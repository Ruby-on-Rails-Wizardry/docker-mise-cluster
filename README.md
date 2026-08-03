# wf — multi-app Docker dev cluster (Ubuntu template)

Template starting point for a **multi-app Rails development cluster** on **Ubuntu** (local Docker Compose). **Production** deploys each app with **Kamal** on a VPS (hostname routing), not this compose file — see [AGENTS.md — Production deployment](AGENTS.md#production-deployment-kamal--not-compose).

Includes:

- **Prebuilt [ubuntu-mise](https://github.com/Ruby-on-Rails-Wizardry/ubuntu-mise)** (`ubuntu-mise:dev`, `pull_policy: never`) for **fred**, **ron**, **harry**, **george**, and optional **dev** — no cluster image build
- **Host UX** like [ubuntu-sample](../ubuntu-sample/): `.mise.env` (`POSTGRESQL_VERSION=18`), Task + mise tasks at cluster root **and** in each app
- Shared **Bundler** install + download caches across all apps
- Shared **Yarn 1** offline mirror + cache folder
- **nginx** path routing (`/fred/`, `/ron/`, `/harry/`, `/george/`) + **PostgreSQL** + **Redis**
- **Config-driven** app list (`config/apps.yml`)
- **Git submodules** for independent app repos (**fred**, **ron**, **harry**, **george**)
- Layout: project **`/work`**, tools at runtime into shared **`/cache`** volume (`ubuntu-mise-cache`)
- **Mise:** development installs at **runtime** into `/cache`; production app images install at **build** only
- **Compose project name** = directory basename (copy to `wf/` and project is `wf` — no hard-coded name)
- **Container user** defaults to host `$USER` / `id -u` (match the ubuntu-mise build; no run-time flags)

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
cluster/   # or wf/ — directory name becomes the Compose project name
├── .mise.env                 # POSTGRESQL_VERSION, IMAGE, CACHE_VOLUME
├── config/
│   ├── apps.yml              # SSOT: apps + shared gems (+ url_root)
│   ├── cache-layout.env      # SSOT: relative cache paths
│   └── bundler-flags.yml     # SSOT: Bundler behavior (symlinked as .bundle/config)
├── bin/
│   ├── lib.sh / mise-host-env.sh / config / doctor
│   ├── setup                 # host bootstrap + warm caches
│   ├── compose               # .env + cache-layout + ensure ubuntu-mise:dev
│   ├── apps / db-reset / docker-app
│   └── cache-ensure / cache-reset
├── nginx/                    # path routing + home page
├── docker/postgres/          # per-app DB init
├── fred/  ron/  harry/  george/   # submodules — Task/mise like ubuntu-sample
├── docker-compose.yml        # prebuilt ubuntu-mise:dev + nginx + db + redis
├── Dockerfile                # optional thin layer (not used by default compose)
├── mise.toml / Taskfile.yml  # multi-app host UX
└── README.md
```

## Quick start

```bash
cd ../ubuntu-mise && task build && cd -   # uses host USER / UID by default
mise install && task doctor
task setup
task up:fred          # or: task up:ron | up:harry | up:george | up:all
# http://localhost:8080/fred/   (and /ron/ /harry/ /george/)
# direct: http://localhost:3001 … 3004
```

No need to pass `IMAGE_USER` / `DEV_UID` when running apps if the base image was built with the same host defaults.

App-scoped Task (same shape as ubuntu-sample):

```bash
task fred -- setup
task fred -- shell
task ron -- doctor
```

## Base image (ubuntu-mise)

All four apps run the **prebuilt** **`ubuntu-mise:dev`** image (`pull_policy: never`). No cluster image layer. **Ubuntu only** for this template.

| Context | How to get the base |
|---------|---------------------|
| Nested under [docker-mise](https://github.com/Ruby-on-Rails-Wizardry/docker-mise) | `cd ../ubuntu-mise && task build` or `task ubuntu:build` from umbrella |
| Standalone cluster clone | Build [ubuntu-mise](https://github.com/Ruby-on-Rails-Wizardry/ubuntu-mise), or `UBUNTU_MISE_ROOT=/path/to/ubuntu-mise task setup -- --docker-build` |
| Custom tag | `IMAGE=my/ubuntu-mise:dev` (must exist locally) |

Shared `/cache` volume: **`ubuntu-mise-cache`** (same default as ubuntu-mise / ubuntu-sample). PostgreSQL major for compose `db` and base client parity: **`.mise.env`** → `POSTGRESQL_VERSION=18`.

**User identity:** `bin/compose` writes host `$USER` / `id -u` / `id -g` into `.env`. Build the base the same way (ubuntu-mise defaults). Override only in `.mise.env.local` if you deliberately use a shared `dev:1000` image.

**Compose project name:** omit `COMPOSE_PROJECT_NAME` so Docker uses the directory name. Copy/clone this tree as `wf/` and the project is `wf`.

Overrides: [`.env.example`](.env.example), [`.mise.env`](.mise.env).

Without Task:

```bash
(cd ../ubuntu-mise && ./bin/build)   # when nested under docker-mise
bin/setup
bin/setup --docker-build
bin/compose up fred
bin/compose up ron harry
bin/compose up fred ron harry george

# Home   → http://localhost:8080/          (nginx; links to apps)
# Fred   → http://localhost:8080/fred/     (when fred is up)
# Ron    → http://localhost:8080/ron/
# Harry  → http://localhost:8080/harry/
# George → http://localhost:8080/george/
# Direct ports (debug): fred :3001, ron :3002, harry :3003, george :3004
# Postgres → localhost:5432  (user/pass cluster / cluster)
# Redis    → localhost:6379

# Data only (for host `bin/setup` db:prepare against published ports)
bin/compose up -d db redis

# Shell in the image
bin/compose --profile dev run --rm dev
```

Compose starts **only** the services you name **and their dependencies**. Apps depend on `nginx`, `db`, and `redis` (not the other way around), so a single-app `up` still gets the proxy without requiring sibling apps.

### Postgres + Redis

Shared compose services (dev credentials only — see `.env.example`):

| Service | Image | Host port | Notes |
|---------|-------|-----------|--------|
| `db` | `postgres:18` | **5432** | DBs: `fred_*`, `ron_*`, `harry_*`, `george_*` (+ `_test`) via `docker/postgres/init-databases.sql` |
| `redis` | `redis:8-alpine` | **6379** | Logical DBs **0–3** (`REDIS_URL`) |

| App | Port | Path | Database | Redis DB |
|-----|------|------|----------|----------|
| fred | 3001 | `/fred` | `fred_development` | 0 |
| ron | 3002 | `/ron` | `ron_development` | 1 |
| harry | 3003 | `/harry` | `harry_development` | 2 |
| george | 3004 | `/george` | `george_development` | 3 |

Development Active Record uses **PostgreSQL** (`pg` gem). Production sample configs still use multi-db SQLite for Kamal. Redis is available via `REDIS_URL` / the `redis` gem; demo apps still use solid_cache / async cable unless you wire Redis stores yourself.

Host `bin/setup` `db:prepare` expects Postgres on **localhost:5432** — start `bin/compose up -d db redis` first, or use `--skip-db` and let containers run `db:prepare`.

Reset **one** app’s development database (leaves siblings alone):

```bash
task db:reset:fred             # or: bin/db-reset fred
task db:reset:ron
bin/db-reset --docker harry    # rails inside compose if host gems are not ready
```

### Nginx path routing

`nginx` is the front door (port **8080**). It is intentionally simpler than `partial/nginx`: same path-proxy idea, **no oauth2-proxy**.

Apps **depend on nginx** (plus `db` / `redis`). Nginx does **not** wait for apps, so you can run any subset; a missing backend returns 502 until that app is up.

| Path | Backend | Notes |
|------|---------|--------|
| `/` | static `nginx/html/index.html` | Links to all apps |
| `/fred/` | `fred:3001` | Prefix stripped; `RAILS_RELATIVE_URL_ROOT=/fred` |
| `/ron/` | `ron:3002` | same pattern |
| `/harry/` | `harry:3003` | same pattern |
| `/george/` | `george:3004` | same pattern |

Edit routing in `nginx/nginx.conf`. Keep `url_root` in `config/apps.yml` and `RAILS_RELATIVE_URL_ROOT` in `docker-compose.yml` aligned with those paths.

Always use **`bin/compose`** (not plain `docker compose`) so `config/cache-layout.env` is loaded.

## Adopting into a real project

1. Copy/clone this tree (often as **`wf/`**) with **`--recurse-submodules`**. Compose project name follows the directory.
2. Edit **`config/apps.yml`** — names, paths, ports, `url_root`, databases.
3. Point **`.gitmodules`** at your app repos (demo apps: [fred](https://github.com/Ruby-on-Rails-Wizardry/fred), [ron](https://github.com/Ruby-on-Rails-Wizardry/ron), [harry](https://github.com/Ruby-on-Rails-Wizardry/harry), [george](https://github.com/Ruby-on-Rails-Wizardry/george)).
4. Update root **`package.json`** `workspaces` if JS workspaces change.
5. Keep **`docker-compose.yml`** app services (ports, `RAILS_RELATIVE_URL_ROOT`), **`nginx/nginx.conf`** locations, and **`docker/postgres/init-databases.sql`** in sync with `apps.yml` (MVP: manual; generation later).
6. Run `bin/setup` and `bin/compose up fred` (or any subset / all four).

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

**In:** Ubuntu + mise image, compose, shared Bundler/Yarn caches, config apps list, demo **fred / ron / harry / george**, **nginx path routing**, **Postgres + Redis**, host-matched container user, directory-based Compose project name.

**Later:** oauth2-proxy (see `partial/`), compose/nginx generation from `apps.yml`, shared path-gems, Redis-backed cable/cache if desired.

## License

Private template; no license asserted.
