#!/usr/bin/env bash
# Restore 288px sidebar and increase six desktop navigation buttons vertically.
# Does not change Educhi app, student data, auth, or admin.
set -Eeuo pipefail
cd /var/www/biobilingual
test -f bkhost/index.html || { echo "Missing Bio student page"; exit 1; }
python3 - <<'PY'
from pathlib import Path
from datetime import datetime
import shutil
p = Path('/var/www/biobilingual/bkhost/index.html')
s = p.read_text(encoding='utf-8')
changes = [
("hidden md:flex shrink-0 bg-white border-r border-slate-200 flex-col justify-between transition-all duration-300 z-20 ${isSidebarOpen ? 'w-96' : 'w-20'}",
 "hidden md:flex shrink-0 bg-white border-r border-slate-200 flex-col transition-all duration-300 z-20 ${isSidebarOpen ? 'w-72' : 'w-20'}"),
('        <div>\n          <div className="h-20 flex items-center justify-center border-b border-slate-100 shrink-0 cursor-pointer"',
 '        <div className="flex min-h-0 flex-1 flex-col">\n          <div className="h-20 flex items-center justify-center border-b border-slate-100 shrink-0 cursor-pointer"'),
('<div className="mt-2 flex flex-col gap-1.5 px-2">',
 '<div className="mt-2 flex min-h-0 flex-1 flex-col gap-2 overflow-y-auto px-2 pb-3">'),
("className={`flex items-center border shadow-sm ${isSidebarOpen ? 'justify-start text-left px-3.5' : 'justify-center'} py-1.5 rounded-xl transition-all group",
 "className={`flex items-center border shadow-sm ${isSidebarOpen ? 'flex-1 min-h-[58px] justify-start text-left px-3.5' : 'shrink-0 min-h-12 justify-center'} rounded-xl transition-all group"),
('<span className="text-left leading-tight"><span className="block text-[17px] font-extrabold">{item.english}</span></span>',
 '<span className="text-left leading-tight"><span className="block text-[19px] font-extrabold">{item.english}</span></span>'),
('className="mt-2 w-full flex items-center justify-center p-1.5 rounded-xl border border-slate-200 text-slate-500 hover:bg-stone-50 transition-colors"',
 'className="mt-1 min-h-12 w-full shrink-0 flex items-center justify-center rounded-xl border border-slate-200 text-slate-500 hover:bg-stone-50 transition-colors"'),
('<div className="p-4 border-t border-slate-100 bg-white">',
 '<div className="shrink-0 p-4 border-t border-slate-100 bg-white">')
]
if all(new in s for _, new in changes):
    print('ALREADY UPDATED: 288px sidebar with tall menu buttons.')
    raise SystemExit(0)
for old, new in changes:
    if s.count(old) != 1:
        raise SystemExit('STOP: Bio sidebar source differs from expected. No files changed.\nMissing: ' + old[:110])
backup = Path('/root') / ('bio-sidebar-before-tall-menu-' + datetime.now().strftime('%Y%m%d-%H%M%S') + '.html')
shutil.copy2(p, backup)
for old, new in changes:
    s = s.replace(old, new, 1)
temp = p.with_name('index.html.tall-buttons.new')
temp.write_text(s, encoding='utf-8')
temp.chmod(p.stat().st_mode & 0o777)
temp.replace(p)
print('DONE: Sidebar restored to 288px; menu buttons fill vertical space toward profile.')
print('BACKUP:', backup)
PY
echo "Public page HTTP:"
curl -sS -o /dev/null -w "%{http_code}\n" https://bio.educhi.xyz/
