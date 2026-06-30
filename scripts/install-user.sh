#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_DIR="${HOME}/Applications"
APP_DIR="${INSTALL_DIR}/PortGlide.app"

PORTGLIDE_SKIP_OPEN=1 "${ROOT_DIR}/scripts/build-app.sh"

mkdir -p "${INSTALL_DIR}"
rm -rf "${APP_DIR}"
/usr/bin/ditto "${ROOT_DIR}/build/PortGlide.app" "${APP_DIR}"
/usr/bin/xattr -cr "${APP_DIR}"
/usr/bin/codesign --verify --deep --strict "${APP_DIR}"

echo "PortGlide установлен независимо от исходников: ${APP_DIR}"
open "${APP_DIR}"
