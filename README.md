# wf — multi-app Docker dev cluster (template)

Template starting point for a **multi-app Rails development cluster** with:

- **Local [ubuntu-mise](https://github.com/Ruby-on-Rails-Wizardry/ubuntu-mise)** base image (`ubuntu-mise:dev` by default) + thin cluster layer (PostgreSQL client / libpq)
- **fred** and **george** (and the optional `dev` shell) share that image (`wf-dev:latest`)
- Shared **Bundler** install + download caches across all apps
- Shared **Yarn 1** offline mirror + cache folder
- **Config-driven** app list (`config/apps.yml`)
- **PostgreSQL** + **Redis** shared data services for all apps
- **Git submodules** for independent app repos (**fred**, **george**) and optional shared gems
- Layout: container user home at `/home/$USER` (default `dev`), project mount / WORKDIR at **`/work`** (same as ubuntu-mise)

Clone with apps:

```bash
git clone --recurse-submodules -b master \
  git@github.com:Ruby-on-Rails-Wizardry/docker-mise-cluster.git
# or after a plain clone:
git submodule update --init --recursive
```

Remotes and `.gitmodules` use **SSH**. If another environment must use **HTTPS** only, keep SSH in the repos and rewrite URLs there with git `url.*.insteadOf` (do not dual-commit URL flips). Full guide in the umbrella doc [docs/CLONE-HTTPS.md](../docs/CLONE-HTTPS.md) (when this tree is nested under [docker-mise](https://github.com/Ruby-on-Rails-Wizardry/docker-mise)), or apply the same pattern:

```bash
# HTTPS-only host/user — not on your normal SSH workstation
# --add stacks values; a second set without --add overwrites the same key
git config --global --add url."https://github.com/".insteadOf "git@github.com:"
git config --global --add url."https://gitlab.com/".insteadOf "git@gitlab.com:"
git pull && git submodule sync --recursive && git submodule update --init --recursive
```

Site-local edits (corp base images, proxy/CA): keep them on a **`local`** branch and **rebase onto `master`** after each pull — full workflow in that guide (do not push those commits to public `master`).

Then edit `config/apps.yml` / `.gitmodules` when adopting into a real project.

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
├── fred/                     # submodule → Ruby-on-Rails-Wizardry/fred
├── george/                   # submodule → Ruby-on-Rails-Wizardry/george
├── .gitmodules
├── Dockerfile                # FROM ubuntu-mise:dev + Postgres client/libpq
├── docker-compose.yml        # fred + george share CLUSTER_IMAGE (wf-dev)
├── mise.toml                 # node/yarn/task pins
├── Taskfile.yml              # task setup / up:fred / compose / …
└── README.md
```

## Base image (ubuntu-mise)

**fred** and **george** run on a thin cluster image built `FROM` a **local** ubuntu-mise tag (default **`ubuntu-mise:dev`**). That parent must exist before `bin/compose build`:

| Context | How to build the base |
|---------|------------------------|
| Nested under [docker-mise](https://github.com/Ruby-on-Rails-Wizardry/docker-mise) | `task ubuntu:build` (or `task cluster:build` auto-builds sibling `../ubuntu-mise` if missing) |
| Standalone cluster clone | Clone/build [ubuntu-mise](https://github.com/Ruby-on-Rails-Wizardry/ubuntu-mise), or set `UBUNTU_MISE_ROOT=/path/to/ubuntu-mise` |
| Custom tag | `BASE_IMAGE=my/ubuntu-mise:dev bin/compose build` |

Overrides (see [`.env.example`](.env.example)): `BASE_IMAGE`, `CLUSTER_IMAGE` (default `wf-dev:latest`).

## Quick start

[Task](https://taskfile.dev) is pinned in [mise.toml](mise.toml) (**3.52.0**). `bin/*` works without it.

```bash
# From this directory (requires mise on host recommended, Docker optional)
mise install              # installs Task (+ node/yarn)
task setup                # or: bin/setup
task setup -- --docker-build   # ensures ubuntu-mise base + builds cluster image

# One app (pulls nginx + db + redis via depends_on)
task up:fred              # or: bin/compose up fred
task up:george

# Both apps (shared nginx + db + redis)
task up:all               # or: bin/compose up fred george
task compose -- ps
```

Without Task:

```bash
# Build local ubuntu-mise first if needed (umbrella sibling or separate clone)
(cd ../ubuntu-mise && ./bin/build)   # when nested under docker-mise
bin/setup
bin/setup --docker-build
bin/compose up fred
bin/compose up george
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

1. Copy/clone this `wf/` tree (or use it as the repo root) with **`--recurse-submodules`**.
2. Edit **`config/apps.yml`** — names, paths, ports, `url_root`, databases.
3. Point **`.gitmodules`** at your app repos (demo apps are already submodules: [fred](https://github.com/Ruby-on-Rails-Wizardry/fred), [george](https://github.com/Ruby-on-Rails-Wizardry/george)).
4. Update root **`package.json`** `workspaces` if JS workspaces change.
5. Keep **`docker-compose.yml`** app services (ports, `RAILS_RELATIVE_URL_ROOT`) and **`nginx/nginx.conf`** locations in sync with `apps.yml` (MVP: manual; generation later).
6. Run `bin/setup` and `bin/compose up fred` (or `george` / both).

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
