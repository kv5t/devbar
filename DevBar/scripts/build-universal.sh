#!/usr/bin/env bash
# Build universal binary DevBar + bundle cloudflared
# Modele: tony-roslund/tunnelbar scripts/package-app.sh
#
# Ce script:
#   1. Verifie que les binaires cloudflared existent
#   2. Compile DevBar pour ARM64 et Intel
#   3. Fusionne les binaires en un universal binary
#   4. Copie cloudflared dans Contents/Resources/
#
# Pre-requis:
#   ./scripts/install-cloudflared.sh  (telecharge les binaires dans Vendor/)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SCHEME="DevBar"
BUILD_DIR="$PROJECT_DIR/build"

echo "=== DevBar - Build Universal + Bundle Cloudflared ==="
echo ""

# 1. Verifier les binaires cloudflared
echo "Verification de cloudflared..."
if ! "$SCRIPT_DIR/verify-cloudflared.sh"; then
    echo "Dossier Vendor/ manquant ou incomplet. Tentative d'installation..."
    if ! "$SCRIPT_DIR/install-cloudflared.sh"; then
        echo "Erreur: Impossible d'installer cloudflared automatiquement."
        exit 1
    fi
    # Re-verifier après installation
    "$SCRIPT_DIR/verify-cloudflared.sh"
fi
echo ""

# 2. Nettoyer les precedents builds
echo "Nettoyage..."
rm -rf "$BUILD_DIR"

# 3. Build pour Apple Silicon
echo "Build pour Apple Silicon (arm64)..."
xcodebuild \
    -project "$PROJECT_DIR/DevBar.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/AppleSilicon" \
    ARCHS=arm64 \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_ALLOWED=NO \
    clean build 2>&1 | tail -3

# 4. Build pour Intel
echo ""
echo "Build pour Intel (x86_64)..."
xcodebuild \
    -project "$PROJECT_DIR/DevBar.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/Intel" \
    ARCHS=x86_64 \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_ALLOWED=NO \
    clean build 2>&1 | tail -3

# 5. Trouver les binaires compiles
ARM64_APP="$BUILD_DIR/AppleSilicon/Build/Products/Release/DevBar.app"
INTEL_APP="$BUILD_DIR/Intel/Build/Products/Release/DevBar.app"

if [[ ! -d "$ARM64_APP" ]] || [[ ! -d "$INTEL_APP" ]]; then
    echo "Erreur: les builds n'ont pas abouti"
    echo "  ARM64: $ARM64_APP"
    echo "  Intel: $INTEL_APP"
    exit 1
fi

# 6. Creer l'app universelle
echo ""
echo "Creation de l'app universelle..."
OUTPUT_APP="$BUILD_DIR/DevBar.app"
rm -rf "$OUTPUT_APP"
cp -R "$ARM64_APP" "$OUTPUT_APP"

# 7. Fusionner les binaires avec lipo
ARM64_BINARY="$ARM64_APP/Contents/MacOS/DevBar"
INTEL_BINARY="$INTEL_APP/Contents/MacOS/DevBar"
OUTPUT_BINARY="$OUTPUT_APP/Contents/MacOS/DevBar"

echo "Fusion des binaires..."
lipo -create \
    "$ARM64_BINARY" \
    "$INTEL_BINARY" \
    -output "$OUTPUT_BINARY"

echo "  $(lipo -info "$OUTPUT_BINARY")"

# 8. Copier cloudflared dans Contents/Resources/ (TunnelBar style)
VENDOR_DIR="$PROJECT_DIR/Vendor"
RESOURCES_DIR="$OUTPUT_APP/Contents/Resources"

echo ""
echo "Bundle de cloudflared dans Resources/..."
cp "$VENDOR_DIR/cloudflared-arm64" "$RESOURCES_DIR/cloudflared-arm64"
chmod 755 "$RESOURCES_DIR/cloudflared-arm64"

cp "$VENDOR_DIR/cloudflared-amd64" "$RESOURCES_DIR/cloudflared-amd64"
chmod 755 "$RESOURCES_DIR/cloudflared-amd64"

# Copier la version si disponible
if [[ -f "$VENDOR_DIR/cloudflared-release.txt" ]]; then
    cp "$VENDOR_DIR/cloudflared-release.txt" "$RESOURCES_DIR/cloudflared-release.txt"
    echo "  Version: $(cat "$VENDOR_DIR/cloudflared-release.txt")"
fi

echo "  cloudflared-arm64: $(ls -lh "$RESOURCES_DIR/cloudflared-arm64" | awk '{ print $5 }')"
echo "  cloudflared-amd64: $(ls -lh "$RESOURCES_DIR/cloudflared-amd64" | awk '{ print $5 }')"

# 9. Copier les frameworks
if [[ -d "$ARM64_APP/Contents/Frameworks" ]]; then
    echo ""
    echo "Copie des frameworks..."
    cp -R "$ARM64_APP/Contents/Frameworks" "$OUTPUT_APP/Contents/Frameworks" 2>/dev/null || true
fi

echo ""
echo "=== Build termine avec succes ==="
echo "App: $OUTPUT_APP"
echo ""
echo "Pour installer:"
echo "  cp -R \"$OUTPUT_APP\" /Applications/"
echo ""
echo "Pour tester directement:"
echo "  open \"$OUTPUT_APP\""
