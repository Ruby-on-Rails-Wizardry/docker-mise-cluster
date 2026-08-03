-- Runs once when the db volume is first created (official Postgres entrypoint).
-- Role/password: POSTGRES_USER / POSTGRES_PASSWORD on the compose `db` service.
-- Keep in sync with config/apps.yml database: fields (+ _test for each app).

CREATE DATABASE fred_development;
CREATE DATABASE fred_test;
CREATE DATABASE ron_development;
CREATE DATABASE ron_test;
CREATE DATABASE harry_development;
CREATE DATABASE harry_test;
CREATE DATABASE george_development;
CREATE DATABASE george_test;
