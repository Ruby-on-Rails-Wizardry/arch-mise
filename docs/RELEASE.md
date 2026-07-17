# Release process

How to cut a version of **arch-mise**. Default branch is **`master`**. Default remote is **`github`** (not `origin`); **`gitlab`** is the backup mirror.

A release is **not done** until the GitHub Release exists for the tag.

For **shared host UX** changes, prefer the **coordinated** path in the umbrella:
[docker-mise docs/RELEASE.md](https://github.com/Ruby-on-Rails-Wizardry/docker-mise/blob/master/docs/RELEASE.md)
(ubuntu first → sync alpine/arch → same `vX.Y.Z` on all three → pin umbrella).

## Agent / human trigger phrases

When the user says any of the following, run this process **end-to-end** (do not stop after commit or push alone):

| Phrase | Action |
|--------|--------|
| **send it** | Full release checklist below (coordinated if shared UX) |
| **ship it** | Same |
| **cut a release** | Same |

```text
verify → changelog → commit → tag → dual-push master + tag → gh release create → pin umbrella
```

## Preconditions

- [ ] Working tree clean (`git status`)
- [ ] On `master`, up to date with `github/master` (or intentionally ahead)
- [ ] Remotes configured: `./bin/setup-remotes` (`github` + `gitlab`)
- [ ] `task build && task verify` passes (and `task doctor` when practical)
- [ ] Shared changes already synced from ubuntu **or** this change is truly Arch-only
- [ ] [CHANGELOG.md](../CHANGELOG.md) `[Unreleased]` reflects what is shipping
- [ ] [`gh`](https://cli.github.com/) is installed and authenticated (`gh auth status`)
  - Needs `repo` scope and write access to `Ruby-on-Rails-Wizardry/arch-mise`

## Semver (host UX / image contract)

| Bump | Examples |
|------|----------|
| **MAJOR** | Rename/remove `bin/*` or Task names; break `/cache` layout or env contract; break compose service shape |
| **MINOR** | New tasks/bin commands; additive cache dirs; new shells; new knobs with defaults preserved |
| **PATCH** | Bugfixes; `MISE_VERSION` bumps; package refresh; docs of existing behavior; verify/doctor improvements |

Version source of truth: annotated git tag **`vX.Y.Z`** + CHANGELOG section. No package version file required.

**Coordinated releases:** use the **same** `X.Y.Z` on ubuntu-mise, alpine-mise, and arch-mise whenever shared host UX or shared `docker/` / `bin/` scripts change. OS-specific Dockerfile-only fixes may ship as a patch on this flavor only; note skew in the umbrella pin commit.

## Checklist

### 1. Stabilize

```bash
./bin/setup-remotes   # if remotes show only origin
task build
task verify
task doctor           # optional but preferred
```

Fix failures before proceeding.

### 2. Changelog

In [CHANGELOG.md](../CHANGELOG.md):

1. Move bullets from **`[Unreleased]`** into a new section:

   ```markdown
   ## [X.Y.Z] - YYYY-MM-DD
   ```

2. Leave empty **`[Unreleased]`** stubs (`Added` / `Changed` / `Fixed` / `Security`).

3. Update compare links at the bottom:

   ```markdown
   [Unreleased]: https://github.com/Ruby-on-Rails-Wizardry/arch-mise/compare/vX.Y.Z...HEAD
   [X.Y.Z]: https://github.com/Ruby-on-Rails-Wizardry/arch-mise/compare/vPREV...vX.Y.Z
   ```

   For the first release, link the version to the tag only:

   ```markdown
   [X.Y.Z]: https://github.com/Ruby-on-Rails-Wizardry/arch-mise/releases/tag/vX.Y.Z
   ```

### 3. Docs sanity

- [ ] README quick start and tables match host UX
- [ ] AGENTS.md contracts still accurate
- [ ] Sibling flavors updated if this was a shared change
- [ ] This file still matches how you actually release

### 4. Commit

```bash
git add -A
git status   # review; no .env, no secrets
git commit -m "Release X.Y.Z

<summary of user-visible changes>"
```

### 5. Tag

Annotated tag required:

```bash
git tag -a vX.Y.Z -m "vX.Y.Z — short summary"
```

### 6. Push branch and tag (dual remote)

```bash
git push github master
git push github vX.Y.Z
git push gitlab master
git push gitlab vX.Y.Z
```

### 7. Create the GitHub Release (**required**)

Publish notes from the changelog section for this version:

```bash
awk '/^## \[X.Y.Z\]/{flag=1; next} /^## \[/{flag=0} flag' CHANGELOG.md > /tmp/release-notes.md

gh release create vX.Y.Z \
  --repo Ruby-on-Rails-Wizardry/arch-mise \
  --title "vX.Y.Z" \
  --notes-file /tmp/release-notes.md \
  --verify-tag
```

Confirm:

```bash
gh release view vX.Y.Z --repo Ruby-on-Rails-Wizardry/arch-mise
```

To replace notes on an existing release:

```bash
gh release edit vX.Y.Z --notes-file /tmp/release-notes.md
```

### 8. Umbrella pin

If this flavor is consumed via **docker-mise**, bump the submodule pin in the parent (and the other flavors if coordinated). See umbrella [docs/RELEASE.md](https://github.com/Ruby-on-Rails-Wizardry/docker-mise/blob/master/docs/RELEASE.md).

### 9. Post-release

- [ ] `gh release list` shows `vX.Y.Z`
- [ ] New work goes under `[Unreleased]` again

## What not to ship in a release commit

- Real secrets, `.env`, `compose.override.yml`
- Unrelated large refactors without changelog bullets
- Broken `task verify`
- Shared-API drift vs ubuntu/alpine (unless intentionally OS-only and documented)

## Maintain vs release

| Intent | Doc |
|--------|-----|
| Versioned shipping | **this file** |
| Remotes, mirrors, rebuild hygiene, doc sync without a version | [MAINTAINING.md](https://github.com/Ruby-on-Rails-Wizardry/docker-mise/blob/master/MAINTAINING.md) |

## Quick one-liner reminder

```text
verify → changelog → commit → tag → dual-push master + tag → gh release create → pin umbrella
```

(Also the definition of **send it** / **ship it** / **cut a release**.)
