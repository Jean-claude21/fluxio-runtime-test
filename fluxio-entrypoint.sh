#!/bin/sh
# Entrypoint for the Fluxio persistent development runtime.
#
# The container stays alive and updates itself with `git pull`: the Vite dev server keeps
# its process and applies HMR. A Coolify redeploy would rebuild the image (~2 min); this
# sync loop brings that down to a few seconds.
# No `set -e` on purpose: a sync failure must never kill the dev server.

FLUXIO_BRANCH="${FLUXIO_BRANCH:-dev}"
FLUXIO_SYNC_INTERVAL="${FLUXIO_SYNC_INTERVAL:-5}"

# Authentication uses an SSH deploy key: read-only and scoped to this repository.
# The key arrives base64-encoded because Coolify injects environment variables as
# Docker ARG values, and a multi-line value would break the Dockerfile syntax.
if [ -n "$FLUXIO_REPO" ] && [ -n "$FLUXIO_DEPLOY_KEY_B64" ]; then
  mkdir -p /root/.ssh
  printf '%s' "$FLUXIO_DEPLOY_KEY_B64" | base64 -d > /root/.ssh/id_ed25519
  chmod 600 /root/.ssh/id_ed25519
  ssh-keyscan -t ed25519 github.com >> /root/.ssh/known_hosts 2>/dev/null
  export GIT_SSH_COMMAND="ssh -i /root/.ssh/id_ed25519 -o StrictHostKeyChecking=no"
  FLUXIO_ORIGIN="git@github.com:${FLUXIO_REPO}.git"

  if [ ! -d /app/.git ]; then
    echo "[fluxio] initialising repository on ${FLUXIO_BRANCH}"
    git init -q /app
    git -C /app remote add origin "$FLUXIO_ORIGIN"
    git -C /app fetch -q --depth 1 origin "$FLUXIO_BRANCH"
    git -C /app checkout -q -B "$FLUXIO_BRANCH" FETCH_HEAD
  fi

  # Background sync loop. Dependencies are only reinstalled when the lockfile
  # changes, which is what keeps an ordinary code change fast.
  (
    while true; do
      sleep "$FLUXIO_SYNC_INTERVAL"
      FLUXIO_BEFORE=$(git -C /app rev-parse HEAD 2>/dev/null || echo none)
      git -C /app fetch -q --depth 1 origin "$FLUXIO_BRANCH" 2>/dev/null || continue
      git -C /app reset -q --hard FETCH_HEAD 2>/dev/null || continue
      FLUXIO_AFTER=$(git -C /app rev-parse HEAD 2>/dev/null || echo none)

      if [ "$FLUXIO_BEFORE" != "$FLUXIO_AFTER" ]; then
        echo "[fluxio] synced to $(echo "$FLUXIO_AFTER" | cut -c1-7)"
        if ! git -C /app diff --quiet "$FLUXIO_BEFORE" "$FLUXIO_AFTER" -- pnpm-lock.yaml 2>/dev/null; then
          echo "[fluxio] lockfile changed, reinstalling"
          (cd /app && pnpm install --prefer-offline) || echo "[fluxio] install failed"
        fi
      fi
    done
  ) &
else
  echo "[fluxio] sync disabled (FLUXIO_REPO or FLUXIO_DEPLOY_KEY_B64 missing) - code frozen at image build"
fi

exec pnpm dev --host 0.0.0.0 --port 3000
