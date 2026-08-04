# Changelog

All notable changes to **docker-mise-cluster** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Changed

- `bin/warm` more resilient for multi-app + Bundler plugins (`bootboot`): shared
  `BUNDLE_USER_HOME=/cache/bundler`, per-Gemfile failure isolation, one retry,
  optional `WARM_ISOLATE_BUNDLE=1` for per-app `BUNDLE_PATH`

### Fixed

### Security

## [0.8.0] - 2026-08-03

### Added

- `docs/ADOPT.md` — how to use this template in a real project
- `nginx/Dockerfile` — local **`cluster-nginx:dev`** (config baked in)

### Changed

- DBs via Rails `db:prepare` only (no `init-databases.sql` mount)
- No compose healthchecks; start-order `depends_on`; apps wait for Postgres in `bin/docker-app`
- Nginx from local image (`pull_policy: never`) with baked config
- Compose no longer re-declares image ENV (`CACHE_ROOT` / `MISE_*` / …); start via `/work/bin/docker-app`
- Docs and comments match current layout (single `/cache` volume, topology-only compose)

### Fixed

### Security

## [0.7.0] - 2026-08-03

### Added

- Four-app layout: **fred**, **ron**, **harry**, **george** (submodules + compose + nginx + Postgres DBs)
- New demo repos [ron](https://github.com/Ruby-on-Rails-Wizardry/ron) and [harry](https://github.com/Ruby-on-Rails-Wizardry/harry)
- Task shorthands: `up:ron`, `up:harry`, `db:reset:ron`, `db:reset:harry`, app-scoped `task ron -- …` / `task harry -- …`
- **`bin/warm` / `task warm`**: crawl Gemfile + package.json inside the image; fill shared volume **`cache`**

### Changed

- App ports start at **3001**: fred 3001, ron 3002, harry 3003, george 3004 (simple path prefixes `/fred` … `/george`)
- **Compose project name** is no longer forced to `docker-mise-cluster` — Docker uses the directory basename
- **No run-time user/UID overrides** — identity from ubuntu-mise image build only
- Rename **`docker-compose.yml` → `compose.yml`**; Compose default file discovery
- **DRY app services** via `x-app` anchor
- **Single cache model:** Docker volume named **`cache`** → `/cache` (mise, gems, yarn). Drop host `.cache` + `config/cache-layout.env` dual path
- Getting started: **build → warm → up**
- Docs: Ubuntu-first four-app template

### Fixed

### Security

**Migration:** existing Compose stacks named `docker-mise-cluster` become a new project (`cluster` under the umbrella, or `wf` when cloned that way). Optional cleanup: `docker compose -p docker-mise-cluster down`. New Postgres DBs (ron/harry) need a fresh `pgdata` volume or manual `CREATE DATABASE` if an old volume is reused.


## [0.6.0] - 2026-07-30

### Added

- Cluster host UX aligned with ubuntu-sample: `.mise.env` (`POSTGRESQL_VERSION=18`, `IMAGE=ubuntu-mise:dev`), `bin/lib.sh`, `bin/mise-host-env.sh`, `bin/config` / `doctor` / cache helpers
- Expanded Taskfile + mise tasks for multi-app up (`up:fred`, `up:george`, `up:all`), nginx-aware doctor, and app-scoped `task fred -- …` / `task george -- …`

### Changed

- Dev apps use **prebuilt `ubuntu-mise:dev` only** (`pull_policy: never`) — no cluster image build layer for fred/george/dev
- Shared `/cache` volume defaults to **`ubuntu-mise-cache`** (same name as ubuntu-mise)
- `bin/compose` writes `.env` (IMAGE, POSTGRESQL_VERSION, IMAGE_USER, …) and ensures the base image exists

### Fixed

### Security


## [0.5.0] - 2026-07-29

### Added

- Document production deploy topology: **two Kamal apps on one VPS**, hostname routing via kamal-proxy; cluster compose is **dev-only** ([AGENTS.md](AGENTS.md#production-deployment-kamal--not-compose))

### Changed

- Dockerfile: single early `COPY --chmod=755 docker/ /docker/` (keep scripts; no `/tmp` stage-and-rm)
- Host TZ detection aligned with flavors (Linux / macOS / WSL-safe localtime resolve)
- Compose services set `hostname` to match the service name (`db`, `redis`, `nginx`, `dev`, `fred`, `george`)
- Leave `/var/lib/apt/lists` after PostgreSQL client install (reuse apt index)

### Fixed

### Security

## [0.3.1] - 2026-07-27

### Added

- `bin/db-reset` + Task shorthands (`task db:reset:fred`, `task db:reset:george`, `task db:reset -- <apps>`) to reset one app’s Postgres database without full `bin/setup --reset`

### Changed

- Locked mise policy: **dev** = runtime `mise install` into `/cache`; **prod default** = no mise (official multi-stage images); **if prod uses mise** = builder-only, start server without install/activate ([AGENTS.md](AGENTS.md))
- Cluster dev image no longer bakes language tools at build; `bin/docker-app` runs `mise install` at start; compose mounts `mise-cache` → `/cache`

## [0.3.0] - 2026-07-27

### Changed

- **fred** / **george** / **dev** app image is a thin layer on local **ubuntu-mise** (`BASE_IMAGE`, default `ubuntu-mise:dev`) plus PostgreSQL client/libpq — no longer a full Ubuntu+mise rebuild
- `bin/setup --docker-build` and `task build` ensure the ubuntu-mise base exists (sibling `../ubuntu-mise` or `UBUNTU_MISE_ROOT`) before building `CLUSTER_IMAGE` (`wf-dev:latest`)
- Project mount / `WORKSPACE` standardized on **`/work`** (was `$HOME/wf`); aligns with ubuntu-mise

## [0.2.1] - 2026-07-27

### Added

- [Taskfile.yml](Taskfile.yml) host UX (`task setup`, `task up:fred`, `task compose`, …); pin **Task 3.52.0** in [mise.toml](mise.toml)

### Changed

- **fred** and **george** are independent git repos and **submodules** of this cluster ([fred](https://github.com/Ruby-on-Rails-Wizardry/fred), [george](https://github.com/Ruby-on-Rails-Wizardry/george)); clone with `--recurse-submodules`
- Expand `.gitignore` Vim artifact coverage (`*~`, `*.swp`/`*.swo`/`*.swn`, `Session.vim`, `.netrwhist`)
- Pin [fred](https://github.com/Ruby-on-Rails-Wizardry/fred) and [george](https://github.com/Ruby-on-Rails-Wizardry/george) for matching Vim ignores

## [0.2.0] - 2026-07-27

### Added

- Compose **Postgres 18** (`db`) and **Redis 8** (`redis`) with published ports 5432 / 6379
- Per-app databases via `docker/postgres/init-databases.sql` (`fred_*`, `george_*`)
- Fred/George: `pg` + `redis` gems; development/test `database.yml` for PostgreSQL; `DATABASE_URL` / `REDIS_URL` from compose
- `bin/docker-app` waits for Postgres, runs `db:prepare`, and aborts unless ActiveRecord adapter is `postgresql`
- `apps.yml` documents per-app `database` / `redis_db`

### Changed

- MVP services now include shared data stores (not only nginx + app processes)
- Yarn install failures no longer block Rails boot (JS is optional for the server process)
- **Nginx first:** apps `depends_on` nginx (+ db/redis); nginx no longer waits for apps — `bin/compose up fred` (or `george`) brings only that app’s stack

## [0.1.0] - 2026-07-27

First tagged release of the multi-app Docker + mise cluster template.

### Added

- **Nginx path proxy** on port **8080**: home page at `/` with links to apps; `/fred/` → fred; `/george/` → george (no oauth2; pattern simplified from `partial/nginx`)
- `url_root` in `config/apps.yml`; compose sets `RAILS_RELATIVE_URL_ROOT` for each app
- `MISE_TRUSTED_CONFIG_PATHS` for bind-mounted project configs; `bin/docker-app` trusts cluster + app dirs before activate
- App-local `fred/mise.toml` / `george/mise.toml`; Ruby version from each Gemfile via idiomatic version files (Ruby **4.0.6**)

### Fixed

- Docker image build: copy root `Gemfile` so `mise install` installs Ruby (not only Node/Yarn)
- Untrusted `fred/mise.toml` / `george/mise.toml` under the host bind mount

[Unreleased]: https://github.com/Ruby-on-Rails-Wizardry/docker-mise-cluster/compare/v0.8.0...HEAD
[0.8.0]: https://github.com/Ruby-on-Rails-Wizardry/docker-mise-cluster/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/Ruby-on-Rails-Wizardry/docker-mise-cluster/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/Ruby-on-Rails-Wizardry/docker-mise-cluster/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/Ruby-on-Rails-Wizardry/docker-mise-cluster/compare/v0.3.1...v0.5.0
[0.3.1]: https://github.com/Ruby-on-Rails-Wizardry/docker-mise-cluster/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/Ruby-on-Rails-Wizardry/docker-mise-cluster/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/Ruby-on-Rails-Wizardry/docker-mise-cluster/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/Ruby-on-Rails-Wizardry/docker-mise-cluster/releases/tag/v0.2.0
[0.1.0]: https://github.com/Ruby-on-Rails-Wizardry/docker-mise-cluster/releases/tag/v0.1.0
