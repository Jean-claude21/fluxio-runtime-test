#!/bin/sh
# Entrypoint du runtime de developpement persistant Fluxio.
#
# Le conteneur reste vivant et se met a jour par `git pull` : le serveur Vite
# garde son process et applique le HMR. Un redeploiement Coolify reconstruirait
# l'image (~2 min) — ici la boucle de sync ramene le delai a quelques secondes.
set -e

FLUXIO_BRANCH="${FLUXIO_BRANCH:-dev}"
FLUXIO_SYNC_INTERVAL="${FLUXIO_SYNC_INTERVAL:-5}"

# Authentification par deploy key SSH : lecture seule, limitee a ce depot,
# revocable sans toucher aux autres projets.
if [ -n "$FLUXIO_REPO" ] && [ -n "$FLUXIO_DEPLOY_KEY" ]; then
  mkdir -p /root/.ssh
  printf '%s\n' "$FLUXIO_DEPLOY_KEY" | tr -d '\r' > /root/.ssh/id_ed25519
  chmod 600 /root/.ssh/id_ed25519
  ssh-keyscan -t ed25519 github.com >> /root/.ssh/known_hosts 2>/dev/null
  export GIT_SSH_COMMAND="ssh -i /root/.ssh/id_ed25519 -o StrictHostKeyChecking=no"
  FLUXIO_ORIGIN="git@github.com:${FLUXIO_REPO}.git"

  if [ ! -d /app/.git ]; then
    echo "[fluxio] initialisation du depot sur ${FLUXIO_BRANCH}"
    git init -q /app
    git -C /app remote add origin "$FLUXIO_ORIGIN"
    git -C /app fetch -q --depth 1 origin "$FLUXIO_BRANCH"
    git -C /app checkout -q -B "$FLUXIO_BRANCH" FETCH_HEAD
  fi

  # Boucle de synchronisation en arriere-plan.
  # Les dependances ne sont reinstallees que si le lockfile a change : c'est ce
  # qui garde le cycle court sur un changement de code ordinaire.
  (
    while true; do
      sleep "$FLUXIO_SYNC_INTERVAL"
      FLUXIO_BEFORE=$(git -C /app rev-parse HEAD 2>/dev/null || echo none)
      git -C /app fetch -q --depth 1 origin "$FLUXIO_BRANCH" 2>/dev/null || continue
      git -C /app reset -q --hard FETCH_HEAD 2>/dev/null || continue
      FLUXIO_AFTER=$(git -C /app rev-parse HEAD 2>/dev/null || echo none)

      if [ "$FLUXIO_BEFORE" != "$FLUXIO_AFTER" ]; then
        echo "[fluxio] sync ${FLUXIO_BEFORE%${FLUXIO_BEFORE#???????}} -> ${FLUXIO_AFTER%${FLUXIO_AFTER#???????}}"
        if ! git -C /app diff --quiet "$FLUXIO_BEFORE" "$FLUXIO_AFTER" -- pnpm-lock.yaml 2>/dev/null; then
          echo "[fluxio] lockfile modifie — reinstallation"
          (cd /app && pnpm install --prefer-offline) || echo "[fluxio] echec install"
        fi
      fi
    done
  ) &
else
  echo "[fluxio] sync desactive (FLUXIO_REPO ou FLUXIO_DEPLOY_KEY absent) — code fige a l'image"
fi

exec pnpm dev --host 0.0.0.0 --port 3000
