# Changelog

All notable changes to **docker-mise-cluster** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- [Taskfile.yml](Taskfile.yml) host UX (`task setup`, `task up:fred`, `task compose`, …); pin **Task 3.52.0** in [mise.toml](mise.toml)

### Changed

- **fred** and **george** are independent git repos and **submodules** of this cluster ([fred](https://github.com/Ruby-on-Rails-Wizardry/fred), [george](https://github.com/Ruby-on-Rails-Wizardry/george)); clone with `--recurse-submodules`

### Fixed

### Security

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

[Unreleased]: https://github.com/Ruby-on-Rails-Wizardry/docker-mise-cluster/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/Ruby-on-Rails-Wizardry/docker-mise-cluster/releases/tag/v0.2.0
[0.1.0]: https://github.com/Ruby-on-Rails-Wizardry/docker-mise-cluster/releases/tag/v0.1.0
