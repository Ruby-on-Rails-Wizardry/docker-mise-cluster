# Agent guide — wf (multi-app Docker cluster template)

## Purpose

`wf/` is the **product template**: a copyable/cloneable starting point for multi-app Rails Docker development with shared Bundler + classic Yarn 1 caches.

Reference trees (do not treat as the product):

- `../partial/` — anonymized real weasily/wf cluster (nginx, oauth2, postgres, submodules)
- `../experment/` — cache experiment; use branch **`dry-yarn-1`** for classic Yarn patterns

## Decisions (locked for MVP)

| Decision | Choice |
|----------|--------|
| Product shape | **Template** — clone, copy, or untar into a project |
| App layout | **Git submodules** (demo apps vendored until replaced) |
| Base image | **Ubuntu 24.04 LTS** + mise; layout: `/home/$USER` + **`$HOME/wf`** (`USER` / `DEV_UID` / `DEV_GID` build args) |
| Yarn | **Classic 1.22.x** (not Berry) |
| MVP services | Image + compose + shared gem/yarn caches only |
| Apply to weasily | New `wf/` tree; leave `partial/` as reference |

## Rules

1. Cache paths only in **`config/cache-layout.env`**; use **`bin/cache-env`** / **`bin/compose`**.
2. App list only in **`config/apps.yml`**; `bin/setup` and `bin/apps` read it. Keep compose services in sync for MVP.
3. Bundler flags only in **`config/bundler-flags.yml`** (symlinked as `.bundle/config`).
4. Do **not** set `BUNDLE_APP_CONFIG` to the cluster root when running app Gemfiles.
5. Prefer `bundle install --local` / yarn `--offline` before network.
6. Image user defaults to **`dev`** (`USER` arg); project mount / WORKDIR is **`$HOME/wf`** (`WORKSPACE`).
7. Do not commit `.cache/**` contents (only `.gitkeep`).
8. Do not introduce Yarn Berry in this template.

## Common tasks

```bash
bin/setup
bin/setup --docker-build
bin/compose up fred george
bin/compose --profile dev run --rm dev
bin/apps yaml
source bin/cache-env && cd fred && bin/rails console
```
