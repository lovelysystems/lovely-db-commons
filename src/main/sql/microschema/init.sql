create schema if not exists microschema;
grant usage on schema microschema to public;
set search_path to microschema;


create or replace function jsonb_strip_empty(d jsonb) returns jsonb
    language plpython3u
    immutable as
$$
if d is None:
    return None

import json

data = json.loads(d)

if not isinstance(data, dict):
    plpy.error(f"jsonb_strip_empty requires an object, got: {data}")

if not data:
    return None


def stripper(data):
    new_data = {}
    for k, v in data.items():
        if isinstance(v, dict):
            v = stripper(v)
        if not v in (u'', None, {}):
            new_data[k] = v
    return new_data or None


data = stripper(data)
if data:
    return json.dumps(data, separators=(',', ':'))
$$;

comment on function jsonb_strip_empty(jsonb) is
    'strips any empty strings, empty objects and null values recursively from the given jsonb object';

CREATE or replace FUNCTION microschema.yaml2json(doc text, schema_id text default null)
    RETURNS json
AS
$$
if doc is None:
    return None
import yaml, json
from yaml import CLoader as Loader

d = yaml.load(doc, Loader=Loader)
if d is None:
    return None
return json.dumps(d, separators=(',', ':'))
$$ LANGUAGE plpython3u immutable;

CREATE or replace FUNCTION validated_schema(schema_body text) returns jsonb
    LANGUAGE plpython3u
    immutable as
$$
if schema_body is None:
    return None

from jsonschema.validators import validator_for, meta_schemas
import yaml, json
from yaml import CLoader as Loader

schema = yaml.load(schema_body, Loader=Loader)

schema_id = schema.get('$schema')
if not schema_id:
    raise Exception(f"no $schema defined in {schema}")

meta_schema = meta_schemas.get(schema_id)
if not meta_schema:
    allowed_schemas = list(meta_schemas.keys())
    raise Exception(f"schema: {schema_id} not in supported schemas: {allowed_schemas}")

validator = validator_for(schema)
validator.check_schema(schema)
return json.dumps(schema, separators=(',', ':'))
$$;


create table json_schemas (
    id text primary key,
    raw text,
    body jsonb,
    bundled jsonb
);

comment on column json_schemas.raw is 'The raw body of the schema in yaml or json format';
comment on column json_schemas.body is 'The parsed body of the schema as a json object';
comment on column json_schemas.bundled is 'The schema with inlined dependencies as a json object, used for validation';

grant select on json_schemas to public;

create or replace function microschema.register(raw_schema text) returns boolean
    language plpgsql as
$$
DECLARE
    existing  json_schemas;
    schema_id text;
    json_body jsonb;
BEGIN
    if raw_schema is null then
        RAISE EXCEPTION 'Schema body is null';
    end if;
    select validated_schema(raw_schema) into json_body;
    if json_body is null then
        RAISE EXCEPTION 'Schema cannot be converted to json %', json_body;
    end if;
    select coalesce(json_body ->> '$id', json_body ->> 'id') into schema_id;

    if schema_id is null then
        RAISE EXCEPTION 'Unable to extract id from schema: %', json_body;
    end if;

    SELECT * INTO existing FROM json_schemas WHERE id = schema_id;

    IF NOT FOUND THEN
        insert into json_schemas (id, raw, body) values (schema_id, raw_schema, json_body);
        return true;
    else
        if $1 <> existing.raw then
            update json_schemas set raw=raw_schema, body=json_body where id = schema_id;
            return true;
        else
            return false;
        end if;
    END IF;
END
$$ set search_path from current;


create or replace function validated_doc(schema_body jsonb, doc text) returns jsonb
    language plpython3u
    immutable as
$$
if doc is None:
    return None
import yaml, json
from yaml import CLoader as Loader

data_dict = yaml.load(doc, Loader=Loader)

from jsonschema.validators import validator_for

if schema_body is None:
    return None

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
comment on function validated_doc is
    E'parses and validates doc (yaml or json) against the given schema body and returns the doc as jsonb';



create or replace function parse_with_schema(schema_id text, doc text) returns jsonb
    language sql
    immutable as
$$
select validated_doc((select bundled from json_schemas where id = schema_id), doc);
$$ set search_path from current;
comment on function parse_with_schema is
    E'parses and validates a doc (yaml or json) against a registered microschema and returns it as jsonb';

create or replace function check_doc(schema_id text, doc text) returns boolean
    language sql
    immutable as
$$
select case
           when doc is null then null
           else parse_with_schema(schema_id, doc::text) is not null
           end;
$$ set search_path from current;
comment on function check_doc is
    E'Checks a document (either yaml or json) against a registered microschema';

create or replace function check_doc(schema_id text, doc jsonb) returns boolean
    language sql
    immutable as
$$
select check_doc(schema_id, doc::text)
$$ set search_path from current;


create or replace function schema_deps(schema jsonb) returns setof text
    language sql
    immutable as
$$
select distinct jsonb_path_query(schema, '$.**."$ref"') #>> '{}';
$$;

create or replace function schema_deps(schema_id text) returns setof text
    language sql
    stable as
$$
WITH RECURSIVE deps AS (
    select schema_deps(body) as dep_id
    from json_schemas
    where id = schema_id
    union
    select schema_deps(body)
    from json_schemas js
             join deps on id = deps.dep_id and id <> schema_id)
select dep_id
from deps
where dep_id <> schema_id;
$$ set search_path from current;


create or replace function bundled_schema(schema_id text) returns jsonb
    language sql
    stable as
$$
select jsonb_set(
               s.body, ARRAY ['$defs'],
               coalesce(s.body -> '$defs', '{}') ||
               coalesce(
                       (select jsonb_object_agg(deps.id, deps.body)
                        from json_schemas deps
                        where deps.id in (select schema_deps(schema_id))),
                       '{}')
           )
from json_schemas s
where s.id = schema_id;
$$ set search_path from current;

create or replace function compute_schema_bundles() returns void
    language sql
    volatile as
$$
update json_schemas
set bundled = bundled_schema(id);
$$ set search_path from current;
