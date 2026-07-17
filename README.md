# wf — multi-app Docker dev cluster (template)

Template starting point for a **multi-app Rails development cluster** with:

- **Ubuntu 24.04 LTS** image + **mise** (Ruby / Node / classic **Yarn 1.22**)
- Shared **Bundler** install + download caches across all apps
- Shared **Yarn 1** offline mirror + cache folder
- **Config-driven** app list (`config/apps.yml`)
- **Git submodules** for independent app (and shared gem) repos
- Layout: container user home at `/home/$USER` (default `dev`), project mount / WORKDIR at **`$HOME/wf`**

Clone this tree, copy it, or untar it into an existing umbrella project, then edit `config/apps.yml` and submodule URLs.

## Layout

```
wf/
├── config/
│   ├── apps.yml              # SSOT: apps + shared gems
│   ├── cache-layout.env      # SSOT: relative cache paths
│   └── bundler-flags.yml     # SSOT: Bundler behavior (symlinked as .bundle/config)
├── bin/
│   ├── setup                 # host bootstrap + warm caches
│   ├── cache-env             # export absolute BUNDLE_* / YARN_* paths
│   ├── compose               # docker compose with cache-layout.env
│   ├── apps                  # read config/apps.yml
│   └── docker-app            # container entry: prefer local caches
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

bin/compose up fred george
# Fred   → http://localhost:3000
# George → http://localhost:3001

# Shell in the image
bin/compose --profile dev run --rm dev
```

Always use **`bin/compose`** (not plain `docker compose`) so `config/cache-layout.env` is loaded.

## Adopting into a real project

1. Copy/clone/untar this `wf/` tree into your umbrella repo (or use it as the repo root).
2. Edit **`config/apps.yml`** — names, paths, ports.
3. Replace demo apps with **git submodules** (see `.gitmodules.example`).
4. Update root **`package.json`** `workspaces` if JS workspaces change.
5. Keep **`docker-compose.yml`** app services in sync with `apps.yml` (MVP: manual; generation later).
6. Run `bin/setup` and `bin/compose up`.

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

**In:** Ubuntu + mise image, compose, shared Bundler/Yarn caches, config apps list, demo fred/george.

**Later:** nginx path routing, Postgres/Redis, oauth2-proxy, compose generation from `apps.yml`, Arch image variant, full weasily submodule set (ron/harry + shared gem).

## License

Private template; no license asserted.
