-- Runs once when the db volume is first created (official Postgres entrypoint).
-- Role/password: POSTGRES_USER / POSTGRES_PASSWORD on the compose `db` service.

CREATE DATABASE fred_development;
CREATE DATABASE fred_test;
CREATE DATABASE george_development;
CREATE DATABASE george_test;
