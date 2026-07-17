# arch-mise

Minimal **Arch Linux** development image: non-root user, **mise**, multi-shell login activation, and a shared **`/cache`** for Ruby / Node / Python package downloads.

## Quick start

**Prerequisites:** Docker. [Task](https://taskfile.dev) is recommended; `bin/*` works without it.

```bash
cd arch-mise

task setup          # build image + cache volume + best-effort warm
task shell          # login shell; this dir (or PROJECT) mounted at /work
```

Without Task:

```bash
./bin/setup
./bin/shell
```

### Sample project (this repo)

With no `PROJECT=…`, the flavor directory is the sample at `/work`. Setup warms mise, Bundler, Yarn, and pip from the committed sample files, then smoke-checks tools and `/cache` wiring:

```bash
task setup
task run -- ./scripts/smoke.sh
# Compose parallel path:
task compose:setup
task compose:run -- ./scripts/smoke.sh
```

Same with `bin/*`:

```bash
./bin/setup
./bin/run ./scripts/smoke.sh
```

Use the image against **another project**:

```bash
PROJECT=/path/to/my-app task setup
PROJECT=/path/to/my-app task shell
# or
PROJECT=/path/to/my-app ./bin/shell
```

## Default tools (`mise.toml`)

When this directory is the project (`task setup` / `task shell` here), [mise.toml](mise.toml) pins common-dev versions:

| Tool | Version | Notes |
|------|---------|--------|
| Ruby | 3.4.10 | Current 3.4 line (Rails / gems) |
| Node.js | 24.18.0 | Active LTS |
| Yarn | 1.22.22 | Classic; Berry via `mise use yarn@4` |
| Python | 3.13.14 | Current 3.13 line |

`task warm` runs `mise install` into `/cache/mise`. **App repos should use their own `mise.toml`** when you set `PROJECT=…`.

Ruby installs prefer **precompiled** binaries (`ruby.compile = false` / `MISE_RUBY_COMPILE=false`) for speed. The image still ships a full compile toolchain (`base-devel`, OpenSSL/YAML/zlib headers, …) so ruby-build, native gems, and Python/Node extensions can build when needed.

Starter sample files (same in all flavors; for warm + [scripts/smoke.sh](scripts/smoke.sh)):

| File | Purpose |
|------|---------|
| [Gemfile](Gemfile) / lock | Rails **~> 8.1.3**, RuboCop **~> 1.88**, Brakeman **~> 8.0** → `bundle install` |
| [package.json](package.json) / [yarn.lock](yarn.lock) | Tiny Yarn classic dep (`ms`) → `yarn install` |
| [requirements.txt](requirements.txt) | `requests` → `pip install` |

## Two ways to run (parallel)

Same mounts either way: **project → `/work`**, **named volume → `/cache`**.

| Path | Setup | Shell | One-shot |
|------|--------|--------|----------|
| **docker run** (default) | `task setup` / `./bin/setup` | `task shell` / `./bin/shell` | `task run -- cmd` |
| **Compose** | `task compose:setup` / `./bin/compose-setup` | `task compose:shell` / `./bin/compose-shell` | `task compose:run -- cmd` |

Use **Compose** when you want overrides, multi-service later, or `compose config`. Use **docker run** for the simplest path.

```bash
# Compose path
task compose:setup
task compose:shell
# or
./bin/compose build
./bin/compose run --rm dev bash -l
PROJECT=/path/to/app ./bin/compose run --rm dev bash -l
```

`bin/compose` regenerates `.env` each run (host UID/GID + absolute `PROJECT_MOUNT`). See `compose.env.example`. Do not commit `.env`.

## Daily commands

### docker run path

| Task | bin | Purpose |
|------|-----|---------|
| `task setup` | `bin/setup` | Build, ensure cache volume, warm |
| `task build` | `bin/build` | Build/refresh image |
| `task shell` | `bin/shell` | Interactive login shell |
| `task run -- cmd` | `bin/run cmd` | One-shot command in the image |
| `task warm` | `bin/warm` | mise + detect Gemfile/yarn/npm/pip/uv |
| `task cache:ensure` | `bin/cache-ensure` | Create Docker volume for `/cache` |
| `task cache:reset -- -y` | `CONFIRM=1 bin/cache-reset` | Delete cache volume |
| `task verify` | `bin/verify` | Login shells + `/cache` self-checks |
| `task doctor` | `bin/doctor` | Host/Docker sanity |
| `task config` | `bin/config` | Print `IMAGE`, volume, `PROJECT`, UID |

### Compose path

| Task | bin | Purpose |
|------|-----|---------|
| `task compose:setup` | `bin/compose-setup` | Compose build + warm |
| `task compose:build` | `bin/compose build` | `docker compose build` |
| `task compose:shell` | `bin/compose-shell` | `compose run --rm dev bash -l` |
| `task compose:run -- cmd` | `bin/compose run --rm dev …` | One-shot via compose |
| `task compose:up` | `bin/compose up` | Attach to `dev` service |
| `task compose:down` | `bin/compose down` | Stop (volumes kept) |
| `task compose:config` | `bin/compose config` | Resolved compose file |
| `task compose -- …` | `bin/compose …` | Pass-through |

## Layout inside the container

| Path | Role |
|------|------|
| `/work` | Your project (`PROJECT` or `$PWD` on the host) |
| `/cache` | Shared package + mise tool cache (named Docker volume) |
| `/home/dev` | Image user home (default user name `dev`) |

### `/cache` contents

| Dir | Used by |
|-----|---------|
| `mise/`, `mise-cache/` | mise tool installs |
| `xdg-state/` | mise trust + other XDG state (`XDG_STATE_HOME`; survives new containers) |
| `bundle/`, `rubygems/` | Bundler (shared path; install does **not** auto-clean unused gems) |
| `yarn/`, `yarn-cache/`, `yarn-global/` | Yarn 1 offline mirror + cache; Yarn Berry global |
| `npm/` | npm |
| `pip/`, `uv/`, `poetry/` | Python package caches |

Helpers: `cache-env`, `cache-env --write-yarnrc`, `--write-yarnrc-yml`, `--write-npmrc`, `--write-pip-conf`, `--link-bundler`.

## UID / GID

By default `bin/build` passes your host `id -u` / `id -g` so bind mounts under `/work` are writable.

```bash
DEV_UID=1000 DEV_GID=1000 task build   # force classic 1000:1000
```

Rebuild if you change UID, or file ownership on mounts will not match.

## Yarn 1 vs Berry / pip vs uv

- **Yarn 1:** `YARN_CACHE_FOLDER` + offline offline mirror (`cache-env --write-yarnrc`)
- **Yarn Berry:** `YARN_GLOBAL_FOLDER` + `YARN_ENABLE_GLOBAL_CACHE` (env set; optional `--write-yarnrc-yml`)
- **pip / uv / poetry:** separate dirs under `/cache`; env is enough for most installs

Do not share one cache volume between **Alpine** and **Ubuntu/Arch** for native extensions (musl vs glibc).

## Overrides

```bash
IMAGE=ghcr.io/me/arch-mise:dev \
CACHE_VOLUME=my-team-cache \
PROJECT=$HOME/src/app \
task shell
```

## Without Task or bin

```bash
docker build -t arch-mise:dev \
  --build-arg DEV_UID=$(id -u) --build-arg DEV_GID=$(id -g) .

docker volume create arch-mise-cache

docker run --rm -it \
  -v "$PWD":/work -w /work \
  -v arch-mise-cache:/cache \
  arch-mise:dev
```

## Use as a git submodule (recommended)

**Default clone URL is GitHub.** GitLab is a backup mirror of the same `master` branch.

| Remote | Role | URL |
|--------|------|-----|
| **github** (default) | fetch + primary push | `git@github.com:Ruby-on-Rails-Wizardry/arch-mise.git` |
| **gitlab** (backup) | mirror / disaster recovery | `git@gitlab.com:ruby-on-rails-wizardry/arch-mise.git` |

### Add to your app repo

```bash
# From your application repository root:
git submodule add -b master \
  git@github.com:Ruby-on-Rails-Wizardry/arch-mise.git \
  arch-mise

git submodule update --init --recursive
```

HTTPS clone (CI / no SSH):

```bash
git submodule add -b master \
  https://github.com/Ruby-on-Rails-Wizardry/arch-mise.git \
  arch-mise
```

Then work from the submodule (or point `PROJECT` at the app root):

```bash
cd arch-mise
task setup && task shell
# develop against the parent app:
PROJECT=.. task shell
```

### Clone only this image repo

```bash
git clone -b master git@github.com:Ruby-on-Rails-Wizardry/arch-mise.git
cd arch-mise
# optional: wire GitLab backup + dual-push (see below)
./bin/setup-remotes
```

### After cloning: remotes (GitHub default, GitLab backup)

```bash
./bin/setup-remotes
```

This ensures:

- **`github`** is the fetch default and upstream for `master`
- **`gitlab`** exists as backup
- **`git push github`** (or plain **`git push`** once upstream is github) can push to **both** GitHub and GitLab via extra push URLs

Manual equivalent:

```bash
git remote add github git@github.com:Ruby-on-Rails-Wizardry/arch-mise.git
git remote add gitlab git@gitlab.com:ruby-on-rails-wizardry/arch-mise.git
git fetch github
git branch -u github/master master
# push to GitHub primary and GitLab backup in one push:
git remote set-url --push github git@github.com:Ruby-on-Rails-Wizardry/arch-mise.git
git remote set-url --add --push github git@gitlab.com:ruby-on-rails-wizardry/arch-mise.git
```

Publish changes:

```bash
git push github master    # hits GitHub + GitLab push URLs when configured
# or explicitly:
git push gitlab master
```

### Sibling images

Same layout and host UX:

- [ubuntu-mise](https://github.com/Ruby-on-Rails-Wizardry/ubuntu-mise)
- [alpine-mise](https://github.com/Ruby-on-Rails-Wizardry/alpine-mise)

## Maintainer notes

Periodic upkeep (remotes, rebuild/verify, keep the three OS flavors in sync, dual-push GitHub + GitLab) is documented for maintainers and agents in:

- **`AGENTS.md`** (this repo) — short maintainer checklist  
- **[docker-mise MAINTAINING.md](https://github.com/Ruby-on-Rails-Wizardry/docker-mise/blob/master/MAINTAINING.md)** — full umbrella + flavor cadence  

Quick maintainer loop:

```bash
./bin/setup-remotes
task build && task verify
# after shared bin/doc changes: sync from ubuntu-mise, then push all
git push github master
git push gitlab master
```

## Releases

Versioned shipping: **[docs/RELEASE.md](docs/RELEASE.md)**. History: **[CHANGELOG.md](CHANGELOG.md)**.  
Coordinated multi-flavor releases: [docker-mise docs/RELEASE.md](https://github.com/Ruby-on-Rails-Wizardry/docker-mise/blob/master/docs/RELEASE.md).

Shortcuts: **send it** / **ship it** / **cut a release** mean run that process end-to-end (including `gh release create`).

## Related

- Sibling base images (Ubuntu / Alpine) — same Task + `bin/*` API  
- [docker-mise](https://github.com/Ruby-on-Rails-Wizardry/docker-mise) — umbrella with submodules  
- `AGENTS.md` — conventions for humans and AI agents  
