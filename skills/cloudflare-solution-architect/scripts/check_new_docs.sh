#!/usr/bin/env bash
# Lists Reference Architecture pages that exist on developers.cloudflare.com
# but are not yet in references/catalog.md (i.e. the skill is out of date).
# Usage: bash scripts/check_new_docs.sh
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

curl -fsSL https://developers.cloudflare.com/sitemap-0.xml \
  | grep -o '<loc>[^<]*reference-architecture[^<]*</loc>' \
  | sed -e 's/<[^>]*>//g' -e 's#/*$#/#' | sort -u > "$tmp/live"

grep -o '](https://developers.cloudflare.com/reference-architecture/[^)]*' "$here/references/catalog.md" | sed 's/^](//' \
  | sed 's#/*$#/#' | sort -u > "$tmp/known"

new="$(comm -23 "$tmp/live" "$tmp/known" | grep -vE '/diagrams/[a-z-]+/$' || true)"
gone="$(comm -13 "$tmp/live" "$tmp/known" || true)"

echo "Live pages: $(wc -l < "$tmp/live") | In catalog: $(wc -l < "$tmp/known")"
if [ -n "$new" ]; then echo "NEW (not in skill):"; echo "$new"; fi
if [ -n "$gone" ]; then echo "REMOVED (in skill, no longer live):"; echo "$gone"; fi
[ -z "$new$gone" ] && echo "Catalog is up to date."
exit 0
