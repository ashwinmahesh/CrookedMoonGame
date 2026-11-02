#!/bin/sh
# Stops the running GPU scheduler by its PID, puts gpu_scheduler.sh.new (make gpu-scheduler-install) in its place and starts it, in the mode the GPU is in now. It never kills by a pattern
# (other lanes' processes) and waits until the scheduler is not in the middle of a swap (the GPU lock is free).
HOME_DIR="$HOME/.crooked-moon"
PIDFILE="$HOME_DIR/gpu_scheduler.pid"
find_pids() { ps -axo pid,command | awk '$2 == "/bin/zsh" && $3 ~ /gpu_scheduler\.sh$/ {print $1}'; }
n=0
while [ -d "$HOME_DIR/gpu.lock" ] && [ $n -lt 60 ]; do sleep 5; n=$((n+1)); done
for p in $(find_pids); do kill "$p" 2>/dev/null && echo "stopped scheduler $p"; done
sleep 1
[ -f "$HOME_DIR/gpu_scheduler.sh.new" ] && { cp "$HOME_DIR/gpu_scheduler.sh" "$HOME_DIR/gpu_scheduler.sh.before_blender"; mv "$HOME_DIR/gpu_scheduler.sh.new" "$HOME_DIR/gpu_scheduler.sh"; }
cd "$HOME_DIR" && nohup ./gpu_scheduler.sh > /dev/null 2>&1 &
sleep 2
echo "started scheduler $(cat "$PIDFILE" 2>/dev/null)"
tail -2 "$HOME_DIR/gpu_scheduler.log"
