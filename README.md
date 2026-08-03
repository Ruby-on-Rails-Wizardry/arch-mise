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

### Rails sample app (`../arch-sample`)

A more realistic exercise of the base image: the [sample_app](https://github.com/Ruby-on-Rails-Wizardry/sample_app) Rails app lives as an **umbrella sibling** at `../arch-sample/` (docker-mise submodule). Mount it like any other project — there is **no** compose `app` service in this flavor:

```bash
# from docker-mise umbrella if sample missing:
git submodule update --init arch-sample
PROJECT=../arch-sample task setup
PROJECT=../arch-sample task shell
# or compose path:
PROJECT=../arch-sample task compose:shell
# or: PROJECT=../arch-sample ./bin/compose run --rm arch-mise bash -l
```

Plain `compose up` starts the interactive **`arch-mise`** service only (local image tag, `pull_policy: never`).

Use the image against **another project**:

```bash
PROJECT=/path/to/my-app task setup
PROJECT=/path/to/my-app task shell
# or
PROJECT=/path/to/my-app ./bin/shell
```

## Default tools (`mise.toml`)

When this directory is the project (`task setup` / `task shell` here), [mise.toml](mise.toml) pins common-dev tools (Node, Yarn, Python, Task, …). **Ruby’s source of truth is the [Gemfile](Gemfile)** (`ruby "…"`), with mise idiomatic version files enabled. Do **not** use `.tool-versions`, `.ruby-version`, `.node-version`, or `.python-version`.

| Tool | Version | Notes |
|------|---------|--------|
| Ruby | 4.0.6 | From **Gemfile** (`ruby "…"`; idiomatic — not under `[tools]`) |
| Node.js | 24.18.0 | Active LTS |
| Yarn | 1.22.22 | Classic; Berry via `mise use yarn@4` |
| Python | 3.13.14 | Current 3.13 line |
| Task | 3.52.0 | go-task; host UX (`Taskfile.yml`) |

`task warm` runs `mise install` into `/cache/mise`. **App repos should use `Gemfile` + `mise.toml`** when you set `PROJECT=…`. Omit `ruby` under `[tools]` when the Gemfile pin is parseable (e.g. `4.0.6`).

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
./bin/compose run --rm arch-mise bash -l
PROJECT=/path/to/app ./bin/compose run --rm arch-mise bash -l
```

`bin/compose` regenerates `.env` each run (host UID/GID + absolute `PROJECT_MOUNT`). Compose uses the local image tag only (`pull_policy: never`). See `compose.env.example`. Do not commit `.env`.

## Daily commands

### docker run path

| Task | bin | Purpose |
|------|-----|---------|
| `task setup` | `bin/setup` | Build, ensure cache volume, warm |
| `task build` | `bin/build` | Build/refresh image |
| `task shell` | `bin/shell` | Interactive login shell (defaults to host `$SHELL` when available in the image; override: `bin/shell zsh`) |
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
| `task compose:shell` | `bin/compose-shell` | `compose run --rm arch-mise bash -l` |
| `task compose:run -- cmd` | `bin/compose run --rm arch-mise …` | One-shot via compose |
| `task compose:up` | `bin/compose up` | Attach to `arch-mise` service |
| `task compose:down` | `bin/compose down` | Stop (volumes kept) |
| `task compose:config` | `bin/compose config` | Resolved compose file |
| `task compose -- …` | `bin/compose …` | Pass-through |

## Layout inside the container

| Path | Role |
|------|------|
| `/work` | Your project (`PROJECT` or `$PWD` on the host) |
| `/cache` | Shared package + mise tool cache (named Docker volume) |
| `/home/dev` | Image user home (default user name `dev`); seeded from repo `home/` |

Repo **`home/`** is copied into `/home/$USER` at image build (`COPY --chown=$DEV_UID:$DEV_GID`). Put defaults there instead of baking logic into Dockerfile `RUN` steps:

| Path under `home/` | Role |
|--------------------|------|
| `bin/` | **Runtime** tools → `/docker/bin` (on `PATH`): `cache-env`, `docker-entrypoint`, `verify-*`, plus any scripts you add |
| `.profile`, `.bashrc`, `.bash_profile`, `.kshrc`, `.zprofile`, `.zshrc`, `.config/fish/config.fish` | PATH + mise activate |
| `.gemrc`, `.bundle/config`, `.npmrc`, `.yarnrc` / `.yarnrc.yml`, `.config/pip/pip.conf`, IRB/Pry/Rails rc | Language tool globals |

**`docker/`** is build-time only (`setup-user`, `setup-cache`, `setup-postgresql`, `setup-mise-shell`, layout YAML). Do not put runtime CLIs there.

Rebuild after edits so the image picks them up.

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

## Supported hosts

Host UX (`bin/*`, Task) is meant to run from a **Unix shell** in one of:

| Host | Notes |
|------|--------|
| **1. Native Linux** | First-class (`id`, `timedatectl` / `/etc/localtime`, Docker Engine or Desktop) |
| **2. Native macOS** | Docker Desktop (or compatible). `TZ` from `/etc/localtime` (or set `TZ=…`) |
| **3. Windows + WSL** | Use the project **inside the WSL Linux distro** (e.g. `~/…`). Docker Desktop **WSL integration** for that distro |

**Not in scope:** running these scripts from native Windows (PowerShell/cmd) or only on `/mnt/c/...` outside a WSL workflow.

`bin/config` / `bin/doctor` print `HOST_KIND=linux|macos|wsl`. Prefer keeping WSL clones under the Linux home filesystem (not `/mnt/c`) for performance and ownership.

## UID / GID

By default `bin/build` passes your host `id -u` / `id -g` so bind mounts under `/work` are writable.

```bash
DEV_UID=1000 DEV_GID=1000 task build   # force classic 1000:1000
```

Rebuild if you change UID, or file ownership on mounts will not match.

## Build defaults (mise + shell)

**mise** loads:

| Source | Role |
|--------|------|
| **[`.mise.env`](.mise.env)** (committed) | Project defaults (`POSTGRESQL_VERSION=18`) |
| **`bin/mise-host-env.sh`** via `env._.source` | Host identity: `USER`, `SHELL`, `DEV_UID`, `DEV_GID`, `IMAGE_USER`, `TZ` (fill gaps only) |
| **`.mise.env.local`** (gitignored) | Optional machine overrides |

**`bin/lib.sh`** applies the same rules so `bin/build` / `bin/compose` work even without `mise activate`. Shell exports always win.

### Host identity (usually already in the shell)

| Variable | Typical host source | Docker / host UX use |
|----------|---------------------|----------------------|
| `USER` | Login name (Linux/macOS/WSL) | Basis for `IMAGE_USER`; compose/runtime |
| `SHELL` | Login shell path | `bin/shell` default inside the container |
| `DEV_UID` / `DEV_GID` | `id -u` / `id -g` if unset | Build-args; `COPY --chown`; bind mounts |
| `IMAGE_USER` | Defaults to `$USER` | Build-arg `USER` (container login name) |
| `TZ` | Detected if unset (`/etc/timezone`, `timedatectl`, `/etc/localtime`) | Container `TZ` |

Do **not** set bash’s special `UID` (read-only); we use **`DEV_UID`**.

### Project / compose knobs

| Variable | Default | Used by |
|----------|---------|---------|
| `POSTGRESQL_VERSION` | **18** (`.mise.env` / Dockerfile `ARG`) | Build-arg; empty = skip client |
| `IMAGE` | `{flavor}:dev` | Image tag |
| `CACHE_VOLUME` | `{flavor}-cache` | Named volume → `/cache` |
| `CACHE_ROOT` | `/cache` | In-container path |
| `PROJECT` / `PWD` | CWD | Bind mount → `/work` |
| `MISE_VERSION` | Dockerfile pin | mise installer (build only) |
| `DEBIAN_FRONTEND` | `noninteractive` | apt (Ubuntu Dockerfile) |
| `TERM` | `$TERM` or `xterm-256color` | `docker run` |
| `DOCKER_BUILD_OPTS` / `DOCKER_RUN_OPTS` | empty | Extra docker CLI flags |

```bash
task build                       # PG 18, host UID/GID, host USER → IMAGE_USER
mise build                       # same as task build
POSTGRESQL_VERSION=17 task build
POSTGRESQL_VERSION= task build   # skip PostgreSQL client
bin/config                       # print resolved values
mise tasks                       # list mise-mirrored host UX tasks
```

Mise mirrors Taskfile host UX (`build`, `setup`, `shell`, `run`, `compose`, `compose:*`, `cache` / `cache:reset`, …). Interactive ones need a real TTY. Taskfile `default` (list) is not mirrored — use `mise tasks`. Destructive: `mise run cache:reset -- -y` (same guard as `task`).

Arch is rolling (`postgresql-libs`); the ARG is recorded and best-effort checked against the installed major.


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
