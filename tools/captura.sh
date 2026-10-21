#!/usr/bin/env bash
# Saca una captura de la demo compilada para Linux (necesita xvfb e ImageMagick).
#   tools/captura.sh salida.png "noche jefes tactil" [ancho alto]
# Las opciones arman la escena: noche, jefes, tactil, tienda, finao. Vacío es de día.
set -euo pipefail
salida=$(realpath -m "$1")
opciones=${2:-dia}
ancho=${3:-1920}
alto=${4:-1200}
juego=$(find "$(dirname "$0")/../build/linux" -name "*.x86_64" | head -1)
log=$(mktemp)
xvfb-run -a -s "-screen 0 ${ancho}x${alto}x24" bash -c '
  "$0" --config=prueba.captura="$1" --config=prueba.ventana="$3x$4" >"$2" 2>&1 &
  pid=$!
  for i in $(seq 1 300); do grep -q "CAPTURA LISTA" "$2" && break; sleep 0.1; done
  sleep 0.3
  import -window root "$5"
  kill $pid
' "$juego" "$opciones" "$log" "$ancho" "$alto" "$salida"
grep -E "ERROR|error" "$log" | grep -iv "sound\|openal\|alsa" || true
rm -f "$log"
echo "Captura: $salida"
