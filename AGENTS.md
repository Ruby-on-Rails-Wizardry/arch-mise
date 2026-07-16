# Agent guide — arch-mise

## Purpose

**arch-mise** is a reusable **base development image**: Ubuntu 24.04 + non-root user + mise + multi-shell activation + shared `/cache` for package managers.

It is **not** the multi-app Rails cluster (`../wf/`). No project `wf` mount is baked in.

## Locked decisions

| Topic | Choice |
|-------|--------|
| Base OS | Arch Linux |
| User | `dev` (override `USER` / `IMAGE_USER`), UID/GID via build args |
| Tool manager | mise (`MISE_DATA_DIR=/cache/mise`) |
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
├── compose.yml           # Compose path (single dev service)
├── compose.env.example
├── Taskfile.yml          # task recipes → bin/* (+ compose:*)
├── bin/                  # host CLI (no Task required)
├── docker/               # image build scripts
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

- Publish: `git push` / `git push github master` (dual-push when setup-remotes configured); `git push gitlab master` for explicit backup-only.

## Sibling flavors

Keep **arch-mise**, **alpine-mise**, and **arch-mise** APIs identical (`bin/*` names, Task task names). Change only `FLAVOR` / base image / package manager in Dockerfiles. After editing shared host UX, sync `bin/`, `Taskfile.yml` patterns, and docs to all three.

## Maintainer notes (periodic)

**Canonical checklist** (umbrella): [docker-mise MAINTAINING.md](https://github.com/Ruby-on-Rails-Wizardry/docker-mise/blob/master/MAINTAINING.md) when this repo is used as a submodule of **docker-mise**.

### When maintaining this flavor

1. Run `./bin/setup-remotes` if remotes show only `origin` (common after submodule init).
2. Prefer changing **arch-mise** first, then sync scripts/docs to alpine/arch.
3. `task build && task verify && task doctor` before pushing.
4. Dual-push: `git push github master` (and ensure GitLab backup is current).
5. If under docker-mise umbrella, bump the submodule SHA in the parent and push the umbrella to github + gitlab.
6. Keep **README.md** and **AGENTS.md** aligned: quick start, parallel Compose path, GitHub-default submodule URL, no secrets.

### Agents

- Read this file + umbrella `MAINTAINING.md` before bulk doc/remote work.
- Do not invent a third host UX; extend `bin/*` + Taskfile only.
- Summarize verify results and which remotes were updated.
