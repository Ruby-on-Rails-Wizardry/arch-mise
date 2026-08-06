# Private base image (corporate / VPN FROM)

Use a different **Dockerfile `FROM`** without editing the Dockerfile — typically a
private registry image that already has the HTTP proxy and VPN CA certificates.

## Mechanism

| Piece | Role |
|-------|------|
| `ARG BASE_IMAGE=ubuntu:24.04` | Dockerfile default `FROM` (public github) |
| **`base-image.env`** | **Tracked on GHE:** `BASE_IMAGE=registry/…` so every internal clone gets it |
| `base-image.env.example` | Template on public github (no corporate registry required) |
| `bin/build` | Passes `--build-arg BASE_IMAGE=…` when set |
| `bin/private-sync` | Merge public github → keep/commit `base-image.env` → **push GHE only** → build |

Public github clones (no `base-image.env`) keep building `FROM ubuntu:24.04`.  
**GHE clones** already include `base-image.env` after the one-time private setup.

## One-time setup (GHE mirror)

Run once behind the firewall so **all** internal users inherit `BASE_IMAGE`:

```bash
# From a checkout that can reach public github + private GHE
git clone git@github.com:Ruby-on-Rails-Wizardry/ubuntu-mise.git
cd ubuntu-mise
./bin/setup-remotes   # optional: github / gitlab / ami

git remote add ghe git@ghe.example.com:YourOrg/ubuntu-mise.git

cp base-image.env.example base-image.env
# edit — permanent org default, e.g.:
# BASE_IMAGE=registry.corp.example/ubuntu-24.04-vpn:latest

bin/private-sync
# commits base-image.env, pushes to ghe only, builds
```

After that, anyone inside:

```bash
git clone git@ghe.example.com:YourOrg/ubuntu-mise.git
cd ubuntu-mise
bin/build          # BASE_IMAGE already set from tracked base-image.env
# or: task build / task shell / …
```

No per-developer `base-image.env` copy step.

## Day-to-day (maintainers)

Keep GHE up to date with public releases while **preserving** `base-image.env`:

```bash
bin/private-sync
# git fetch github && merge
# leave base-image.env as-is (already tracked)
# git push ghe HEAD:master
# bin/build
```

Flags:

| Flag | Effect |
|------|--------|
| `--no-build` | Push GHE only (no local image build) |
| `--no-push` | Merge + ensure env + build; no push |
| `--no-fetch` | Skip merge from github |
| `--no-commit` | Do not amend/commit `base-image.env` |

```bash
PRIVATE_REMOTE=enterprise bin/private-sync
PUBLIC_REMOTE=github BRANCH=master bin/private-sync --no-build
```

## Build only

```bash
# GHE clone: base-image.env already present
bin/build

# one-shot override (does not change the committed file)
BASE_IMAGE=registry.corp/ubuntu-vpn:other bin/build

bin/compose build   # honors BASE_IMAGE via bin/compose → .env
```

## Safety / public github

- **`base-image.env` is not gitignored** so it can be a normal committed file on GHE.
- **`bin/private-sync` pushes only to `PRIVATE_REMOTE`** (default `ghe`), never to
  `github`. That is what keeps the corporate registry line off public github.
- Do **not** `git push github` from a branch that has committed `base-image.env`
  unless you intentionally want that image name public.
- Do not put secrets (tokens) in `base-image.env` — only the image reference.
- Your corporate base should still be a normal Ubuntu (or Alpine/Arch) userland
  so the rest of the Dockerfile (apt/apk/pacman packages) applies cleanly.

## Alpine / Arch

Same knobs; Dockerfile defaults differ:

| Flavor | Default `BASE_IMAGE` (no env file) |
|--------|-------------------------------------|
| ubuntu-mise | `ubuntu:24.04` |
| alpine-mise | `alpine:3.22` |
| arch-mise | `archlinux:latest` |
