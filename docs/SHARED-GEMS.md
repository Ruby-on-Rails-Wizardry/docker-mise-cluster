# Shared gems: path in dev, published in deploy

How this cluster models a **shared library gem** used by multiple apps without
bootboot or dual lockfiles.

Demo gem: **[wizardry_shared](https://github.com/Ruby-on-Rails-Wizardry/wizardry_shared)**  
Helpers: **`bin/local-gem-env`**, **`config/apps.yml`** → `shared_gems`.

---

## Goal

| Environment | How the gem is resolved |
|-------------|-------------------------|
| **Deploy / CI lock truth** | Gemfile pins a **published version** (Nexus / rubygems, or git branch as a stand-in) |
| **Multi-app cluster dev** | **Same Gemfile line**; Bundler uses a **path checkout** via `local.*` |

Do **not** use Shopify **bootboot** for path-vs-published. Bootboot is for dual-booting
two full dependency graphs (`Gemfile.lock` / `Gemfile_next.lock`). Path override is a
different problem.

---

## Pattern (option 1 — Bundler `local.*`)

### 1. Gemfile pins the published form only

Real Nexus / private gem server (preferred in production apps):

```ruby
# Gemfile
source "https://your-nexus.example/repository/gems/" do
  gem "wizardry_shared", "0.1.0"
end
```

Or a single default source:

```ruby
gem "wizardry_shared", "0.1.0"
```

**Demo stand-in** (no Nexus yet). Use **git + `branch:`** — Bundler’s `local.*`
override requires a branch, not tag-only:

```ruby
# Shared library — pin published version (git branch + version stands in for Nexus).
# Cluster dev: bin/local-gem-env sets BUNDLE_LOCAL__WIZARDRY_SHARED → path checkout.
# Deploy: omit local.* override; Bundler uses the lock (git rev or published version).
gem "wizardry_shared", "0.1.0",
  git: "https://github.com/Ruby-on-Rails-Wizardry/wizardry_shared.git",
  branch: "master"
```

### 2. Register the checkout in the cluster

`config/apps.yml`:

```yaml
shared_gems:
  - name: wizardry_shared   # gem name (Bundler local.<name>)
    path: wizardry_shared   # directory under cluster root (usually a submodule)
```

### 3. Dev: set path override (ENV)

```bash
# Host
eval "$(bin/local-gem-env)"
bin/local-gem-env --print
# → BUNDLE_LOCAL__WIZARDRY_SHARED=/…/docker-mise-cluster/wizardry_shared

# Container (/work mount)
eval "$(bin/local-gem-env /work)"
# → BUNDLE_LOCAL__WIZARDRY_SHARED=/work/wizardry_shared
```

Bundler maps:

```text
local.wizardry_shared  →  env BUNDLE_LOCAL__WIZARDRY_SHARED
```

(hyphens → underscores, uppercased, double underscore after `LOCAL`).

### 4. Deploy / CI

- Do **not** run `local-gem-env`.
- Do **not** set `BUNDLE_LOCAL__*`.
- Lockfile + published source win.

---

## What this repo already wires

| Piece | Role |
|-------|------|
| `wizardry_shared/` | Submodule → own git repo |
| `config/apps.yml` → `shared_gems` | List of name/path pairs |
| `bin/local-gem-env` | Emit `export BUNDLE_LOCAL__…=path` (materialized from **cluster-tasks** via `wire`) |
| `bin/warm` | Host wrapper → cluster-tasks; `eval "$(…/local-gem-env /work)"` before bundle |
| `bin/docker-app` | Materialized for `/work`; same local-gem eval on app boot |
| `bin/setup` | Prints host overrides after seeding `.bundle/config` |
| App Gemfiles | Pin `wizardry_shared` `0.1.0` (git + branch demo form) |
| Home pages | `WizardryShared.hello("Fred")` (etc.) so the load path is visible |
| `BUNDLE_CLEAN=false` | Wire + warm keep multi-app shared `BUNDLE_PATH` from pruning siblings |

Private per-app `.bundle/config` (from `bin/ensure-bundle-config`) holds **behavior**
flags only. Path overrides stay in **ENV** so host vs `/work` paths do not fight
inside a committed config file.

Host implementation source: sibling **[cluster-tasks](https://github.com/Ruby-on-Rails-Wizardry/cluster-tasks)** (`../cluster-tasks/bin/wire --yes`).

---

## Day-to-day (standalone cluster + sibling tooling)

Work in a **standalone** cluster clone, not nested under `docker-mise/`:

```bash
# siblings
git clone git@github.com:Ruby-on-Rails-Wizardry/cluster-tasks.git
git clone --recurse-submodules \
  git@github.com:Ruby-on-Rails-Wizardry/docker-mise-cluster.git
cd docker-mise-cluster

# Submodules often detach HEAD; local.* wants a real branch
git -C wizardry_shared checkout master

../cluster-tasks/bin/wire --yes
task doctor
task warm          # sets BUNDLE_LOCAL__* inside the warm container
task up:all
```

Host-side bundle (optional):

```bash
eval "$(bin/local-gem-env)"
cd fred && bundle install
```

Recommended layout:

```text
Ruby-on-Rails-Wizardry/
├── docker-mise/                 # ubuntu-mise / alpine / arch only
│   └── ubuntu-mise/             # task build → ubuntu-mise:dev
├── cluster-tasks/               # sibling host tooling (wire)
└── docker-mise-cluster/         # this product
    ├── fred/ ron/ harry/ george/
    └── wizardry_shared/
```

---

## Why standalone (not nested under docker-mise)

Bundler `local.*` runs `git` **inside** the gem path. Submodules often store git
data as a **file**:

```text
wizardry_shared/.git  →  gitdir: ../.git/modules/wizardry_shared
```

| Checkout | What Docker mounts as `/work` | Result |
|----------|-------------------------------|--------|
| **Standalone** `docker-mise-cluster` | Whole clone | `../.git/modules/…` stays **inside** the mount → `local.*` works |
| **Nested** `docker-mise/cluster` submodule | Only the cluster tree | gitdir points **into parent** `docker-mise/.git` **outside** the mount → `git rev-parse` fails |

So: develop the cluster as **`../docker-mise-cluster`**, not as a submodule of the
umbrella. The umbrella no longer vendors `cluster/` for this reason.

---

## Requirements checklist

| Requirement | Why |
|-------------|-----|
| Standalone cluster clone (`--recurse-submodules`) | gitdir under `/work` |
| Gemfile uses **`branch:`** for git sources (not tag-only) | Bundler local override rule |
| Shared gem on a real branch (`git -C … checkout master`) | Detached submodule HEAD confuses local overrides |
| Gemspec version matches Gemfile pin (`0.1.0`) | Resolution must agree |
| No `BUNDLE_LOCAL__*` in production | Deploy must not look for `/work/…` |
| `BUNDLE_CLEAN=false` if apps share `BUNDLE_PATH` | Sibling apps’ gems must not be pruned |

---

## Add another shared gem

1. Create the gem’s **own repo**; set version in the gemspec.  
2. Add submodule under the cluster, e.g. `my_gem/`.  
3. Register in `config/apps.yml`:

   ```yaml
   shared_gems:
     - name: wizardry_shared
       path: wizardry_shared
     - name: my_gem
       path: my_gem
   ```

4. In **each** app Gemfile, pin the published form only (Nexus or git+branch).  
5. Run `task warm` (or `eval "$(bin/local-gem-env /work)"` + `bundle install`).  
6. Commit app `Gemfile` / `Gemfile.lock` and the cluster submodule pin.  

`bin/local-gem-env` picks up new `shared_gems` entries automatically — no change to
warm/docker-app required.

---

## Manual equivalent (without `local-gem-env`)

```bash
cd fred
bundle config set --local local.wizardry_shared /work/wizardry_shared
```

That writes `fred/.bundle/config`. Prefer ENV via `bin/local-gem-env` in this
cluster so host absolute paths and container `/work/…` stay separate.

---

## Optional: `.bundle/config` vs ENV

| Approach | Pros | Cons |
|----------|------|------|
| **ENV `BUNDLE_LOCAL__*`** (this repo) | Host vs container paths; no commit of machine paths | Must set in warm / docker-app / host shell |
| **`bundle config set --local local.*`** | Persists per app | Absolute path in `.bundle/config` often wrong on the other side of Docker |

---

## Troubleshooting

| Symptom | Likely cause |
|---------|----------------|
| `Cannot use local override … :branch is not specified` | Gemfile used `tag:` only; use `branch:` (or pure rubygems version pin) |
| `git rev-parse` failed under `/work/…` | Nested monorepo submodule; use standalone cluster clone |
| Override ignored / still cloning remote | `BUNDLE_LOCAL__*` not set in that process; re-check warm/docker-app |
| Version conflict | Gemspec `VERSION` ≠ Gemfile pin |
| Deploy tries a path | `BUNDLE_LOCAL__*` leaked into the image or CI env |

---

## Related

- [docs/ADOPT.md](ADOPT.md) — adopting the template into a real project  
- [wizardry_shared README](https://github.com/Ruby-on-Rails-Wizardry/wizardry_shared#readme)  
- [Bundler: local git repos](https://bundler.io/guides/git.html#local-git-repos) (`bundle config local.*`)  
