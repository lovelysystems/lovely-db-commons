/*
This script runs all example content files under /tests/json_schema against the registered json schemas.

The expected directory structure is::
<schema_id>/something.yml
<schema_id>/something_should_fail.yml

Files ending with `fail.yml` are expected to fail.

*/


-- temporary table holding the file contents
create temporary table files_tmp (
    name text not null,
    body text not null
);

\copy files_tmp from program 'find /tests/json_schema -name ''*.yml'' |while read -r f; do echo $f,$(base64 -w 0 -i $f); done' csv;

select t.eq(true, (select count(*) > 0 from files_tmp), 'expecting at least one test file');

create or replace function t.test_json_schema_example(file_name text, body text)
    returns boolean
    language plpgsql as
$$
declare
    path_parts  jsonb   := to_json(regexp_split_to_array(file_name, '/'));
    schema_id   text    := path_parts ->> -2;
    base_name   text    := path_parts ->> -1;
    should_fail boolean := base_name like '%fail.yml';
    result      boolean;
begin
    raise notice 'checking ''%'' should_fail=% schema_id=''%''', file_name, should_fail, schema_id;
    if not exists(select 1 from microschema.json_schemas where id = schema_id) then
        raise exception 'schema ''%'' from example file ''%'' does not exist', schema_id, file_name;
    end if;

    if should_fail then
        -- catch exception if we should fail
        begin
            select microschema.check_doc(schema_id, body) into result;
        exception
            when others then
                return true;
        end;
        if result <> false then
            raise exception 'expecting example ''%'' to fail but it did not result=%', file_name, result;
        end if;
    else
        select microschema.check_doc(schema_id, body) into result;
        if result <> true then
            raise exception 'expecting example ''%'' to be valid but it was not result=%', file_name, result;
        end if;
    end if;


    return true;

end
$$;

-- run all tests
select t.test_json_schema_example(name, body)
from (select name, convert_from(decode(body, 'base64'), 'UTF-8') as body
      from files_tmp) as test_files;


