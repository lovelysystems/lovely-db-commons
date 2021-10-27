create temporary table loaded_json_schemas_tmp (
    body text not null
);

\copy loaded_json_schemas_tmp from program 'ls -1 $SCHEMA_DIR/json_schema/*.yml|while read -r f; do echo $(base64 -w 0 -i $f); done' csv;
select microschema.register(convert_from(decode(body, 'base64'), 'UTF-8'))
from loaded_json_schemas_tmp;
