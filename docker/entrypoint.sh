#!/usr/bin/env bash
set -euo pipefail

if [[ $# -eq 0 ]]; then
  exec python /opt/CookHLA/CookHLA.py --help
fi

case "$1" in
  cookhla)
    shift
    exec python /opt/CookHLA/CookHLA.py "$@"
    ;;
  makegeneticmap)
    shift
    exec python -m MakeGeneticMap "$@"
    ;;
  bash|sh|python|plink|Rscript|java|perl)
    exec "$@"
    ;;
  *)
    exec python /opt/CookHLA/CookHLA.py "$@"
    ;;
esac

