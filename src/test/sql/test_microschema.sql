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


-- the schema type needs to be known
select t.raises($stmt$
select microschema.register($$
{
  "$schema": "http://unknown-schema",
  "id": "MyAwesomeContentType"
}
$$); $stmt$,
                '%no validator found for schema: http://unknown-schema%'
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

