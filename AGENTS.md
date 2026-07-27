# Agent guide — wf (multi-app Docker cluster template)

## Purpose

`wf/` is the **product template**: a copyable/cloneable starting point for multi-app Rails Docker development with shared Bundler + classic Yarn 1 caches.

Reference trees (do not treat as the product):

- `../partial/` — anonymized real weasily/wf cluster (nginx, oauth2, postgres, submodules)
- `../experment/` — cache experiment; use branch **`dry-yarn-1`** for classic Yarn patterns

## Decisions (locked for MVP)

| Decision | Choice |
|----------|--------|
| Product shape | **Template** — clone, copy, or untar into a project |
| App layout | **Git submodules** (`fred`, `george` → independent repos) |
| Base image | **Ubuntu 24.04 LTS** + mise; layout: `/home/$USER` + **`$HOME/wf`** (`USER` / `DEV_UID` / `DEV_GID` build args) |
| Yarn | **Classic 1.22.x** (not Berry) |
| MVP services | Image + compose + shared gem/yarn caches + nginx + Postgres + Redis |
| Apply to weasily | New `wf/` tree; leave `partial/` as reference |

## Submodules (apps)

| Path | Repo |
|------|------|
| `fred/` | `git@github.com:Ruby-on-Rails-Wizardry/fred.git` |
| `george/` | `git@github.com:Ruby-on-Rails-Wizardry/george.git` |

Clone: `git clone --recurse-submodules …` or `git submodule update --init --recursive`.  
App code changes are committed **inside** `fred/` / `george/`, then the parent cluster pin is updated.

## Rules

1. Cache paths only in **`config/cache-layout.env`**; use **`bin/cache-env`** / **`bin/compose`**.
2. App list only in **`config/apps.yml`**; `bin/setup` and `bin/apps` read it. Keep compose services **and** `nginx/nginx.conf` locations in sync for MVP (`port`, `url_root` ↔ `RAILS_RELATIVE_URL_ROOT` + nginx `location`).
3. Bundler flags only in **`config/bundler-flags.yml`** (symlinked as `.bundle/config`).
4. Do **not** set `BUNDLE_APP_CONFIG` to the cluster root when running app Gemfiles.
5. Prefer `bundle install --local` / yarn `--offline` before network.
6. Image user defaults to **`dev`** (`USER` arg); project mount / WORKDIR is **`$HOME/wf`** (`WORKSPACE`).
7. Do not commit `.cache/**` contents (only `.gitkeep`).
8. Do not introduce Yarn Berry in this template.
9. Nginx is path routing only (see `partial/nginx` for oauth patterns). Do not reintroduce oauth2 here unless explicitly requested.
10. Dev Postgres/Redis credentials stay in compose / `.env.example` only — never real secrets. Per-app DBs: `docker/postgres/init-databases.sql`; wire new apps in compose (`DATABASE_URL`, `REDIS_URL`) and that init script.

## Nginx (path proxy)

| Path | Target |
|------|--------|
| `/` | static home (`nginx/html/index.html`) |
| `/fred/` | `fred:3000` (prefix stripped) |
| `/george/` | `george:3001` (prefix stripped) |

Config: `nginx/nginx.conf` + `nginx/proxy.conf`. Apps set `RAILS_RELATIVE_URL_ROOT` so asset/link helpers keep the path prefix.

**depends_on direction:** each app → `nginx` + `db` + `redis`. Nginx does **not** depend on apps (one-app `compose up fred` still starts the proxy).

## Data services

| Service | Role |
|---------|------|
| `db` | Postgres 18; `fred_*` / `george_*` databases |
| `redis` | Redis 8; `REDIS_URL` per app (DB index 0 / 1) |

Apps depend on db/redis/nginx healthy before start. Host setup against Postgres needs `bin/compose up -d db` (or `--skip-db`).

## Common tasks

```bash
mise install                   # Task + node/yarn from mise.toml
task setup                     # or bin/setup
task setup -- --docker-build
task db                        # optional: compose up -d db redis
task up:fred                   # nginx + db + redis + fred only
task up:george
task up:all                    # both apps + shared deps
task compose -- ps
# http://localhost:8080/  → home; /fred/ and/or /george/ via proxy
task shell:dev
task apps
source bin/cache-env && cd fred && bin/rails console
```

`bin/*` remains the implementation; Task is optional host UX (same pattern as ubuntu-mise).
