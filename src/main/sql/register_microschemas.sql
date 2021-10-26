create temporary table loaded_microschemas_tmp (
    body text not null
);

\copy loaded_microschemas_tmp from program 'find $SCHEMA_DIR/json_schema -name ''*.yml'' -exec base64 -w 0 -i {} \;' csv;

select microschema.register(convert_from(decode(body, 'base64'), 'UTF-8'))
from loaded_microschemas_tmp;
