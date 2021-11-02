set search_path to microschema;

-- yaml to json conversion
select t.eq(yaml2json($$
a:
 b: 1
 c: 2
$$), $${
  "a": {
    "b": 1,
    "c": 2
  }
}$$::json);


select t.eq(yaml2json(null), null, 'nulls are handled correctly');
select t.eq(yaml2json(''), null, 'empty yaml gives null');

-- the schema needs to be defined
select t.raises($stmt$
select microschema.register($$
{
  "id": "MyAwesomeContentType"
}
$$); $stmt$,
                '%no $schema defined in {%}%'
           );


-- the schema type needs to be known
select t.raises($stmt$
select microschema.register($$
{
  "$schema": "http://unknown-schema",
  "id": "MyAwesomeContentType"
}
$$); $stmt$,
                '%schema: http://unknown-schema not in supported schemas%'
           );

-- schema gets validated
select t.raises($stmt$
select microschema.validate_schema($$
{
  "$schema": "http://json-schema.org/draft-04/schema",
  "id": 1
}
$$); $stmt$,
                '%jsonschema.exceptions.SchemaError: 1 is not of type ''string%''%'
           );



select t.eq(null, check_doc('Person', null), 'the check function always returns null on null input');

-- invalid docs produce an exception
select t.raises($stmt$select check_doc('Person', '{}');$stmt$, '%''name'' is a required property%');

select t.eq(true, check_doc('Person', 'name: Marvin'), 'true gets returned on valid docs');

-- bundles should be applied
select t.eq(bundled_schema('Person'), (select bundled from json_schemas where id = 'Person')::jsonb);

-- the bundles have all used schemas defined in the $defs
select t.eq((select body from json_schemas where id = 'ImageReference')::jsonb,
            (select bundled -> '$defs' -> 'ImageReference' from json_schemas where id = 'Person'));


create table docs (
    id serial8 primary key,
    schema_name text references microschema.json_schemas (id),
    raw text not null,
    data jsonb GENERATED ALWAYS AS (microschema.parse_with_schema(schema_name, raw)) STORED
);
comment on table docs is 'an example table using dynamic types based on a schema column';



insert into docs(schema_name, raw)
values ('ImageReference', $$
digest: "2297e98f8af710c7e7fe703abc8f639e0ee507c4"
$$);

insert into docs(schema_name, raw)
values ('Person', $$
name: Jon
image:
 digest: 4cbd040533a2f43fc6691d773d510cda70f4126a
$$);
