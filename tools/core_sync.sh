#!/usr/bin/env bash
# Puts the engine core (addons/dnd_core, a git submodule) at the commit this checkout names. git pull moves the pin but
# not the submodule's files, and the game then stops at parse errors for classes the newer core added.
# Only moves a core that is clean and behind the pin; one with work of its own is left alone, with a note.
core=addons/dnd_core
pin=$(git ls-tree HEAD "$core" | awk '{print $3}')
[ -n "$pin" ] || exit 0
have=$(git -C "$core" rev-parse HEAD 2>/dev/null)
[ "$have" = "$pin" ] && exit 0
if [ -n "$have" ]; then
  if [ -n "$(git -C "$core" status --porcelain --untracked-files=no)" ]; then
    echo "The engine core ($core) has uncommitted changes and isn't at the commit main names ($pin): left as it is." >&2
    exit 0
  fi
  git -C "$core" cat-file -e "$pin^{commit}" 2>/dev/null || git -C "$core" fetch --quiet origin || true
  if ! git -C "$core" merge-base --is-ancestor "$have" "$pin" 2>/dev/null; then
    echo "The engine core ($core) is at ${have:0:9}, which isn't behind the commit main names (${pin:0:9}): left as it is." >&2
    exit 0
  fi
fi
echo "Bringing the engine core up to the commit main names (${pin:0:9})."
git submodule update --init --quiet "$core"
