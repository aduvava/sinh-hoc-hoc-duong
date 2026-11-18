#!/usr/bin/env bash
# Deploy English-only student UI to bio.educhi.xyz with backup and validation.
# Keeps Supabase, site content, OAuth settings, and the separate Educhi app unchanged.
set -Eeuo pipefail
SITE=/var/www/biobilingual
COMMIT=042088a0537de10bef62b69ceb43283ac64f6c82
BASE="https://raw.githubusercontent.com/aduvava/sinh-hoc-hoc-duong/$COMMIT"
cd "$SITE"
test -s bkhost/index.html
test -s bkhost/history.js
if ! command -v node >/dev/null 2>&1; then
  export NVM_DIR="$HOME/.nvm"
  [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"
fi
for bin in python3 curl node npx; do
  command -v "$bin" >/dev/null 2>&1 || { echo "Missing $bin; no changes"; exit 2; }
done
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
for file in index.html history.js; do
  curl -fsSL --retry 2 --connect-timeout 12 --max-time 60 "$BASE/bkhost/$file" -o "$WORK/$file"
done
export BIO_ENGLISH_DEPLOY_WORK="$WORK"
python3 - <<'PY'
import os, re
from pathlib import Path
p = Path(os.environ['BIO_ENGLISH_DEPLOY_WORK'])
html = (p/'index.html').read_text('utf-8')
history = (p/'history.js').read_text('utf-8')
checks = {
 'English button helper': 'const englishButtonLabel =' in html,
 'React history event': 'bioedu-open-history' in html and "window.addEventListener('bioedu-open-history', loadHistory)" in history,
 'No legacy DOM mutation': 'MutationObserver' not in history,
 'Correct isolated backend': 'yjdbrjoolgblmamdphle.supabase.co' in html,
 'JSX present': bool(re.search(r'<script\s+type="text/babel">([\s\S]*?)</script>', html)),
 'Enough buttons': html.count('<button') >= 90,
 'English history cache': 'history.js?v=20261118-english' in html
}
for key, status in checks.items(): print(f'{"OK" if status else "FAIL"}: {key}')
if not all(checks.values()): raise SystemExit('Validation failed. No changes.')
app = re.search(r'<script\s+type="text/babel">([\s\S]*?)</script>', html).group(1)
(p/'app.jsx').write_text(app, encoding='utf-8')
PY

node --check "$WORK/history.js"
npx --yes esbuild@0.25.12 "$WORK/app.jsx" --outfile="$WORK/validation.js" --target=es2020 --minify >/dev/null
node --check "$WORK/validation.js"

# Fetch the compatible precompile builder before making any live changes.
curl -fsSL --retry 2 "$BASE/scripts/build-bio-fast-preview.sh" -o "$WORK/build-preview.sh"

BACKUP="/root/bio-english-ui-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"
cp -a bkhost/index.html bkhost/history.js "$BACKUP/"
echo "Backed up student UI to $BACKUP"

# Atomic replacement; do not touch the public root index.html symlink.
install -m 644 "$WORK/index.html" bkhost/index.html.english-new
install -m 644 "$WORK/history.js" bkhost/history.js.english-new
mv -f bkhost/index.html.english-new bkhost/index.html
mv -f bkhost/history.js.english-new bkhost/history.js

if ! bash "$WORK/build-preview.sh"; then
  echo "Preview build failed; restoring previous production UI..."
  cp -a "$BACKUP/index.html" bkhost/index.html
  cp -a "$BACKUP/history.js" bkhost/history.js
  exit 1
fi

echo "==== ENGLISH BUTTON UPDATE COMPLETED ===="
echo "Backup: $BACKUP"
echo "Site: https://bio.educhi.xyz/"
echo "Compiled preview: https://bio.educhi.xyz/bkhost/fast-preview.html"
echo "Note: data and main Educhi site were not changed."
