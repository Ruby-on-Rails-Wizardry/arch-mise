# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Version tags are `vX.Y.Z`. A GitHub Release via `gh release create` is required at cut time (see [docs/RELEASE.md](docs/RELEASE.md)).

## [Unreleased]

### Added

### Changed

### Fixed

### Security

<!-- Next changes go here. Move bullets into a version section when cutting a release. -->

## [0.7.0] - 2026-07-30

### Changed

- Drop compose **`app`** service / `compose:app` / `bin/compose-app`; use `PROJECT=../arch-sample` with `arch-mise` service instead
- Compose service name and hostname match the flavor (`arch-mise`)
- Sample Rails app moved out of this repo: use umbrella sibling **`arch-sample/`** (was nested `sample_app` submodule)
- Compose services use local image tag only (`pull_policy: never`) — never pull the flavor image from a registry; build with `bin/build` / `bin/compose build`

## [0.6.0] - 2026-07-29

### Added

- `.mise.env` + `mise.toml` `env._.file` for project defaults (`POSTGRESQL_VERSION=18`); `bin/lib.sh` loads the same file (set-if-unset)
- `bin/mise-host-env.sh` + `mise.toml` `env._.source` export host `USER`, `SHELL`, `DEV_UID`, `DEV_GID`, `IMAGE_USER`, `TZ` (fill gaps only)
- mise tasks mirroring Taskfile: `build`, `setup`, `config`, `warm`, `doctor`, `verify`, `cache` / `cache:reset`, `run`, pass-through `compose`, `compose:build` / `config` / `setup` / `down` / `run`, plus TTY `shell` / `compose:shell` / `compose:up` / `compose:app`

### Changed

- Default `POSTGRESQL_VERSION` to **18** via `.mise.env` and Dockerfile `ARG`; empty still skips client install
- `IMAGE_USER` falls back to host `$USER` when unset (then `dev`)

## [0.5.1] - 2026-07-29

### Changed

- Compose named cache volume is no longer `external: true` — Docker Compose creates it when missing (still shared with `bin/shell` via `CACHE_VOLUME` name)

## [0.5.0] - 2026-07-29

### Added

- Repo `home/` skeleton (gem/bundler/npm/yarn/pip/IRB/Pry/Rails globals) copied into `/home/$USER` at build with `COPY --chown=$DEV_UID:$DEV_GID`
- `home/bin/` → `~/bin` on `PATH`; shell rc + mise activate live in `home/` (setup-mise-shell only verifies)
- Split layout: **`docker/`** = build-time setup only; **runtime** tools (`cache-env`, `docker-entrypoint`, `verify-*`) live in `home/bin` (not `/usr/local/bin`)
- Optional PostgreSQL client + libpq (`postgresql-libs`) via `docker/setup-postgresql.sh` when `POSTGRESQL_VERSION` is set (ARG/ENV; empty = skip)

### Changed

- `bin/shell` defaults to the host login shell (`$SHELL` / parent) when available in the image (bash/zsh/fish/ksh/sh); explicit `bin/shell zsh` still overrides
- Host matrix documented + hardened: **Linux**, **macOS**, **WSL** (project inside WSL); `host_kind` / improved `TZ` detection (macOS-safe localtime resolve)
- Install `lsb-release` (`lsb_release`) in the base image
- Install full terminal `vim` and `neovim` (`nvim`); no GUI gvim
- Dockerfile: single early `COPY --chmod=755 docker/ /docker/` (keep scripts; no `/tmp` stage-and-rm); `setup-cache` reads from `/docker`
- Host timezone: `bin/shell` / `bin/run` / compose set container `TZ` from host; override with `TZ=…`
- Compose services set `hostname` to match the service name (`dev`, `app`)
- AGENTS: mise install at **runtime** into `/cache` for this dev image; prod default = no mise; if prod uses mise = builder-only

### Fixed

### Security

## [0.4.3] - 2026-07-27

### Changed

- Expand `.gitignore` Vim artifact coverage (`*~`, `*.swp`/`*.swo`/`*.swn`, `Session.vim`, `.netrwhist`) including [sample_app](https://github.com/Ruby-on-Rails-Wizardry/sample_app)
- Bump [sample_app](https://github.com/Ruby-on-Rails-Wizardry/sample_app) submodule to master (`958ccb9`)

## [0.4.2] - 2026-07-27

### Changed

- Bump [sample_app](https://github.com/Ruby-on-Rails-Wizardry/sample_app) submodule to master (`37e717c`) so the app leaves `ruby.compile` to the base image (Alpine musl vs glibc)

## [0.4.0] - 2026-07-24

### Added

- Pin **Task** (go-task) **3.52.0** in default [mise.toml](mise.toml) so `task warm` / `mise install` provides host UX tools in the image
- Enable mise **idiomatic version files** for Ruby so the **Gemfile** `ruby "…"` directive is the preferred Ruby version source (no `.ruby-version`)

### Changed

- Prefer **Gemfile + mise.toml** for tool pins (Ruby from Gemfile via idiomatic files; other tools from mise.toml)
- Standardize on **mise.toml** + **Gemfile**; treat **`.tool-versions`**, **`.ruby-version`**, **`.node-version`**, and **`.python-version`** as redundant (`bin/warm` / compose `app` trigger on mise.toml or Gemfile only)
- Bump starter Ruby to **4.0.6** (Gemfile; no `[tools] ruby` pin)
- Point [sample_app](https://github.com/Ruby-on-Rails-Wizardry/sample_app) submodule at the matching Gemfile + mise.toml / Ruby 4.0.6 pins

### Fixed

### Security

## [0.3.0] - 2026-07-23

### Added

- [sample_app](https://github.com/Ruby-on-Rails-Wizardry/sample_app) git submodule for a realistic Rails exercise of the base image
- Compose service **`app`** (profile `app`): mounts `sample_app` at `/work`, warms mise/bundle, runs `rails server` on port 3000 with `/up` healthcheck
- Host helpers: `bin/compose-app`, `task compose:app`; setup/compose-setup init the submodule and warm sample gems into `/cache`

### Changed

- `bin/warm` runs `mise install` when `.ruby-version` / `.node-version` / `.python-version` are present (not only `mise.toml` / `.tool-versions`)

### Fixed

### Security

## [0.2.0] - 2026-07-17

### Added

- Default [mise.toml](mise.toml) with common-dev tool pins: Ruby 3.4.10, Node 24.18.0 (LTS), Yarn 1.22.22, Python 3.13.14 (`task warm` installs when this dir is the project)
- Starter [Gemfile](Gemfile) / [Gemfile.lock](Gemfile.lock): Rails ~> 8.1.3, RuboCop ~> 1.88, Brakeman ~> 8.0 (`task warm` runs `bundle install`)
- Sample [package.json](package.json) / [yarn.lock](yarn.lock) (`ms`) and [requirements.txt](requirements.txt) (`requests`) for warm
- [scripts/smoke.sh](scripts/smoke.sh) post-setup checks (tools + cache env); README Sample project path
- Image compile toolchain: `base-devel`, OpenSSL/YAML/zlib/ffi and related packages for ruby-build, native gems, and Python/Node extensions
- `MISE_TRUSTED_CONFIG_PATHS=/work` and `XDG_STATE_HOME=/cache/xdg-state` so project mise config stays trusted across containers

### Changed

- Shared Bundler cache: force `BUNDLE_CLEAN=false` / `bundle install --no-clean` so one Gemfile cannot prune gems other projects still use on `/cache/bundle`
- Classic Yarn offline mirror: `yarn-offline-mirror-pruning false` for the same multi-project cache reason
- Ruby installs prefer precompiled binaries (`ruby.compile = false` / `MISE_RUBY_COMPILE=false`) for speed; source compile still possible with the toolchain

### Fixed

- `bin/shell` always requests a Docker TTY and starts `bash -il` / `zsh -il` so the shell is interactive (shows a prompt)
- Shell mise activate no longer fails with untrusted `/work/mise.toml` after warm (trust was ephemeral under home)

## [0.1.0] - 2026-07-17

### Added

- Documented release process in [docs/RELEASE.md](docs/RELEASE.md) (includes mandatory GitHub Release via `gh`)
- Keep a Changelog file for version history
- Phrase shortcuts (**send it** / **ship it** / **cut a release**) in AGENTS.md and README
- Baseline host UX: Task + `bin/*`, parallel Compose path, mise, multi-shell login, `/cache` layout

[Unreleased]: https://github.com/Ruby-on-Rails-Wizardry/arch-mise/compare/v0.7.0...HEAD
[0.7.0]: https://github.com/Ruby-on-Rails-Wizardry/arch-mise/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/Ruby-on-Rails-Wizardry/arch-mise/compare/v0.5.1...v0.6.0
[0.5.1]: https://github.com/Ruby-on-Rails-Wizardry/arch-mise/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/Ruby-on-Rails-Wizardry/arch-mise/compare/v0.4.3...v0.5.0
[0.4.3]: https://github.com/Ruby-on-Rails-Wizardry/arch-mise/compare/v0.4.2...v0.4.3
[0.4.2]: https://github.com/Ruby-on-Rails-Wizardry/arch-mise/releases/tag/v0.4.2
[0.4.0]: https://github.com/Ruby-on-Rails-Wizardry/arch-mise/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/Ruby-on-Rails-Wizardry/arch-mise/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/Ruby-on-Rails-Wizardry/arch-mise/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Ruby-on-Rails-Wizardry/arch-mise/releases/tag/v0.1.0

