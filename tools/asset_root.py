#!/usr/bin/env python3
"""Where this clone keeps generated and static source assets (image and voice takes, portrait options, renders,
captures to keep): one folder outside git, set per computer, so big files can live on an external drive.

The root is, in order: the CM_ASSET_ROOT environment variable; the clone's git setting cm.assetRoot, written by
`make setup ASSET_ROOT=<folder>` (local to this clone and shared by all its worktrees, never committed); otherwise
.assets/ inside the checkout (git-ignored). The game itself never reads from here: picked, final art is copied into
art/ and committed through Git LFS.

  python3 tools/asset_root.py               prints the root
  python3 tools/asset_root.py --ensure      prints it and creates it if missing
  python3 tools/asset_root.py --set <dir>   stores it for this clone (what make setup runs)
"""
import os, subprocess, sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

def git(*args):
    r = subprocess.run(['git', '-C', str(REPO), *args], capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else ''

def asset_root() -> Path:
    for value in (os.environ.get('CM_ASSET_ROOT', '').strip(), git('config', '--get', 'cm.assetRoot')):
        if value: return Path(os.path.abspath(os.path.expanduser(value)))
    return REPO / '.assets'

def main(argv):
    if argv[:1] == ['--set'] and len(argv) == 2:
        target = Path(os.path.abspath(os.path.expanduser(argv[1])))
        target.mkdir(parents=True, exist_ok=True)
        subprocess.run(['git', '-C', str(REPO), 'config', 'cm.assetRoot', str(target)], check=True)
        print(target)
        return 0
    root = asset_root()
    if argv[:1] == ['--ensure']:
        try: root.mkdir(parents=True, exist_ok=True)
        except OSError as e:
            print(f'asset root {root} is not writable ({e.strerror}); is its drive mounted? '
                  'Run make setup ASSET_ROOT=<folder> or set CM_ASSET_ROOT.', file=sys.stderr)
            return 1
    elif argv:
        print(__doc__, file=sys.stderr); return 2
    print(root)
    return 0

if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
