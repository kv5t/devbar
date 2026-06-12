#!/usr/bin/env bash
# Telecharge cloudflared pour DevBar (ARM64 + Intel)
# Modele: tony-roslund/tunnelbar scripts/install-cloudflared.sh
#
# Verification SHA-256 des binaires via les digests du release GitHub.
# Utilisation:
#   ./scripts/install-cloudflared.sh              # derniere version
#   CLOUDFLARED_VERSION=2026.6.0 ./scripts/install-cloudflared.sh  # version specifique

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR_DIR="$ROOT_DIR/Vendor"
VERSION="${CLOUDFLARED_VERSION:-}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
RELEASE_JSON="$TMP_DIR/release.json"

# Resoudre la version depuis GitHub
if [[ -z "$VERSION" ]]; then
    echo "Detection de la derniere version de cloudflared..."
    curl -fsSL https://api.github.com/repos/cloudflare/cloudflared/releases/latest -o "$RELEASE_JSON"
    VERSION="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('tag_name',''))" "$RELEASE_JSON")"
else
    echo "Utilisation de la version: $VERSION"
    curl -fsSL "https://api.github.com/repos/cloudflare/cloudflared/releases/tags/$VERSION" -o "$RELEASE_JSON"
fi

if [[ -z "$VERSION" || "$VERSION" == "latest" ]]; then
    echo "Erreur: impossible de resolver la version de cloudflared" >&2
    exit 1
fi

echo "Version: $VERSION"

BASE_URL="https://github.com/cloudflare/cloudflared/releases/download/$VERSION"
mkdir -p "$VENDOR_DIR"

# Extraire les checksums SHA-256 depuis les digests du release
CHECKSUMS_FILE="$VENDOR_DIR/cloudflared-release-checksums.txt"
python3 -c "
import json, sys
release = json.load(open(sys.argv[1]))
lines = []
for asset in release.get('assets', []):
    name = asset.get('name', '')
    digest = asset.get('digest', '')
    if name.startswith('cloudflared-') and digest.startswith('sha256:'):
        sha = digest.replace('sha256:', '')
        lines.append(f'{name}: {sha}')
if not lines:
    print('Erreur: aucun digest SHA-256 trouve dans le release', file=sys.stderr)
    sys.exit(1)
with open(sys.argv[2], 'w') as f:
    f.write('\n'.join(lines) + '\n')
" "$RELEASE_JSON" "$CHECKSUMS_FILE"

echo "Checksums extraits:"
cat "$CHECKSUMS_FILE"

checksum_for() {
    local file="$1"
    awk -F ': ' -v file="$file" '$1 == file { print $2 }' "$CHECKSUMS_FILE"
}

download_arch() {
    local arch="$1"
    local archive="cloudflared-darwin-$arch.tgz"
    local archive_path="$TMP_DIR/$archive"
    local extract_dir="$TMP_DIR/extract-$arch"
    local expected
    local actual
    local binary_path

    expected="$(checksum_for "$archive")"
    if [[ -z "$expected" ]]; then
        echo "Erreur: checksum non trouve pour $archive" >&2
        exit 1
    fi

    echo ""
    echo "Telechargement pour $arch..."
    curl -fsSL "$BASE_URL/$archive" -o "$archive_path"

    actual="$(shasum -a 256 "$archive_path" | awk '{ print $1 }')"

    if [[ "$actual" != "$expected" ]]; then
        echo "Erreur: checksum mismatch pour $archive" >&2
        echo "  Attendu: $expected" >&2
        echo "  Recu:    $actual" >&2
        exit 1
    fi
    echo "  SHA-256 verifie: $actual"

    mkdir -p "$extract_dir"
    tar -xzf "$archive_path" -C "$extract_dir"

    binary_path="$(find "$extract_dir" -type f -name cloudflared -print -quit)"
    if [[ -z "$binary_path" ]]; then
        echo "Erreur: binaire cloudflared non trouve dans l'archive" >&2
        exit 1
    fi

    cp "$binary_path" "$VENDOR_DIR/cloudflared-$arch"
    chmod 755 "$VENDOR_DIR/cloudflared-$arch"
    echo "  Installe: $VENDOR_DIR/cloudflared-$arch"
}

download_arch arm64
download_arch amd64

# Sauvegarder la version
printf '%s\n' "$VERSION" > "$VENDOR_DIR/cloudflared-release.txt"

# Generer les checksums des binaires finaux
(
    cd "$VENDOR_DIR"
    shasum -a 256 cloudflared-arm64 cloudflared-amd64 > cloudflared-binaries.sha256
)

# Verifier avec le script de verification
"$ROOT_DIR/scripts/verify-cloudflared.sh"

echo ""
echo "cloudflared $VERSION installe dans $VENDOR_DIR"
