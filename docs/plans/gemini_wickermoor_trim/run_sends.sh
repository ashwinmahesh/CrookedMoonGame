#!/bin/zsh
# Sends each brief once (no resends), in order; a reply already saved is skipped.
cd "$(dirname "$0")"
for f in sent_*.txt; do
  n=${f#sent_}; n=${n%.txt}
  [[ -f reply_$n.json ]] && continue
  /opt/homebrew/bin/python3 -I ~/.crooked-moon/bridge.py send ai-bridge-885bb429a2 $f gemini-4-argon-medium reply_$n.json
done
