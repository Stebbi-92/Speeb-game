#!/bin/bash
# Copies docs/wiki into the repository's GitHub wiki. Needs GH_TOKEN (the Actions token will do).
set -e
repo="${GITHUB_REPOSITORY:-Stebbi-92/Speeb-game}"
dir=$(mktemp -d)
git clone -q "https://x-access-token:${GH_TOKEN}@github.com/${repo}.wiki.git" "$dir"
for f in docs/wiki/*.md; do [ "$(basename "$f")" = README.md ] || cp "$f" "$dir/"; done
cd "$dir"
git add -A
if git diff --cached --quiet; then echo "wiki unchanged"; exit 0; fi
git -c user.name="brelm-release" -c user.email="actions@users.noreply.github.com" commit -qm "Wiki from ${GITHUB_SHA:-local}"
git push -q
echo "wiki updated"
