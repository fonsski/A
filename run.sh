#!/usr/bin/env bash
# Запуск приложения с ключами Supabase: ./run.sh <устройство> [аргументы flutter run]
# Пример: ./run.sh macos
set -euo pipefail
cd "$(dirname "$0")"
if [ ! -f dart_defines.json ]; then
  echo "Нет dart_defines.json — скопируйте dart_defines.example.json и впишите ключи." >&2
  exit 1
fi
device="${1:-macos}"
[ $# -gt 0 ] && shift
exec flutter run -d "$device" --dart-define-from-file=dart_defines.json "$@"
