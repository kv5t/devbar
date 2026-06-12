#!/usr/bin/env bash
# Verifie les binaires cloudflared dans Vendor/
# Modele: tony-roslund/tunnelbar scripts/verify-cloudflared.sh
#
# Verification:
#   1. Les binaires existent pour les deux architectures
#   2. Les binaires sont executables
#   3. Les checksums SHA-256 correspondent

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR_DIR="$ROOT_DIR/Vendor"
CHECKSUM_FILE="$VENDOR_DIR/cloudflared-binaries.sha256"

echo "=== Verification de cloudflared ==="

# Verifier que le dossier Vendor existe
if [[ ! -d "$VENDOR_DIR" ]]; then
    echo "Erreur: dossier Vendor/ manquant. Lancez scripts/install-cloudflared.sh d'abord." >&2
    exit 1
fi

# Verifier les binaires pour chaque architecture
for arch in arm64 amd64; do
    binary="$VENDOR_DIR/cloudflared-$arch"

    if [[ ! -f "$binary" ]]; then
        echo "Erreur: $binary manquant. Lancez scripts/install-cloudflared.sh d'abord." >&2
        exit 1
    fi

    if [[ ! -x "$binary" ]]; then
        echo "Erreur: $binary n'est pas executable." >&2
        exit 1
    fi

    echo "  OK: $binary"
done

# Verifier les checksums
if [[ ! -f "$CHECKSUM_FILE" ]]; then
    echo "Erreur: $CHECKSUM_FILE manquant. Lancez scripts/install-cloudflared.sh d'abord." >&2
    exit 1
fi

echo ""
echo "Verification des checksums SHA-256..."
(
    cd "$VENDOR_DIR"
    shasum -a 256 -c "$(basename "$CHECKSUM_FILE")"
)

# Afficher la version
if [[ -f "$VENDOR_DIR/cloudflared-release.txt" ]]; then
    echo ""
    echo "cloudflared $(cat "$VENDOR_DIR/cloudflared-release.txt") verifie"
else
    echo ""
    echo "cloudflared binaires verifies (version inconnue)"
fi
