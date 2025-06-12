# Changes for lovely-db-commons

## unreleased

### Feature

- multiplatform docker build
- switched to postgres 16.x as base postgres version

## 2021-12-17 / 0.0.3

### Feature

- added `test_json_schemas.sql` script to run microschema content tests

### Breaking

- all testing related scripts are now under the the `t` directory to follow the naming convention to
  name directories according to their db schema.

## 2021-12-09 / 0.0.2

### Feature

- added jsonb_strip_empty function

## 2021-11-18 / 0.0.1

- initial release
