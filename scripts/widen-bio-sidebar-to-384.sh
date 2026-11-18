#!/usr/bin/env bash
# Widen only the Bio student desktop sidebar. Keep main Educhi untouched.
set -Eeuo pipefail
FILE=/var/www/biobilingual/bkhost/index.html
test -s "$FILE" || { echo "ERROR: Bio index.html not found"; exit 1; }
export BIO_SIDEBAR_FILE="$FILE"
python3 - <<'PY'
from pathlib import Path
from datetime import datetime
import os, shutil
p = Path(os.environ['BIO_SIDEBAR_FILE'])
s = p.read_text(encoding='utf-8')
old = "hidden md:flex bg-white border-r border-slate-200 flex-col justify-between transition-all duration-300 z-20 ${isSidebarOpen ? 'w-72' : 'w-20'}"
new = "hidden md:flex shrink-0 bg-white border-r border-slate-200 flex-col justify-between transition-all duration-300 z-20 ${isSidebarOpen ? 'w-96' : 'w-20'}"
oldmain = '<main ref={mainRef} className="flex-1 overflow-y-auto relative bg-[#eef6ff] pb-20 md:pb-0">'
newmain = '<main ref={mainRef} className="flex-1 min-w-0 overflow-y-auto relative bg-[#eef6ff] pb-20 md:pb-0">'
if new in s and newmain in s:
    print('ALREADY UPDATED: sidebar 384px (w-96), prevented flex shrinking.')
    raise SystemExit(0)
if s.count(old) != 1 or s.count(oldmain) != 1:
    raise SystemExit('STOP: Unexpected sidebar code; nothing changed.')
backup = Path('/root') / ('bio-sidebar-backup-' + datetime.now().strftime('%Y%m%d-%H%M%S') + '.html')
shutil.copy2(p, backup)
updated = s.replace(old, new, 1).replace(oldmain, newmain, 1)
tmp = p.with_name('index.html.sidebar-wider-tmp')
tmp.write_text(updated, encoding='utf-8')
tmp.chmod(p.stat().st_mode & 0o777)
tmp.replace(p)
print('DONE: Bio sidebar 288px -> 384px; width no longer shrinks.')
print('BACKUP:', backup)
print('Only Bio student HTML changed. Educhi, admin, OAuth and database unchanged.')
PY
curl -sS -o /dev/null -w 'Website HTTP %{http_code}\n' https://bio.educhi.xyz/
