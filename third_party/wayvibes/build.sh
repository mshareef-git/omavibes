#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT="$(cd "$ROOT/../.." && pwd)/bin/wayvibes"

make -C "$ROOT" clean
make -C "$ROOT"

install -m 755 "$ROOT/wayvibes" "$OUTPUT"

echo "Built: $OUTPUT"
sha256sum "$OUTPUT"
