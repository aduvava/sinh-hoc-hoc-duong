#!/usr/bin/env bash
# Build an isolated fast preview. Does not edit the live homepage or databases.
set -Eeuo pipefail

SITE=/var/www/biobilingual
cd "$SITE"

for tool in node npx python3; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "ERROR: Missing $tool. Nothing changed." >&2
    exit 2
  fi
done

if [[ ! -s bkhost/index.html ]]; then
  echo "ERROR: bkhost/index.html is missing. Nothing changed." >&2
  exit 2
fi

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT
export BIO_PREVIEW_TEMP_DIR="$workdir"

python3 - <<'PY'
from pathlib import Path
import os, re

site = Path('/var/www/biobilingual')
tmp = Path(os.environ['BIO_PREVIEW_TEMP_DIR'])
html = (site / 'bkhost/index.html').read_text(encoding='utf-8')
match = re.search(r'<script\s+type="text/babel">([\s\S]*?)</script>', html)
if not match:
    raise RuntimeError('Cannot locate the JSX script. No files have been changed.')

app = match.group(1)
boot = 'ReactDOM.createRoot(document.getElementById(\'root\')).render(<App />);'
if boot not in app:
    raise RuntimeError('Cannot find React startup code. No files have been changed.')

app = app.replace(boot, '''
class BioErrorBoundary extends React.Component {
  constructor(props) { super(props); this.state = { failed: false }; }
  static getDerivedStateFromError(error) { return { failed: true, detail: String(error?.message || error).slice(0, 350) }; }
  componentDidCatch(error, info) { console.error('Bio app rendering failed:', error, info); }
  render() {
    if (!this.state.failed) return this.props.children;
    return React.createElement('div', {
      style: { maxWidth: 680, margin: '4rem auto', padding: 24, fontFamily: 'Arial,sans-serif' }
    },
      React.createElement('h2', null, 'Không thể hiển thị nội dung'),
      React.createElement('p', null, 'Có lỗi tải trang. Vui lòng thử lại hoặc liên hệ quản trị viên.'),
      React.createElement('pre', {style:{whiteSpace:'pre-wrap',overflowWrap:'anywhere',background:'#fff1f2',border:'1px solid #fecdd3',padding:'12px',fontSize:'13px'}}, this.state.detail || 'Không có chi tiết lỗi'),
      React.createElement('button', { onClick: () => location.reload() }, 'Tải lại trang')
    );
  }
}
ReactDOM.createRoot(document.getElementById('root')).render(
  <BioErrorBoundary><App /></BioErrorBoundary>
);
''')

helper_anchor = 'const {useState,useEffect,useRef,useMemo}=React;'
if helper_anchor not in app:
    raise RuntimeError('Unexpected React source format. No files have been changed.')
helper = '''
const safeBioArray = key => {
  try { const parsed = JSON.parse(localStorage.getItem(key) || '[]');
    return Array.isArray(parsed) ? parsed : []; }
  catch { return []; }
};
'''
app = app.replace(helper_anchor, helper_anchor + '\n' + helper, 1)
for key in ['bioedu_vocab_bank', 'bioedu_materials_library', 'bioedu_exam_bank',
            'bioedu_entertainment', 'bioedu_results', 'bioedu_students']:
    old = "JSON.parse(localStorage.getItem('" + key + "') || '[]')"
    app = app.replace(old, "safeBioArray('" + key + "')")

# Repair partial quick-access records from an older browser's localStorage.
# Keep valid saved labels but restore required properties if a record is incomplete.
old_quick_access = "return { ...siteContentDefaults, ...saved, home: { ...siteContentDefaults.home, ...(saved?.home || {}) }, plant: { ...siteContentDefaults.plant, ...(saved?.plant || {}) }, quickAccess: Array.isArray(saved?.quickAccess) && saved.quickAccess.length === 4 ? saved.quickAccess : siteContentDefaults.quickAccess };"
new_quick_access = """const quickAccess = Array.isArray(saved?.quickAccess) && saved.quickAccess.length === 4
      ? saved.quickAccess.map((raw, index) => {
          const base = siteContentDefaults.quickAccess[index];
          const item = raw && typeof raw === 'object' ? raw : {};
          return Object.fromEntries(
            Object.entries(base).map(([key, value]) =>
              [key, typeof item[key] === 'string' && item[key].trim() ? item[key] : value]
            )
          );
        })
      : siteContentDefaults.quickAccess;
    return { ...siteContentDefaults, ...saved, home: { ...siteContentDefaults.home, ...(saved?.home || {}) }, plant: { ...siteContentDefaults.plant, ...(saved?.plant || {}) }, quickAccess };"""
if old_quick_access in app:
    app = app.replace(old_quick_access, new_quick_access, 1)

preview = html[:match.start()] + '<script defer src="/bkhost/assets/bio-preview.js"></script>' + html[match.end():]
source_css = '<script defer src="https://cdn.tailwindcss.com"></script>'
source_babel = '<script defer src="https://unpkg.com/@babel/standalone@7.24.7/babel.min.js"></script>'
if source_css not in preview or source_babel not in preview:
    raise RuntimeError('Unexpected CDN script layout. No files have been changed.')
preview = preview.replace(source_css, '<link rel="stylesheet" href="/bkhost/assets/bio-preview.css">', 1)
preview = preview.replace(source_babel, '', 1)
preview = preview.replace('<script src="./history.js?v=20261015"></script>',
                          '<script defer src="./history.js?v=20261015"></script>')

(tmp / 'bio-preview.jsx').write_text(app, encoding='utf-8')
(tmp / 'bio-fast-preview.html').write_text(preview, encoding='utf-8')
(tmp / 'input.css').write_text('@tailwind base;\n@tailwind components;\n@tailwind utilities;\n')
print('Source prepared. Compiling JavaScript and CSS...')
PY

npx --yes esbuild@0.25.12 "$workdir/bio-preview.jsx" --outfile="$workdir/bio-preview.js" --target=es2020 --minify
npx --yes tailwindcss@3.4.17 -i "$workdir/input.css" -o "$workdir/bio-preview.css" --content "$SITE/bkhost/index.html" --minify
node --check "$workdir/bio-preview.js"

for asset in bio-preview.js bio-preview.css bio-fast-preview.html; do
  if [[ ! -s "$workdir/$asset" ]]; then
    echo "ERROR: missing build output $asset. Nothing changed." >&2
    exit 2
  fi
done

mkdir -p "$SITE/bkhost/assets"
install -m 644 "$workdir/bio-preview.js" "$SITE/bkhost/assets/bio-preview.js"
install -m 644 "$workdir/bio-preview.css" "$SITE/bkhost/assets/bio-preview.css"
install -m 644 "$workdir/bio-fast-preview.html" "$SITE/bkhost/fast-preview.html"

echo '===== BUILD COMPLETED: PREVIEW ONLY ====='
ls -lh "$SITE/bkhost/fast-preview.html" "$SITE/bkhost/assets/bio-preview.js" "$SITE/bkhost/assets/bio-preview.css"
echo 'Open https://bio.educhi.xyz/bkhost/fast-preview.html'
echo 'The live / and /bkhost/ pages were NOT changed.'
