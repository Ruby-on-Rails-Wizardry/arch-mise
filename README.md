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

Use the image against **another project**:

```bash
PROJECT=/path/to/my-app task setup
PROJECT=/path/to/my-app task shell
# or
PROJECT=/path/to/my-app ./bin/shell
```

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
| `bundle/`, `rubygems/` | Bundler |
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

## Related

- `alpine-mise/`, `arch-mise/` — same UX, different base OS  
- `../wf/` — multi-app Rails cluster template (not this image)  
- `AGENTS.md` — conventions for humans and AI agents  
