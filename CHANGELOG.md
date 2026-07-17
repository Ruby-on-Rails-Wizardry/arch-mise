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

[Unreleased]: https://github.com/Ruby-on-Rails-Wizardry/arch-mise/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/Ruby-on-Rails-Wizardry/arch-mise/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Ruby-on-Rails-Wizardry/arch-mise/releases/tag/v0.1.0
