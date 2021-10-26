/**
  This script drops the database and recreates it from scratch.
  Also the user passwords are set to their usernames for easy dev access.
  This script must not be executed outside the localdev environment or testing.
 */
\cd /app/schema/sql;
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'app';
drop database if exists app;

create database app;

\connect app

\i testing.sql
\i microschema.sql
\i register_microschemas.sql

