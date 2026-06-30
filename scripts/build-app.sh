#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
APP_DIR="${BUILD_DIR}/PortGlide.app"
CONTENTS="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS}/MacOS"

cd "${ROOT_DIR}"
echo "Собираю PortGlide…"
swift build -c release

# Never overwrite the executable while macOS is running its signed pages.
RUNNING_PIDS="$(/usr/bin/pgrep -x PortGlide || true)"
if [ -n "${RUNNING_PIDS}" ]; then
    /bin/kill ${RUNNING_PIDS} 2>/dev/null || true
    for _ in $(seq 1 20); do
        /usr/bin/pgrep -x PortGlide >/dev/null 2>&1 || break
        sleep 0.1
    done
fi

# Recreate the generated bundle so Finder/iCloud extended attributes from a
# previous build cannot invalidate code signing.
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
cp "${ROOT_DIR}/.build/release/PortGlide" "${MACOS_DIR}/PortGlide"
mkdir -p "${CONTENTS}/Resources"
cp "${ROOT_DIR}/Assets/PortGlide.icns" "${CONTENTS}/Resources/PortGlide.icns"

cat > "${CONTENTS}/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>PortGlide</string>
    <key>CFBundleExecutable</key>
    <string>PortGlide</string>
    <key>CFBundleIdentifier</key>
    <string>io.portglide.macos</string>
    <key>CFBundleName</key>
    <string>PortGlide</string>
    <key>CFBundleIconFile</key>
    <string>PortGlide</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

chmod +x "${MACOS_DIR}/PortGlide"
/usr/bin/xattr -cr "${APP_DIR}"
/usr/bin/codesign --force --deep --sign - "${APP_DIR}"
/usr/bin/codesign --verify --deep --strict "${APP_DIR}"
if [ "${PORTGLIDE_SKIP_OPEN:-0}" != "1" ]; then
    echo "Открываю ${APP_DIR}"
    open "${APP_DIR}"
fi
