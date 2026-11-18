#!/usr/bin/env bash
# Slightly wider desktop sidebar only; preserve all other site files and data.
set -Eeuo pipefail
file=/var/www/biobilingual/bkhost/index.html
[[ -f "$file" ]] || { echo "ERROR: Bio student page not found: $file"; exit 2; }
export BIO_SIDEBAR_FILE="$file"
python3 - <<'PY'
from pathlib import Path
import os, shutil
from datetime import datetime
path=Path(os.environ["BIO_SIDEBAR_FILE"])
source=path.read_text(encoding="utf-8")
width_old="isSidebarOpen ? 'w-64' : 'w-20'"
width_new="isSidebarOpen ? 'w-72' : 'w-20'"
pad_old="isSidebarOpen ? 'justify-start text-left px-2.5' : 'justify-center'"
pad_new="isSidebarOpen ? 'justify-start text-left px-3.5' : 'justify-center'"
if width_new in source and pad_new in source:
    print("ALREADY UPDATED: Sidebar 288px wide.")
    raise SystemExit(0)
if source.count(width_old) != 1 or source.count(pad_old) != 1:
    raise SystemExit("STOP: Sidebar source differs from expected, no changes made.")
backup=Path("/root")/("bio-sidebar-backup-"+datetime.now().strftime("%Y%m%d-%H%M%S")+".html")
shutil.copy2(path, backup)
updated=source.replace(width_old,width_new).replace(pad_old,pad_new)
tmp=path.with_name(path.name+".sidebar-temp")
tmp.write_text(updated,encoding="utf-8")
tmp.chmod(path.stat().st_mode & 0o777)
tmp.replace(path)
print("DONE: Desktop sidebar width 256px -> 288px; button padding slightly increased.")
print("BACKUP:",backup)
print("The Educhi main site, other pages, authentication and databases are untouched.")
PY
echo 'Public page response:'
curl -sS -o /dev/null -w 'HTTP %{http_code}\n' 'https://bio.educhi.xyz/'
