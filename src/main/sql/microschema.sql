create schema if not exists microschema;
grant usage on schema microschema to public;
set search_path to microschema;
create extension if not exists plpython3u;


CREATE or replace FUNCTION microschema.yaml2json(raw text, schema_id text default null)
    RETURNS json
AS
$$
if raw is None:
    return None
import yaml, json
from yaml import CLoader as Loader
d = yaml.load(raw, Loader=Loader)
if d is None:
    return None
return json.dumps(d, separators=(',', ':'))
$$ LANGUAGE plpython3u immutable;

CREATE or replace FUNCTION microschema.validate_schema(schema_body jsonb) returns text as
$$
import json
from jsonschema.validators import validator_for

schema = json.loads(schema_body)
validator = validator_for(schema, default=None)
if not validator:
    schemaIdent = schema.get('$schema')
    raise Exception(f"no validator found for schema:{schemaIdent}")
validator.check_schema(schema)
$$ LANGUAGE plpython3u immutable;


create domain json_schema as jsonb not null check ( microschema.validate_schema(VALUE) is null );

create table microschema.json_schemas (
    id text primary key,
    body json_schema
);

create or replace function microschema.register(text) returns boolean
    language plpgsql as
$$
DECLARE
    existing  json_schemas;
    json_body jsonb;
BEGIN
    select yaml2json($1) into json_body;
    SELECT * INTO existing FROM json_schemas WHERE id = json_body ->> 'id';
    IF NOT FOUND THEN
        insert into json_schemas (id, body) values (json_body ->> 'id', json_body);
        return true;
    else
        if json_body <> existing.body then
            update json_schemas set body=json_body where id = json_body ->> 'id';
            return true;
        else
            return false;
        end if;
    END IF;
END
$$ set search_path from current;


create or replace function validated_json(schema_body json_schema, raw text) returns jsonb
    language plpython3u
    immutable as
$$
if raw is None:
    return None
import yaml, json
from yaml import CLoader as Loader
data_dict = yaml.load(raw, Loader=Loader)

from jsonschema.validators import validator_for
schema = json.loads(schema_body)
cls = validator_for(schema, default=None)
if not cls:
    ident = schema.get('$schema')
    raise Exception(f"no validator found for schema {ident}")
validator = validator = cls(schema)
from jsonschema import exceptions
error = exceptions.best_match(validator.iter_errors(data_dict))
if error is not None:
    raise error
return json.dumps(data_dict, separators=(',', ':'))
$$;

create or replace function parse_with_schema(schema_id text, raw text) returns jsonb
    language sql
    immutable as
$$
select validated_json((select body from json_schemas where id = schema_id), raw);
$$ set search_path from current;
comment on function parse_with_schema is
    E'Checks raw yaml or json data against a registered microschema and returns it as jsonb';
