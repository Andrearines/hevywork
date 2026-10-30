#!/usr/bin/env bash
# Ejecuta la app con la URL y la clave publicable del .env, sin la secreta.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ ! -f .env ]]; then
  echo "Falta .env: copia .env.example y rellena SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
. ./.env
set +a

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_PUBLISHABLE_KEY:-}" ]]; then
  echo "SUPABASE_URL o SUPABASE_PUBLISHABLE_KEY vacías en .env." >&2
  exit 1
fi

exec flutter run \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="$SUPABASE_PUBLISHABLE_KEY" \
  "$@"
