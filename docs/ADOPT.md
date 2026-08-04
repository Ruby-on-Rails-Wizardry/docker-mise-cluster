# How to use this cluster template in a real project

This repo (**docker-mise-cluster**) is a **dev multi-app shell**: Compose, nginx path routing, shared Postgres/Redis, and a single Docker volume `cache` for mise/gems/yarn. Demo apps (fred / ron / harry / george) prove the wiring; they are not the product.

Typical layout when adopting: clone or copy this tree as **`work/`** (directory name becomes the Compose project name).

## What to bring over

Copy the **orchestration layer** as a unit:

| Path | Role |
|------|------|
| `bin/` | `compose`, `warm`, `docker-app`, `apps`, `doctor`, `db-reset`, `lib.sh`, … |
| `compose.yml` | Stack + shared `x-app` + volume `cache` |
| `config/apps.yml` | App list + `shared_gems` (rewrite for your apps) |
| `config/bundler-flags.yml` | Default Bundler flags (seeded into each app’s private `.bundle/config`) |
| `bin/local-gem-env` | Dev path overrides for shared gems (`BUNDLE_LOCAL__*`) |
| `nginx/` | Path reverse proxy + home page |
| `docker/postgres/` | Optional notes (Rails `db:prepare` creates DBs by default) |
| `nginx/Dockerfile` | Local nginx image build |
| `Taskfile.yml`, `mise.toml`, `.mise.env` | Host tasks + defaults |
| Root `package.json` / `yarn.lock` | Yarn workspaces (adjust names) |
| `.gitignore`, `.dockerignore`, `.env.example` | Hygiene |
| `.gitmodules` | Point at **your** app repos |

Skip: `node_modules/`, generated `.env`, app `tmp/` / `log/`, and demo app checkouts if you replace them immediately.

## What to replace

| Demo piece | Real project |
|------------|--------------|
| `fred/`, `ron/`, `harry/`, `george/` submodules | Your app git submodules (same relative paths or rename everywhere) |
| Demo ports/paths | Your ports, `url_root` prefixes, DB names |
| Public Hub images for `db` / `redis` / `nginx` | Corp registry (e.g. Nexus) or preloaded local tags — see [Images (restrained networks)](#images-restrained-networks) |

You do **not** need to copy whole demo Rails apps if yours already run. Apps only need to boot under compose env (`DATABASE_URL`, `RAILS_RELATIVE_URL_ROOT`, shared `/cache` Bundler path) via `bin/docker-app` or an equivalent.

## Keep four places in sync per app

For every app:

1. **`config/apps.yml`** — `name`, `path`, `port`, `url_root`, `database`, `redis_db`
2. **`compose.yml`** — service deltas under `x-app` (`working_dir`, ports, `RAILS_RELATIVE_URL_ROOT`, `DATABASE_URL`, `REDIS_URL`)
3. **`nginx/nginx.conf`** (+ links in **`nginx/html/index.html`**)
4. **DB setup** — Rails `db:prepare` creates DBs if missing (compose superuser); optional SQL init only if you reintroduce it

Also update:

- **`.gitmodules`** — real remotes and branches  
- **`package.json` `workspaces`** — real app directory names  
- **`Taskfile.yml`** — `up:*` / `db:reset:*` / `task <app>` if you keep shortcuts  

Path prefixes often **differ** from directory names in real systems (e.g. `/activity` vs `ron/`). Set `url_root` to the **browser path**, not necessarily the folder name.

## Shared library gems (path in dev, published in deploy)

Full write-up: **[docs/SHARED-GEMS.md](SHARED-GEMS.md)** (pattern, day-to-day, add a gem, troubleshooting).

Short version: Gemfile pins the **published** form; cluster dev uses
`bin/local-gem-env` → `BUNDLE_LOCAL__*` path override. Do not use bootboot for this.
Demo: **wizardry_shared** + `shared_gems` in `config/apps.yml`. Work in a
**standalone** `docker-mise-cluster` clone (not nested under `docker-mise/`).

## Host base image (ubuntu-mise)

Apps run **`ubuntu-mise:dev`** with `pull_policy: never`. On each machine:

```bash
# sibling under docker-mise umbrella, or a standalone ubuntu-mise clone
cd ../ubuntu-mise   # or UBUNTU_MISE_ROOT=…
task build          # host USER/UID baked in — no run-time user knobs
```

Host UX on the base image (separate commands, no setup flags):

```bash
task config         # optional — show deduced values
task build          # → ubuntu-mise:dev
task warm           # this tree
task warm:sample    # optional: sibling Rails sample
```

## Cluster bring-up

```bash
cd work               # this tree
mise install          # Task, etc. on host if you use Task
task warm             # fill Docker volume `cache` → /cache (crawl Gemfile / package.json)
task up:all           # or task up:fred / bin/compose up …
# http://localhost:8080/…
```

| Step | What |
|------|------|
| **build** (once) | `ubuntu-mise:dev` for this host |
| **warm** | Shared volume **`cache`** (mise, gems, yarn) |
| **up** | Compose apps + nginx + db + redis |

Always use **`bin/compose`** / **`task`** so the image and volume exist. Compose project name = **directory basename** (no `COMPOSE_PROJECT_NAME` required).

## Cache model

| | |
|--|--|
| Volume | Named **`cache`** (external; created by `bin/warm` / `bin/cache-ensure`) |
| Mount | `/cache` inside containers |
| Layout | Image ENV: mise, `bundle`, rubygems, yarn under `/cache` |
| Fill | **`task warm`** — container crawl of project-root `Gemfile` / `package.json` (maxdepth 2) |

No dual host `.cache` tree for containers. Do not reintroduce host gem paths as the SSOT.

## Images (restrained networks)

Public defaults use Docker Hub short names for shared services:

| Service | Public default | Issue offline / corp |
|---------|----------------|----------------------|
| apps / dev | `ubuntu-mise:dev` (`pull_policy: never`) | Build locally |
| db | `postgres:N` | Pulls Hub (CloudFront) if missing |
| redis | `redis:N-alpine` | same |
| nginx | **`cluster-nginx:dev`** via `nginx/Dockerfile` (`pull_policy: never`) | `bin/compose build nginx` |

Corp environments (see anonymized **`partial/`** under docker-mise) use full registry URLs, e.g.:

```yaml
db:
  image: nexus.example.com:8132/postgres:17
redis:
  image: nexus.example.com:8132/redis:8.x
nginx:
  image: nginx-local:latest   # or nexus-hosted nginx
```

Prefer a **`local`** branch or `compose.override.yml` for Nexus tags so public `master` stays Hub-friendly. Preload tags and set `pull_policy: never` if you cannot reach Hub at all.

## What each real app should support

| Concern | Dev contract |
|---------|----------------|
| Mount | App lives under cluster root; compose `working_dir: /work/<path>` |
| Tools | Runtime `mise install` into volume `/cache` |
| Gems | `BUNDLE_PATH` / cache under `/cache` (image defaults); each app has private `.bundle/config` |
| Boot | `bin/docker-app` or equivalent: bundle, optional yarn, wait for Postgres, `db:prepare`, `rails s` |
| Path prefix | `RAILS_RELATIVE_URL_ROOT` from compose |
| Health | `/up` or adjust nginx/docs if you change it |

Production remains **per-app Kamal** (hostname routing), not this compose file — see [AGENTS.md](../AGENTS.md#production-deployment-kamal--not-compose).

## Related references

| Tree | Role |
|------|------|
| This repo | Dev multi-app template |
| `../ubuntu-mise` (umbrella) | Base image + host UX |
| `../partial/` (umbrella) | Anonymized real multi-app cluster (oauth2, Nexus-style images) — patterns only |

## Checklist

- [ ] `work/` layout: tooling + real app submodules  
- [ ] `.gitmodules` → real remotes  
- [ ] `apps.yml` + `compose.yml` + nginx + DB setup aligned  
- [ ] `ubuntu-mise:dev` built on this host  
- [ ] db/redis/nginx images available (Hub, Nexus, or local)  
- [ ] `task warm` then `task up:…`  
- [ ] Site-local Nexus/proxy on `local` branch if needed  
