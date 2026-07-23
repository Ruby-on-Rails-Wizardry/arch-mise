# Agent guide — arch-mise

## Purpose

**arch-mise** is a reusable **base development image**: Ubuntu 24.04 + non-root user + mise + multi-shell activation + shared `/cache` for package managers.

It is **not** the multi-app Rails cluster (`../wf/`). No project `wf` mount is baked in.

## Locked decisions

| Topic | Choice |
|-------|--------|
| Base OS | Arch Linux |
| User | `dev` (override `USER` / `IMAGE_USER`), UID/GID via build args |
| Tool manager | mise (`MISE_DATA_DIR=/cache/mise`); Ruby prefers precompiled; compile toolchain in image |
| Build toolchain | `base-devel` + OpenSSL/YAML/zlib/ffi/… headers for native gems & language builds |
| Shells | bash, ksh, sh (dash), zsh, fish activate mise on login |
| Project mount | Host `PROJECT` or `$PWD` → **`/work`** |
| Package cache | Named volume → **`/cache`** |
| Host UX | **Task** (`Taskfile.yml`) + **`bin/*`** (logic lives in bin) |

## Host commands (prefer these)

Two **parallel** runtimes — same `/work` + `/cache` contract:

| Intent | docker run | Compose |
|--------|------------|---------|
| First-time setup | `task setup` / `./bin/setup` | `task compose:setup` / `./bin/compose-setup` |
| Shell | `task shell` / `./bin/shell` | `task compose:shell` / `./bin/compose-shell` |
| One-shot | `task run -- cmd` / `./bin/run` | `task compose:run -- cmd` / `./bin/compose run --rm dev …` |
| Build only | `task build` / `./bin/build` | `task compose:build` / `./bin/compose build` |
| Verify image | `task verify` / `./bin/verify` | (same) |

- Always use **`bin/compose`** (or `task compose:*`), not raw `docker compose`, so `.env` gets host UID/GID and absolute `PROJECT_MOUNT`.
- Implement changes in **`bin/*`** first; Taskfile only delegates.
- Do not make `task shell` call Compose — keep paths independent.

## Config SSOT

| Concern | Where |
|---------|--------|
| Image env + cache paths | `Dockerfile` `ENV` |
| Cache dir names | `docker/cache-layout.env` |
| Create `/cache`, profile.d | `docker/setup-cache.sh` |
| User creation | `docker/setup-user.sh` |
| Shell mise activation | `docker/setup-mise-shell.sh` |
| Default language tool versions | `mise.toml` (starter pins; apps override) |
| Sample project (warm/smoke) | `Gemfile*`, `package.json`/`yarn.lock`, `requirements.txt`, `scripts/smoke.sh` |
| Realistic Rails sample | `sample_app/` git submodule → compose service `app` (`bin/compose-app`) |
| Host run helpers | `bin/lib.sh` |

## Verify before claiming done

```bash
task build
task verify          # shells + caches
task doctor
```

## Safety

- Do not commit secrets or populated cache volume contents.
- Do not share `/cache` volumes across Alpine (musl) and glibc images for native gems/wheels.
- Prefer reversible local changes; `cache:reset` is destructive (requires `-y` / `CONFIRM=1`).

## File map

```
arch-mise/
├── Dockerfile
├── compose.yml           # Compose path: dev + profiled app (sample_app)
├── compose.env.example
├── Taskfile.yml          # task recipes → bin/* (+ compose:*)
├── mise.toml             # default ruby/node/yarn/python pins
├── Gemfile               # starter rails + rubocop + brakeman
├── Gemfile.lock
├── package.json          # sample yarn classic dep
├── yarn.lock
├── requirements.txt      # sample pip deps
├── scripts/smoke.sh      # post-setup sample smoke test
├── sample_app/           # submodule: realistic Rails app for compose app service
├── bin/                  # host CLI (no Task required)
├── docker/               # image build scripts
├── CHANGELOG.md          # Keep a Changelog
├── docs/
│   └── RELEASE.md        # versioned release checklist
├── README.md
└── AGENTS.md
```

## Remotes and submodules

| Remote | Role | URL |
|--------|------|-----|
| **github** | **Default** — fetch, upstream, primary push | `git@github.com:Ruby-on-Rails-Wizardry/arch-mise.git` |
| **gitlab** | **Backup** mirror | `git@gitlab.com:ruby-on-rails-wizardry/arch-mise.git` |

- Default branch: **`master`**
- After clone: run **`./bin/setup-remotes`** (idempotent) so `github` is pushDefault and push URLs include GitLab backup.
- **Do not** use `origin` as the primary name; prefer `github` / `gitlab`.
- Consumers should add this repo as a **submodule** via GitHub:

```bash
git submodule add -b master \
  git@github.com:Ruby-on-Rails-Wizardry/arch-mise.git \
  arch-mise
```

- Publish (non-versioned): `git push` / `git push github master` (dual-push when setup-remotes configured); `git push gitlab master` for explicit backup-only.
- **Releases:** follow [docs/RELEASE.md](docs/RELEASE.md) — verify → changelog → commit → tag → dual-push → **`gh release create` (required)** → pin umbrella. Prefer the coordinated path in [docker-mise docs/RELEASE.md](https://github.com/Ruby-on-Rails-Wizardry/docker-mise/blob/master/docs/RELEASE.md) when shared host UX changes.

### Phrase shortcuts

| Phrase | Means |
|--------|--------|
| **send it** / **ship it** / **cut a release** | [docs/RELEASE.md](docs/RELEASE.md) **end-to-end** (coordinated across flavors when shared UX changes). Do **not** stop after push alone. |
| **maintain** / **sync** / **refresh docs** | Umbrella [MAINTAINING.md](https://github.com/Ruby-on-Rails-Wizardry/docker-mise/blob/master/MAINTAINING.md) — no version unless also releasing |

When shipping user-visible changes, update [CHANGELOG.md](CHANGELOG.md) under `[Unreleased]`. Move entries into a version section when cutting a release.

## Sibling flavors

Keep **ubuntu-mise**, **alpine-mise**, and **arch-mise** APIs identical (`bin/*` names, Task task names). Change only `FLAVOR` / base image / package manager in Dockerfiles. After editing shared host UX, sync `bin/`, `Taskfile.yml` patterns, and docs to all three. Prefer changing **ubuntu-mise** first, then sync here.

## Maintainer notes (periodic)

**Canonical checklists** (umbrella):

- Maintain: [docker-mise MAINTAINING.md](https://github.com/Ruby-on-Rails-Wizardry/docker-mise/blob/master/MAINTAINING.md)
- Release: [docker-mise docs/RELEASE.md](https://github.com/Ruby-on-Rails-Wizardry/docker-mise/blob/master/docs/RELEASE.md) and this repo’s [docs/RELEASE.md](docs/RELEASE.md)

### When maintaining this flavor

1. Run `./bin/setup-remotes` if remotes show only `origin` (common after submodule init).
2. Prefer changing **ubuntu-mise** first, then sync scripts/docs to alpine/arch.
3. `task build && task verify && task doctor` before pushing.
4. Dual-push: `git push github master` (and ensure GitLab backup is current).
5. If under docker-mise umbrella, bump the submodule SHA in the parent and push the umbrella to github + gitlab.
6. Keep **README.md** and **AGENTS.md** aligned: quick start, parallel Compose path, GitHub-default submodule URL, no secrets.

### Agents

- Read this file + umbrella `MAINTAINING.md` / `docs/RELEASE.md` before bulk doc/remote/release work.
- Do not invent a third host UX; extend `bin/*` + Taskfile only.
- Summarize verify results and which remotes were updated.
