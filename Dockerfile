# Minimal Arch Linux image: non-root user + mise + shared /cache.
# Layout: home at /home/$USER; shared caches at /cache
#   (Bundler, Yarn 1 + Berry, npm, pip/uv/poetry, mise).
# Login shells (bash, ksh, sh, zsh, fish) activate mise via shell rc files.

FROM archlinux:latest

# Container login name (default "dev"). Pair with DEV_UID / DEV_GID for bind mounts.
ARG USER=dev
ARG DEV_UID=1000
ARG DEV_GID=1000
ARG MISE_VERSION=v2026.7.7
ARG CACHE_ROOT=/cache

# Image/user layout + shared package/tool caches under CACHE_ROOT.
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    USER=${USER} \
    CACHE_ROOT=${CACHE_ROOT} \
    MISE_DATA_DIR=${CACHE_ROOT}/mise \
    MISE_CONFIG_DIR=/home/${USER}/.config/mise \
    MISE_CACHE_DIR=${CACHE_ROOT}/mise-cache \
    BUNDLE_PATH=${CACHE_ROOT}/bundle \
    BUNDLE_CACHE_PATH=${CACHE_ROOT}/rubygems \
    YARN_CACHE_FOLDER=${CACHE_ROOT}/yarn-cache \
    YARN_OFFLINE_MIRROR=${CACHE_ROOT}/yarn \
    YARN_GLOBAL_FOLDER=${CACHE_ROOT}/yarn-global \
    YARN_ENABLE_GLOBAL_CACHE=true \
    NPM_CONFIG_CACHE=${CACHE_ROOT}/npm \
    npm_config_cache=${CACHE_ROOT}/npm \
    PIP_CACHE_DIR=${CACHE_ROOT}/pip \
    UV_CACHE_DIR=${CACHE_ROOT}/uv \
    POETRY_CACHE_DIR=${CACHE_ROOT}/poetry \
    POETRY_VIRTUALENVS_IN_PROJECT=true \
    PATH=/home/${USER}/.local/bin:${CACHE_ROOT}/mise/shims:${PATH} \
    HOME=/home/${USER}

# Minimal base + common shells (bash default; /bin/sh is bash on Arch).
# wheel + sudo drop-in for passwordless admin (Arch convention).
RUN pacman -Syu --noconfirm \
    && pacman -S --noconfirm --needed \
        bash \
        ca-certificates \
        curl \
        fish \
        git \
        less \
        ksh \
        sudo \
        tzdata \
        unzip \
        wget \
        vim \
        zsh \
    && pacman -Scc --noconfirm

# Non-root user (name / UID / GID overridable). See docker/setup-user.sh.
COPY docker/setup-user.sh /tmp/setup-user.sh
RUN chmod +x /tmp/setup-user.sh \
    && USER="${USER}" DEV_UID="${DEV_UID}" DEV_GID="${DEV_GID}" /tmp/setup-user.sh \
    && rm /tmp/setup-user.sh

# Shared /cache tree + profile.d + helpers. See docker/setup-cache.sh.
COPY docker/setup-cache.sh \
     docker/cache-layout.env \
     docker/bundler-flags.yml \
     docker/cache-env \
     docker/verify-caches.sh \
     docker/docker-entrypoint.sh \
     /tmp/
RUN chmod +x /tmp/setup-cache.sh \
    && USER="${USER}" CACHE_ROOT="${CACHE_ROOT}" FLAVOR=arch-mise /tmp/setup-cache.sh \
    && rm -f /tmp/setup-cache.sh /tmp/cache-layout.env /tmp/bundler-flags.yml \
            /tmp/cache-env /tmp/verify-caches.sh /tmp/docker-entrypoint.sh

USER ${USER}
WORKDIR /home/${USER}

# Install mise (https://mise.jdx.dev) for the image user.
# Tools install into MISE_DATA_DIR (/cache/mise); binary stays in ~/.local/bin.
RUN curl -fsSL https://mise.run | MISE_VERSION="${MISE_VERSION}" sh \
    && ~/.local/bin/mise --version \
    && ~/.local/bin/mise reshim

# Activate mise for bash / ksh / sh / zsh / fish. See docker/setup-mise-shell.sh.
COPY --chown=${USER}:${USER} docker/setup-mise-shell.sh /tmp/setup-mise-shell.sh
RUN chmod +x /tmp/setup-mise-shell.sh \
    && /tmp/setup-mise-shell.sh \
    && rm /tmp/setup-mise-shell.sh

# Self-checks:
#   docker run --rm --entrypoint /usr/local/lib/arch-mise/verify-login-shells.sh IMAGE
#   docker run --rm --entrypoint /usr/local/lib/arch-mise/verify-caches.sh IMAGE
COPY --chmod=755 docker/verify-login-shells.sh /usr/local/lib/arch-mise/verify-login-shells.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint"]
# Default to an interactive login shell so profile-based mise setup always runs.
CMD ["bash", "-l"]
