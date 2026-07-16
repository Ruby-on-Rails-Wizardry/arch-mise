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

## Sibling flavors

Keep **arch-mise**, **alpine-mise**, and **arch-mise** APIs identical (`bin/*` names, Task task names). Change only `FLAVOR` / base image / package manager in Dockerfiles. After editing shared host UX, sync `bin/`, `Taskfile.yml` patterns, and docs to all three.
