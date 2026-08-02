#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v docker >/dev/null 2>&1; then
  echo "Erro: Docker não encontrado." >&2
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "Erro: Docker Compose v2 não encontrado." >&2
  exit 1
fi

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Arquivo .env criado a partir do .env.example."
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

DATA_ROOT="${DATA_ROOT:-./data}"
FRONTEND_NETWORK="${FRONTEND_NETWORK:-frontend}"
MONITORING_NETWORK="${MONITORING_NETWORK:-monitoring}"

for network in "$FRONTEND_NETWORK" "$MONITORING_NETWORK"; do
  if ! docker network inspect "$network" >/dev/null 2>&1; then
    docker network create "$network" >/dev/null
    echo "Rede Docker criada: $network"
  fi
done

for directory in grafana loki mimir tempo pyroscope; do
  mkdir -p "$DATA_ROOT/$directory"
done

# Permissões amplas são adequadas para este laboratório local e evitam conflitos
# entre os UIDs usados pelas diferentes imagens Grafana.
chmod -R a+rwx "$DATA_ROOT"

docker compose config --quiet

echo
printf 'Bootstrap concluído.\nExecute: make up\n'
