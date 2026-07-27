# Changelog

All notable changes to **docker-mise-cluster** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Changed

### Fixed

### Security

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

[Unreleased]: https://github.com/Ruby-on-Rails-Wizardry/docker-mise-cluster/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Ruby-on-Rails-Wizardry/docker-mise-cluster/releases/tag/v0.1.0
