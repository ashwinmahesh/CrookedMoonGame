#!/bin/zsh
# One Blender turn on the GPU (headless, never a window): runs the oldest batch script in the Blender queue folder
# (~/.crooked-moon/blender_queue/NN_name.py, oldest first by name) with `blender -b`, for at most BLENDER_MAX minutes
# (default 20), then moves it to blender_queue/done/ (finished) or blender_queue/failed/ (error or timed out) with its log.
# A batch script is an ordinary Blender Python script; it may read `--` arguments from sys.argv after "--" and should
# write its outputs itself (a .glb under the repo or the asset root). A script that needs longer than the turn should
# save its progress and be listed again (re-queue by copying it back with a higher number): batches are meant to be short.
#
# The scheduler (gpu_scheduler.sh) calls this with the GPU lock held and both generators idle. By hand:
#   tools/gpu/blender_batch.sh            runs the next batch (takes the lock itself when GPU_LOCK_HELD is not set)
#   tools/gpu/blender_batch.sh --list     lists the queue
#   tools/gpu/blender_batch.sh --pending  prints how many batches wait
# Environment: BLENDER (the executable), BLENDER_MAX (minutes), BLENDER_QUEUE (the folder), GPU_LOCK (the lock directory).
BLENDER=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
BLENDER_MAX=${BLENDER_MAX:-20}
Q=${BLENDER_QUEUE:-$HOME/.crooked-moon/blender_queue}
LOCK=${GPU_LOCK:-$HOME/.crooked-moon/gpu.lock}
LOG=${GPU_LOG:-$HOME/.crooked-moon/gpu_scheduler.log}
mkdir -p "$Q/done" "$Q/failed"
next() { ls "$Q"/*.py 2>/dev/null | sort | head -1; }
case "$1" in
  --pending) ls "$Q"/*.py 2>/dev/null | wc -l | tr -d ' '; exit 0;;
  --list) ls -1 "$Q"/*.py 2>/dev/null; exit 0;;
esac
script=$(next)
[[ -z $script ]] && { echo "no Blender batch waits"; exit 0; }
name=${script:t:r}
took_lock=0
if [[ -z $GPU_LOCK_HELD ]]; then
  mkdir "$LOCK" 2>/dev/null || { echo "GPU lock is held: $(cat $LOCK/owner 2>/dev/null)"; exit 75; }
  echo "blender_batch $$ $name $(date -u +%H:%MZ)" > "$LOCK/owner"; took_lock=1
fi
echo "$(date -u +%H:%M:%S) Blender batch $name starts (at most ${BLENDER_MAX} min)" >> $LOG
out="$Q/$name.log"
# macOS has no `timeout`: a watchdog kills Blender when the turn is over.
"$BLENDER" -b --factory-startup --python "$script" -- ${=BLENDER_ARGS} > "$out" 2>&1 &
pid=$!
( sleep $(( BLENDER_MAX * 60 )); kill $pid 2>/dev/null; sleep 5; kill -9 $pid 2>/dev/null ) &
dog=$!
wait $pid; rc=$?
kill $dog 2>/dev/null
if [[ $rc == 0 ]] && ! grep -q "Traceback (most recent call last)" "$out"; then dest=done; else dest=failed; fi
mv "$script" "$Q/$dest/"; mv "$out" "$Q/$dest/"
echo "$(date -u +%H:%M:%S) Blender batch $name ended ($dest, exit $rc)" >> $LOG
[[ $took_lock == 1 ]] && rm -rf "$LOCK"
exit 0
