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

bin/compose up
# Home   → http://localhost:8080/          (nginx; links to apps)
# Fred   → http://localhost:8080/fred/
# George → http://localhost:8080/george/
# Direct ports (debug): fred :3000, george :3001

# Shell in the image
bin/compose --profile dev run --rm dev
```

### Nginx path routing

`nginx` is the front door (port **8080**). It is intentionally simpler than `partial/nginx`: same path-proxy idea, **no oauth2-proxy**.

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

**In:** Ubuntu + mise image, compose, shared Bundler/Yarn caches, config apps list, demo fred/george, **nginx path routing** (`/`, `/fred/`, `/george/`).

**Later:** Postgres/Redis, oauth2-proxy (see `partial/`), compose/nginx generation from `apps.yml`, Arch image variant, full weasily submodule set (ron/harry + shared gem).

## License

Private template; no license asserted.
