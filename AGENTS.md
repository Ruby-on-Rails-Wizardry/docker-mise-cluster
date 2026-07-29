# Agent guide — wf (multi-app Docker cluster template)

## Purpose

`wf/` is the **product template**: a copyable/cloneable starting point for multi-app Rails Docker **development** with shared Bundler + classic Yarn 1 caches.

It is **not** the production deploy topology. Production follows Rails/Kamal defaults per app (see [Production deployment](#production-deployment-kamal--not-compose)).

Reference trees (do not treat as the product):

- `../partial/` — anonymized real weasily/wf cluster (nginx, oauth2, postgres, submodules)
- `../experment/` — cache experiment; use branch **`dry-yarn-1`** for classic Yarn patterns

## Decisions (locked for MVP)

| Decision | Choice |
|----------|--------|
| Product shape | **Template** — clone, copy, or untar into a project (**dev** multi-app compose) |
| App layout | **Git submodules** (`fred`, `george` → independent repos) |
| **Production deploy** | **Two Kamal apps, one VPS** (Approach A): each app has its own image + `config/deploy.yml`; **kamal-proxy** routes by **hostname**. Not `docker compose` of this cluster in prod. |
| Base image (dev) | **Local [ubuntu-mise](https://github.com/Ruby-on-Rails-Wizardry/ubuntu-mise)** (`BASE_IMAGE`, default `ubuntu-mise:dev`) + thin cluster layer (Postgres client/libpq); layout: `/home/$USER` + project **`/work`** + **`/cache`** volume (`USER` / `DEV_UID` / `DEV_GID` build args). Build base first: `task ubuntu:build` from the docker-mise umbrella. |
| Yarn | **Classic 1.22.x** (not Berry) |
| MVP services | Image + compose + shared gem/yarn caches + nginx + Postgres + Redis |
| Apply to weasily | New `wf/` tree; leave `partial/` as reference |
| **Mise install timing** | **Development:** `mise install` at **runtime** into **`/cache`** volume. **Production:** tools frozen at **image build**; server start only (no install/activate on boot). |
| **Mise in production** | **Default: do not use mise** — keep official multi-stage language images (`ruby:*-slim` + bundle), with pin parity to Gemfile. **If mise is used:** **builder stage only** (BuildKit cache mounts OK); copy frozen binaries/app into a slim runtime; final image should not require the mise binary, shims, or `mise activate`. Never ship full ubuntu-mise as a prod base. |

## Mise: development vs production

| Context | `mise install` | Cache / layers | Runtime |
|---------|----------------|----------------|---------|
| **Development** (ubuntu-mise, cluster `wf-dev`, compose `fred`/`george`/`dev`) | **At container runtime** | Shared **`/cache`** volume (and host-warmed gem/yarn under `/work/.cache`) | `mise activate` + `mise install` as needed (`bin/docker-app`, `dev` shell) |
| **Production** (app Dockerfiles / Kamal) — **default** | N/A (no mise) | Official base + gems/assets in image layers | Fixed process (Thruster/Puma). Pin Ruby via Dockerfile `ARG` matching Gemfile |
| **Production** — **if mise is adopted** | **Builder stage only** (`RUN mise install`, BuildKit caches) | Downloads in builder cache; **copy-out** to runtime | Start server only. Prefer **no mise** in the final image; never install/activate on boot |

**Why default off:** for single-Ruby Rails apps (fred/george today), official images are smaller, clearer, and simpler to operate. Build-time mise mainly helps multi-language pin parity; it is a **build tool**, not a runtime manager.

Current **fred** / **george** production Dockerfiles use official `ruby:…-slim` multi-stage and **do not** use mise.

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
6. Image user defaults to **`dev`** (`USER` arg); project mount / WORKDIR is **`/work`** (`WORKSPACE`, same as ubuntu-mise).
7. Do not commit `.cache/**` contents (only `.gitkeep`).
8. Do not introduce Yarn Berry in this template.
9. Nginx is path routing only (**dev**). Do not reintroduce oauth2 here unless explicitly requested. Production uses **hostname** routing via kamal-proxy, not these path prefixes.
10. Dev Postgres/Redis credentials stay in compose / `.env.example` only — never real secrets. Per-app DBs: `docker/postgres/init-databases.sql`; wire new apps in compose (`DATABASE_URL`, `REDIS_URL`) and that init script.
11. **Mise install timing:** development → **runtime** + `/cache`; production → **image build** only (see Decisions table). Do not bake language toolchains into the cluster **dev** image build; do not run `mise install` on production boot.
12. **Do not** treat this compose stack as production. Deploy each app with **Kamal** from the app repo (`fred`, `george`).

## Production deployment (Kamal — not compose)

Rails 8 / DHH default: **one Docker image per app**, **Kamal** deploys over SSH, **kamal-proxy** for SSL + routing. This cluster is the **local multi-app dev** story only.

### Chosen topology: two apps, one server

```text
fred.example.com  ──┐
george.example.com ─┼──► VPS ── kamal-proxy ──► container fred
                    │                      └──► container george
```

| Concern | Development (this repo) | Production (Approach A) |
|---------|-------------------------|-------------------------|
| Front door | nginx path prefix `/fred`, `/george` | **Hostname** per app (`proxy.host` in each `deploy.yml`) |
| Process | compose + `bin/docker-app` | Thruster → Puma (`app` Dockerfile `CMD`) |
| Image | shared `wf-dev` + bind-mount `/work` | Per-app image from `fred/Dockerfile` / `george/Dockerfile` |
| Tools | runtime `mise install` → `/cache` | Frozen at image build (no mise on boot) |
| Data | shared compose Postgres + Redis | SQLite volumes (generator default) *or* Postgres accessory later |
| Deploy unit | `bin/compose up fred` | `cd fred && bin/kamal deploy` (independent of george) |

### Unit of deploy

| App | Config | Typical commands |
|-----|--------|------------------|
| [fred](https://github.com/Ruby-on-Rails-Wizardry/fred) | `config/deploy.yml`, `.kamal/secrets` | `bin/kamal setup` (first time), `bin/kamal deploy` |
| [george](https://github.com/Ruby-on-Rails-Wizardry/george) | same shape | same, **same VPS IP**, different `service` / `image` / `proxy.host` / volumes |

Both apps list the **same** `servers.web` host. First app’s `kamal setup` installs Docker/proxy on the box; the second reuses the host. Use unique volume names (`fred_storage`, `george_storage`).

### Not production (yet)

- Real server IPs, registry, and DNS in `deploy.yml` (still placeholders in the demo apps)
- Choosing SQLite volumes vs a shared Postgres accessory for prod parity with cluster
- CI that builds/pushes images and runs `kamal deploy`

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

### Reset one app database

Shared Postgres; only the named app’s database is dropped/recreated (`config/apps.yml` → `database:`).

```bash
task db:reset:fred             # or: bin/db-reset fred
task db:reset:george           # or: bin/db-reset george
task db:reset -- fred george   # multiple
bin/db-reset --docker fred     # force rails via compose
bin/db-reset --host fred       # force host rails (after bin/setup)
```

`bin/setup --reset` still resets **all** apps during full host setup.

## Common tasks

```bash
mise install                   # Task + node/yarn from mise.toml
task setup                     # or bin/setup
task setup -- --docker-build
task db                        # optional: compose up -d db redis
task db:reset:fred             # drop/create/schema/seed one app DB
task db:reset:george
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
