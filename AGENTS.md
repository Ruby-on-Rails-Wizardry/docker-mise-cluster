# Agent guide — wf (multi-app Docker cluster template)

## Purpose

`wf/` is the **product template**: a copyable/cloneable starting point for multi-app Rails Docker **development** on **Ubuntu** with shared Bundler + classic Yarn 1 caches.

It is **not** the production deploy topology. Production follows Rails/Kamal defaults per app (see [Production deployment](#production-deployment-kamal--not-compose)).

Reference trees (do not treat as the product):

- `../partial/` — anonymized real weasily/wf cluster (nginx, oauth2, postgres, submodules)
- `../experment/` — cache experiment; use branch **`dry-yarn-1`** for classic Yarn patterns

## Decisions (locked for MVP)

| Decision | Choice |
|----------|--------|
| Product shape | **Template** — clone, copy, or untar into a project (**dev** multi-app compose) |
| OS / base | **Ubuntu only** — prebuilt [ubuntu-mise](https://github.com/Ruby-on-Rails-Wizardry/ubuntu-mise) (`IMAGE=ubuntu-mise:dev`, `pull_policy: never`) |
| App layout | **Git submodules** (`fred`, `ron`, `harry`, `george` → independent repos) |
| App ports / paths | Simple name paths; ports from **3001**: fred `/fred:3001`, ron `/ron:3002`, harry `/harry:3003`, george `/george:3004` |
| **Compose project name** | **Directory basename** — do **not** hardcode `COMPOSE_PROJECT_NAME` (copy to `wf/` → project `wf`) |
| **Container user** | Baked into **ubuntu-mise** at **build** (host `$USER`/`DEV_UID`/`DEV_GID` via `task build`); compose does **not** pass user/UID at run time |
| **Production deploy** | **N Kamal apps, one VPS** (Approach A): each app has its own image + `config/deploy.yml`; **kamal-proxy** routes by **hostname**. Not `docker compose` of this cluster in prod. |
| Host UX | Cluster + each app: **mise** + **Task** like ubuntu-sample (`.mise.env` with `POSTGRESQL_VERSION`, `bin/*`, mirrored tasks). Cluster orchestrates multi-app + **nginx** path routing. |
| Yarn | **Classic 1.22.x** (not Berry) |
| MVP services | Image + compose + shared gem/yarn caches + nginx + Postgres + Redis |
| Apply to weasily | New `wf/` tree; leave `partial/` as reference |
| **Mise install timing** | **Development:** `mise install` at **runtime** into **`/cache`** volume. **Production:** tools frozen at **image build**; server start only (no install/activate on boot). |
| **Mise in production** | **Default: do not use mise** — keep official multi-stage language images (`ruby:*-slim` + bundle), with pin parity to Gemfile. **If mise is used:** **builder stage only** (BuildKit cache mounts OK); copy frozen binaries/app into a slim runtime; final image should not require the mise binary, shims, or `mise activate`. Never ship full ubuntu-mise as a prod base. |

## Mise: development vs production

| Context | `mise install` | Cache / layers | Runtime |
|---------|----------------|----------------|---------|
| **Development** (ubuntu-mise, compose apps + `dev`) | **At container runtime** | Shared **`/cache`** volume (and host-warmed gem/yarn under `/work/.cache`) | `mise activate` + `mise install` as needed (`bin/docker-app`, `dev` shell) |
| **Production** (app Dockerfiles / Kamal) — **default** | N/A (no mise) | Official base + gems/assets in image layers | Fixed process (Thruster/Puma). Pin Ruby via Dockerfile `ARG` matching Gemfile |
| **Production** — **if mise is adopted** | **Builder stage only** (`RUN mise install`, BuildKit caches) | Downloads in builder cache; **copy-out** to runtime | Start server only. Prefer **no mise** in the final image; never install/activate on boot |

**Why default off:** for single-Ruby Rails apps, official images are smaller, clearer, and simpler to operate. Build-time mise mainly helps multi-language pin parity; it is a **build tool**, not a runtime manager.

Current app production Dockerfiles use official `ruby:…-slim` multi-stage and **do not** use mise.

## Submodules (apps)

| Path | Repo | Port | Path prefix |
|------|------|------|-------------|
| `fred/` | `git@github.com:Ruby-on-Rails-Wizardry/fred.git` | 3001 | `/fred` |
| `ron/` | `git@github.com:Ruby-on-Rails-Wizardry/ron.git` | 3002 | `/ron` |
| `harry/` | `git@github.com:Ruby-on-Rails-Wizardry/harry.git` | 3003 | `/harry` |
| `george/` | `git@github.com:Ruby-on-Rails-Wizardry/george.git` | 3004 | `/george` |

Clone: `git clone --recurse-submodules …` or `git submodule update --init --recursive`.  
App code changes are committed **inside** each app repo, then the parent cluster pin is updated.

## Rules

1. Cache paths only in **`config/cache-layout.env`**; use **`bin/cache-env`** / **`bin/compose`**.
2. App list only in **`config/apps.yml`**; `bin/setup` and `bin/apps` read it. Keep **`compose.yml`** services, **`nginx/nginx.conf`**, and **`docker/postgres/init-databases.sql`** in sync for MVP (`port`, `url_root` ↔ `RAILS_RELATIVE_URL_ROOT` + nginx `location` + DB names). Shared app shape lives in the `x-app` anchor — per-app blocks are deltas only.
3. Bundler flags only in **`config/bundler-flags.yml`** (symlinked as `.bundle/config`).
4. Do **not** set `BUNDLE_APP_CONFIG` to the cluster root when running app Gemfiles.
5. Prefer `bundle install --local` / yarn `--offline` before network.
6. Image user is set at **ubuntu-mise build** only (host `$USER` / UID / GID). Project mount / WORKDIR is **`/work`** (`WORKSPACE`). Do **not** pass `user:` / `IMAGE_USER` / `DEV_UID` at cluster run time.
7. Do **not** set a default `COMPOSE_PROJECT_NAME` — Docker uses the directory name. Operators may export one only when they need a stable name across renames.
8. Do not commit `.cache/**` contents (only `.gitkeep`).
9. Do not introduce Yarn Berry in this template.
10. Nginx is path routing only (**dev**). Do not reintroduce oauth2 here unless explicitly requested. Production uses **hostname** routing via kamal-proxy, not these path prefixes.
11. Dev Postgres/Redis credentials stay in compose / `.env.example` only — never real secrets. Per-app DBs: `docker/postgres/init-databases.sql`; wire new apps in compose (`DATABASE_URL`, `REDIS_URL`) and that init script.
12. **Mise install timing:** development → **runtime** + `/cache`; production → **image build** only (see Decisions table). Do not bake language toolchains into the cluster **dev** image build; do not run `mise install` on production boot.
13. **Do not** treat this compose stack as production. Deploy each app with **Kamal** from its app repo.

## Production deployment (Kamal — not compose)

Rails 8 / DHH default: **one Docker image per app**, **Kamal** deploys over SSH, **kamal-proxy** for SSL + routing. This cluster is the **local multi-app dev** story only.

### Chosen topology: N apps, one server

```text
fred.example.com   ──┐
ron.example.com    ──┤
harry.example.com  ──┼──► VPS ── kamal-proxy ──► containers (one per app)
george.example.com ──┘
```

| Concern | Development (this repo) | Production (Approach A) |
|---------|-------------------------|-------------------------|
| Front door | nginx path prefix `/fred`, `/ron`, … | **Hostname** per app (`proxy.host` in each `deploy.yml`) |
| Process | compose + `bin/docker-app` | Thruster → Puma (`app` Dockerfile `CMD`) |
| Image | prebuilt `ubuntu-mise:dev` + bind-mount `/work` | Per-app image from each app `Dockerfile` |
| Tools | runtime `mise install` → `/cache` | Frozen at image build (no mise on boot) |
| Data | shared compose Postgres + Redis | SQLite volumes (generator default) *or* Postgres accessory later |
| Deploy unit | `bin/compose up fred` | `cd fred && bin/kamal deploy` (independent of siblings) |

### Unit of deploy

| App | Config | Typical commands |
|-----|--------|------------------|
| [fred](https://github.com/Ruby-on-Rails-Wizardry/fred) | `config/deploy.yml`, `.kamal/secrets` | `bin/kamal setup` (first time), `bin/kamal deploy` |
| [ron](https://github.com/Ruby-on-Rails-Wizardry/ron) | same shape | same VPS, unique `service` / `image` / `proxy.host` / volumes |
| [harry](https://github.com/Ruby-on-Rails-Wizardry/harry) | same shape | same |
| [george](https://github.com/Ruby-on-Rails-Wizardry/george) | same shape | same |

All apps list the **same** `servers.web` host. First app’s `kamal setup` installs Docker/proxy on the box; the others reuse the host. Use unique volume names (`fred_storage`, `ron_storage`, …).

### Not production (yet)

- Real server IPs, registry, and DNS in `deploy.yml` (still placeholders in the demo apps)
- Choosing SQLite volumes vs a shared Postgres accessory for prod parity with cluster
- CI that builds/pushes images and runs `kamal deploy`

## Nginx (path proxy)

| Path | Target |
|------|--------|
| `/` | static home (`nginx/html/index.html`) |
| `/fred/` | `fred:3001` (prefix stripped) |
| `/ron/` | `ron:3002` (prefix stripped) |
| `/harry/` | `harry:3003` (prefix stripped) |
| `/george/` | `george:3004` (prefix stripped) |

Config: `nginx/nginx.conf` + `nginx/proxy.conf`. Apps set `RAILS_RELATIVE_URL_ROOT` so asset/link helpers keep the path prefix.

**depends_on direction:** each app → `nginx` + `db` + `redis`. Nginx does **not** depend on apps (one-app `compose up fred` still starts the proxy).

## Data services

| Service | Role |
|---------|------|
| `db` | Postgres 18; per-app `*_development` / `*_test` databases |
| `redis` | Redis 8; `REDIS_URL` per app (DB index 0–3) |

Apps depend on db/redis/nginx healthy before start. Host setup against Postgres needs `bin/compose up -d db` (or `--skip-db`).

### Reset one app database

Shared Postgres; only the named app’s database is dropped/recreated (`config/apps.yml` → `database:`).

```bash
task db:reset:fred             # or: bin/db-reset fred
task db:reset:ron
task db:reset -- fred ron      # multiple
bin/db-reset --docker harry    # force rails via compose
bin/db-reset --host george     # force host rails (after bin/setup)
```

`bin/setup --reset` still resets **all** apps during full host setup.

## Common tasks

```bash
mise install                   # Task + node/yarn from mise.toml
task setup                     # or bin/setup
task setup -- --docker-build
task db                        # optional: compose up -d db redis
task db:reset:fred             # drop/create/schema/seed one app DB
task up:fred                   # nginx + db + redis + fred only
task up:ron
task up:all                    # all four apps + shared deps
task compose -- ps
# http://localhost:8080/  → home; /fred/ /ron/ /harry/ /george/ via proxy
task shell:dev
task apps
source bin/cache-env && cd fred && bin/rails console
```

`bin/*` remains the implementation; Task is optional host UX (same pattern as ubuntu-mise).
