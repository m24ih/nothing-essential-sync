#!/bin/bash
# ==============================================================================
# Build Script: Package Nothing Essential Sync into Flashable Module ZIP
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION=$(grep "^version=" "$SCRIPT_DIR/module.prop" | cut -d'=' -f2)
ZIP_NAME="nothing-essential-sync-${VERSION}.zip"
BUILD_DIR="/tmp/module_build_$$"

echo "=== Building ${ZIP_NAME} ==="

rm -rf "${BUILD_DIR}" "${SCRIPT_DIR}/${ZIP_NAME}"
mkdir -p "${BUILD_DIR}"

# 1. Copy required module files
cp -f "${SCRIPT_DIR}/module.prop" "${BUILD_DIR}/"
cp -f "${SCRIPT_DIR}/customize.sh" "${BUILD_DIR}/"
cp -f "${SCRIPT_DIR}/service.sh" "${BUILD_DIR}/"
cp -f "${SCRIPT_DIR}/uninstall.sh" "${BUILD_DIR}/"
cp -f "${SCRIPT_DIR}/sync.sh" "${BUILD_DIR}/"
cp -f "${SCRIPT_DIR}/setup.sh" "${BUILD_DIR}/"
cp -f "${SCRIPT_DIR}/config.env" "${BUILD_DIR}/"
cp -f "${SCRIPT_DIR}/action.sh" "${BUILD_DIR}/"

# 2. Copy binary
mkdir -p "${BUILD_DIR}/bin"
cp -f "${SCRIPT_DIR}/bin/sqlite3" "${BUILD_DIR}/bin/"
chmod 755 "${BUILD_DIR}/bin/sqlite3" "${BUILD_DIR}/sync.sh" "${BUILD_DIR}/service.sh" "${BUILD_DIR}/setup.sh" "${BUILD_DIR}/action.sh"

# 3. Copy WebUI & WebRoot (Official KernelSU standard is webroot)
mkdir -p "${BUILD_DIR}/webroot" "${BUILD_DIR}/webui"
cp -r "${SCRIPT_DIR}/webroot/"* "${BUILD_DIR}/webroot/"
cp -r "${SCRIPT_DIR}/webui/"* "${BUILD_DIR}/webui/"

# 4. Create ZIP
cd "${BUILD_DIR}"
python3 -m zipfile -c "${SCRIPT_DIR}/${ZIP_NAME}" ./* >/dev/null

rm -rf "${BUILD_DIR}"

echo "✓ Successfully generated flashable module:"
echo "  ${SCRIPT_DIR}/${ZIP_NAME} ($(du -h "${SCRIPT_DIR}/${ZIP_NAME}" | cut -f1))"
