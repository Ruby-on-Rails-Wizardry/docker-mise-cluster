# wf — multi-app Docker dev cluster (template)

Template starting point for a **multi-app Rails development cluster** with:

- **Ubuntu 24.04 LTS** image + **mise** (Ruby / Node / classic **Yarn 1.22**)
- Shared **Bundler** install + download caches across all apps
- Shared **Yarn 1** offline mirror + cache folder
- **Config-driven** app list (`config/apps.yml`)
- **PostgreSQL** + **Redis** shared data services for all apps
- **Git submodules** for independent app (and shared gem) repos
- Layout: container user home at `/home/$USER` (default `dev`), project mount / WORKDIR at **`$HOME/wf`**

Clone this tree, copy it, or untar it into an existing umbrella project, then edit `config/apps.yml` and submodule URLs.

## Layout

```
wf/
├── config/
│   ├── apps.yml              # SSOT: apps + shared gems (+ url_root)
│   ├── cache-layout.env      # SSOT: relative cache paths
│   └── bundler-flags.yml     # SSOT: Bundler behavior (symlinked as .bundle/config)
├── bin/
│   ├── setup                 # host bootstrap + warm caches
│   ├── cache-env             # export absolute BUNDLE_* / YARN_* paths
│   ├── compose               # docker compose with cache-layout.env
│   ├── apps                  # read config/apps.yml
│   └── docker-app            # container entry: prefer local caches
├── nginx/
│   ├── nginx.conf            # path routing + home page
│   ├── proxy.conf            # shared reverse-proxy headers (no oauth)
│   └── html/index.html       # / home with links to apps
├── docker/
│   ├── setup-postgresql.sh   # PGDG client + libpq in the app image
│   ├── setup-user.sh
│   └── postgres/
│       └── init-databases.sql  # per-app DBs on first boot
├── .cache/                   # materialized caches (not committed)
├── fred/  george/            # demo apps (replace with submodules in real use)
├── Dockerfile                # Ubuntu 24.04 + dev user + mise
├── docker-compose.yml
├── mise.toml
└── README.md
```

## Quick start

```bash
# From this directory (requires mise on host recommended, Docker optional)
bin/setup                 # install tools, warm gem/yarn caches, db:prepare
bin/setup --docker-build  # also build image wf-dev:latest

# One app (pulls nginx + db + redis via depends_on)
bin/compose up fred
# or
bin/compose up george

# Both apps (shared nginx + db + redis)
bin/compose up fred george

# Home   → http://localhost:8080/          (nginx; links to apps)
# Fred   → http://localhost:8080/fred/     (when fred is up)
# George → http://localhost:8080/george/   (when george is up)
# Direct ports (debug): fred :3000, george :3001
# Postgres → localhost:5432  (user/pass cluster / cluster)
# Redis    → localhost:6379

# Data only (for host `bin/setup` db:prepare against published ports)
bin/compose up -d db redis

# Shell in the image
bin/compose --profile dev run --rm dev
```

Compose starts **only** the services you name **and their dependencies**. Apps depend on `nginx`, `db`, and `redis` (not the other way around), so a single-app `up` still gets the proxy without requiring the sibling app.

### Postgres + Redis

Shared compose services (dev credentials only — see `.env.example`):

| Service | Image | Host port | Notes |
|---------|-------|-----------|--------|
| `db` | `postgres:18` | **5432** | DBs: `fred_development`, `george_development` (+ `_test`) via `docker/postgres/init-databases.sql` |
| `redis` | `redis:8-alpine` | **6379** | Fred uses logical DB **0**, George **1** (`REDIS_URL`) |

Apps receive:

| Env | Fred | George |
|-----|------|--------|
| `DATABASE_URL` | `postgresql://…@db:5432/fred_development` | `…/george_development` |
| `REDIS_URL` | `redis://redis:6379/0` | `redis://redis:6379/1` |
| `POSTGRES_*` | host `db`, user/password from compose | same |

Development Active Record uses **PostgreSQL** (`pg` gem). Production sample configs still use multi-db SQLite for Kamal. Redis is available via `REDIS_URL` / the `redis` gem; demo apps still use solid_cache / async cable unless you wire Redis stores yourself.

Host `bin/setup` `db:prepare` expects Postgres on **localhost:5432** — start `bin/compose up -d db redis` first, or use `--skip-db` and let containers run `db:prepare`.

### Nginx path routing

`nginx` is the front door (port **8080**). It is intentionally simpler than `partial/nginx`: same path-proxy idea, **no oauth2-proxy**.

Apps **depend on nginx** (plus `db` / `redis`). Nginx does **not** wait for apps, so you can run only fred or only george; a missing backend returns 502 until that app is up.

| Path | Backend | Notes |
|------|---------|--------|
| `/` | static `nginx/html/index.html` | Links to both apps |
| `/fred/` | `fred:3000` | Prefix stripped; app has `RAILS_RELATIVE_URL_ROOT=/fred` |
| `/george/` | `george:3001` | Same pattern with `/george` |

Edit routing in `nginx/nginx.conf`. Keep `url_root` in `config/apps.yml` and `RAILS_RELATIVE_URL_ROOT` in `docker-compose.yml` aligned with those paths.

Always use **`bin/compose`** (not plain `docker compose`) so `config/cache-layout.env` is loaded.

## Adopting into a real project

1. Copy/clone/untar this `wf/` tree into your umbrella repo (or use it as the repo root).
2. Edit **`config/apps.yml`** — names, paths, ports.
3. Replace demo apps with **git submodules** (see `.gitmodules.example`).
4. Update root **`package.json`** `workspaces` if JS workspaces change.
5. Keep **`docker-compose.yml`** app services (ports, `RAILS_RELATIVE_URL_ROOT`) and **`nginx/nginx.conf`** locations in sync with `apps.yml` (MVP: manual; generation later).
6. Run `bin/setup` and `bin/compose up` (includes nginx on **8080**).

## Cache model

| Path | Role |
|------|------|
| `.cache/rubygems` | Packaged `.gem` files; container prefers `bundle install --local` |
| `.cache/bundle` | Shared gem install tree (`BUNDLE_PATH`) |
| `.cache/yarn` | Classic Yarn offline mirror |
| `.cache/yarn-cache` | Classic `YARN_CACHE_FOLDER` |

Host warms caches via `bin/setup`; containers use `bin/docker-app` and fall back to the network only on a cache miss.

## Config SSOT

| Setting | File |
|---------|------|
| App / shared gem list | `config/apps.yml` |
| Relative cache dirs | `config/cache-layout.env` |
| Bundler flags (non-path) | `config/bundler-flags.yml` |
| Tool pins | `mise.toml` |
| Yarn offline-mirror | `.yarnrc` (from `bin/cache-env --write-yarnrc`) |

## MVP scope (this version)

**In:** Ubuntu + mise image, compose, shared Bundler/Yarn caches, config apps list, demo fred/george, **nginx path routing**, **Postgres + Redis**.

**Later:** oauth2-proxy (see `partial/`), compose/nginx generation from `apps.yml`, Arch image variant, full weasily submodule set (ron/harry + shared gem), Redis-backed cable/cache if desired.

## License

Private template; no license asserted.
