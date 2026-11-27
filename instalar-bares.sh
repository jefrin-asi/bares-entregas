#!/usr/bin/env bash
# Instala o ACTUALIZA el Sistema Bares en Ubuntu bajando el paquete de Internet (sin USB ni cuenta de GitHub).
#   curl -fsSL https://raw.githubusercontent.com/jefrin-asi/bares-entregas/main/instalar-bares.sh -o instalar-bares.sh && bash instalar-bares.sh
#   MUESTRA en una PC que ya tiene otro sistema (p. ej. la caja de Cognata's):   bash instalar-bares.sh --muestra
# - Pide la clave del paquete sin mostrarla (no queda en el historial).
# - Verifica la huella SHA-256; si no coincide, no instala nada.
# - Si ya está instalado, actualiza con respaldo previo y regreso automático a la versión anterior si falla.
set -euo pipefail
REPO="jefrin-asi/bares-entregas"; BASE="${BARES_ENTREGAS_BASE:-https://github.com/$REPO/releases/latest/download}"; ITER=200000   # BARES_ENTREGAS_BASE solo para probar
EXTRA=("$@")
paso() { printf '\n\033[36m== %s\033[0m\n' "$*"; }
falla() { printf '\033[31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }
for c in curl openssl sha256sum tar; do command -v "$c" >/dev/null || falla "Falta $c:  sudo apt install -y curl openssl coreutils tar"; done
DIR="$HOME/bares-entrega/$(date +%Y%m%d-%H%M%S)"; mkdir -p "$DIR"; cd "$DIR"

paso "Bajando el paquete"
curl -fL --retry 3 -o paquete-ubuntu.enc "$BASE/paquete-ubuntu.enc" || falla "No se pudo bajar el paquete (¿hay Internet?)."
HUELLA="$(curl -fsSL "$BASE/paquete-ubuntu.sha256" | awk '{print $1}')"

paso "Descifrando"
read -r -s -p "Clave del paquete: " CLAVE; echo
printf '%s' "$CLAVE" | openssl enc -d -aes-256-cbc -pbkdf2 -iter "$ITER" -in paquete-ubuntu.enc -out paquete.tar.gz -pass stdin 2>/dev/null || falla "Clave incorrecta o archivo dañado."
unset CLAVE
[ "$(sha256sum paquete.tar.gz | cut -d' ' -f1)" = "$HUELLA" ] || falla "La huella no coincide: el paquete no es el original o se bajó incompleto. Repita el comando."
echo "Paquete verificado (huella SHA-256 correcta)."
mkdir -p paquete && tar -xzf paquete.tar.gz -C paquete 2>/dev/null || true
rm -f paquete-ubuntu.enc paquete.tar.gz
cd paquete; chmod +x ./*.sh

if systemctl list-unit-files 2>/dev/null | grep -q '^sistema-bares.service'; then
  paso "El sistema ya está instalado: ACTUALIZANDO (pide la clave de esta PC)"
  sudo ./actualizar.sh
else
  paso "Primera vez en esta PC: INSTALANDO (pide la clave de esta PC)"
  sudo ./instalar.sh "${EXTRA[@]}"
fi
printf '\nListo. Las cajas solo deben recargar la página (F5).\n'
