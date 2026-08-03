# wf — multi-app Docker dev cluster (Ubuntu template)

Template for a **multi-app Rails development cluster** on **Ubuntu** (local Docker Compose). **Production** uses **Kamal** per app — see [AGENTS.md](AGENTS.md#production-deployment-kamal--not-compose).

## Quick start

```bash
cd ../ubuntu-mise && task build && cd -
mise install && task doctor
task warm                 # fill volume `cache` → /cache (crawl Gemfile / package.json)
task up:fred              # or: task up:all
# http://localhost:8080/fred/   … /ron/ /harry/ /george/
# direct: :3001 … :3004
```

| Step | What |
|------|------|
| **build** | `ubuntu-mise:dev` once (host USER/UID at build) |
| **warm** | Shared Docker volume **`cache`** → `/cache` (mise, gems, yarn) |
| **up** | Compose apps + nginx + db + redis |

Always use **`bin/compose`** / **`task`** so the base image and volume exist.

## What’s included

- Prebuilt **ubuntu-mise:dev** (`pull_policy: never`) for fred, ron, harry, george, optional `dev`
- **One cache volume** named `cache` mounted at `/cache` (image layout for mise + Bundler + Yarn)
- nginx path routing `/fred/` … `/george/` + Postgres + Redis
- `config/apps.yml` app list; git submodules for app repos
- Compose project name = **directory basename**

Clone with apps:

```bash
git clone --recurse-submodules -b master \
  git@github.com:Ruby-on-Rails-Wizardry/docker-mise-cluster.git
git submodule update --init --recursive   # after plain clone
```

## Layout

```
cluster/   # or wf/ — directory name = Compose project name
├── compose.yml               # apps + nginx + db + redis; volume cache → /cache
├── config/apps.yml           # app list (ports, url_root, databases)
├── bin/warm                  # crawl tree, install into volume cache
├── bin/setup                 # warm (+ optional host db:prepare)
├── bin/compose               # compose wrapper
├── fred/ ron/ harry/ george/ # app submodules
└── nginx/
```

## Cache

| | |
|--|--|
| Docker volume | **`cache`** (override only if needed: `CACHE_VOLUME=…`) |
| Mount | `/cache` |
| Contents | mise tools, `bundle`, rubygems, yarn (see ubuntu-mise image ENV) |
| Fill | **`task warm`** / `bin/warm` (container crawl of Gemfile + package.json) |
| Reset | `task cache:reset -- -y` |

There is no separate host `.cache` tree for containers. Host and Mac/WSL all warm the same volume via the image.

## Apps

| App | Port | Path | Database | Redis DB |
|-----|------|------|----------|----------|
| fred | 3001 | `/fred` | `fred_development` | 0 |
| ron | 3002 | `/ron` | `ron_development` | 1 |
| harry | 3003 | `/harry` | `harry_development` | 2 |
| george | 3004 | `/george` | `george_development` | 3 |

```bash
task up:fred
task up:all
task compose -- ps
task db:reset:fred
bin/compose --profile dev run --rm dev
```

Front door: **http://localhost:8080/**  
Postgres **5432** / Redis **6379** (dev credentials in `.env.example`).

## Adopting into a real project

Full guide: **[docs/ADOPT.md](docs/ADOPT.md)** (what to copy, what to rewrite, Nexus/images, bring-up).

Short version:

1. Clone/copy as **`wf/`** with real app submodules (not necessarily the demo apps).
2. Align **`config/apps.yml`**, **`compose.yml`**, **`nginx/`**, and DB setup for each app.
3. Build **`ubuntu-mise:dev`**, then `task warm` → `task up:…`.

## License

Private template; no license asserted.
