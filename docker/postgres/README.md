# Postgres

By default the cluster does not mount an init SQL script. Each app’s
`bin/docker-app` runs `rails db:prepare`, which creates the database if missing
(Postgres user is the compose superuser).

To use SQL-based multi-DB bootstrap (volume first-create only), add a `*.sql`
under this directory and mount it in `compose.yml`:

```yaml
volumes:
  - ./docker/postgres/init-databases.sql:/docker-entrypoint-initdb.d/01-init-databases.sql:ro
```
