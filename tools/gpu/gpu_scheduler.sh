#!/bin/zsh
# Keeps the GPU busy (Ashwin, 2026-10-31: "You shouldn't be wasting GPU hours when the GPU is available") and shares it among three
# kinds of work (the coordinator's order, 2026-11-02): VOICE first (missing lines block play), then IMAGES (portraits, title and world
# art, then cutscenes), then BLENDER (headless batches, at most BLENDER_MAX minutes a turn).
#
#   images and voice take turns as before: images first; when the image queue is empty and voice work waits, swap to voice; while voice runs,
#   swap back for waiting images after VOICE_MIN minutes (default 40), and give voice its turn after IMAGE_MAX minutes of images
#   (default 60); swap back to images when voice is empty (then run ~/.crooked-moon/gpu_deferred.sh once: held image work).
#   Blender (new): batches wait as scripts in ~/.crooked-moon/blender_queue/ (tools/gpu/blender_batch.sh). A Blender turn comes
#   (a) whenever both queues are empty, and (b) at a voice turn boundary (voice's slice ends or its queue empties) if the last Blender
#   turn was at least BLENDER_EVERY minutes ago (default 60), so voice and images are not starved. A turn never preempts a running
#   job: both queues are paused, each generator finishes its current job (a busy one is never stopped), the image generator is
#   restarted and the voice model unloaded to free the GPU, the batch runs, and the GPU goes back to the mode that was next.
#
# Swaps go through gpu_swap.sh (the same directory as this script's installed copy: ~/.crooked-moon) under ~/.crooked-moon/gpu.lock.
# Logs to ~/.crooked-moon/gpu_scheduler.log. Stop it by PID (gpu_scheduler.pid). `make gpu-scheduler-install` copies these files to
# ~/.crooked-moon; `make gpu-scheduler-restart` restarts the daemon in the mode the GPU is in; `tools/gpu/gpu_scheduler.sh --status`.
HOME_DIR=${CM_HOME:-$HOME/.crooked-moon}
VOICE_MIN=${VOICE_MIN:-40}
IMAGE_MAX=${IMAGE_MAX:-60}      # images get the GPU at most this long while voice waits, then voice gets VOICE_MIN
BLENDER_EVERY=${BLENDER_EVERY:-60}   # minutes between Blender turns taken at a voice boundary (an empty GPU needs no wait)
LOG=$HOME_DIR/gpu_scheduler.log
LOCK=$HOME_DIR/gpu.lock
PY=/opt/homebrew/bin/python3
CTL=($PY "$HOME/Applications/Daemon Monitor.app/Contents/Resources/control.py")
BATCH=${BLENDER_BATCH:-$HOME_DIR/blender_batch.sh}
img_pending() { curl -s -m 5 localhost:55302/v1/queue | $PY -c "import json,sys;d=json.load(sys.stdin);print(d['queued']+d['running'])" 2>/dev/null || echo -1; }
img_busy() { curl -s -m 2 localhost:5742/health | grep -q '"busy":true'; }
voice_pending() { curl -s -m 5 "localhost:55205/api/queue?limit=1" | $PY -c "import json,sys;print(json.load(sys.stdin)['total'])" 2>/dev/null || echo -1; }
voice_running() { curl -s -m 2 localhost:5743/api/queue | $PY -c "import json,sys;print(sum(1 for j in json.load(sys.stdin).get('data',[]) if j.get('status')=='running'))" 2>/dev/null || echo 0; }
blender_pending() { [[ -x $BATCH ]] && $BATCH --pending 2>/dev/null || echo 0; }
# Which generator has the GPU now (for a start with no START_MODE): the voice queue running means voice.
detect_mode() {
  $CTL status 2>/dev/null | $PY -c "
import json,sys
d={s['id']:s for s in json.load(sys.stdin)['services']}
v=d.get('voice',{})
print('voice' if v.get('running') and v.get('busy') or (v.get('running') and v.get('queue_paused') is False) else 'image')" 2>/dev/null || echo image
}
if [[ $1 == --status ]]; then
  echo "mode: $(detect_mode); images waiting: $(img_pending); voice waiting: $(voice_pending); Blender batches: $(blender_pending); lock: $(cat $LOCK/owner 2>/dev/null || echo free)"; exit 0
fi
lock() { until mkdir $LOCK 2>/dev/null; do sleep 10; done; echo "$1 $$" > $LOCK/owner; }
unlock() { rm -rf $LOCK; }
swap() {
  lock gpu_scheduler
  [[ -n $DRY ]] && echo "DRY swap $1" >> $LOG || $HOME_DIR/gpu_swap.sh $1 >> $LOG 2>&1
  unlock
  MODE=$1; SINCE=$(date +%s)
}
# A Blender turn, then the GPU goes to $1 (the mode that was next). Skips the turn, and goes straight to $1, if a generator is still
# busy after the wait (a running job is never stopped).
blender_turn() {
  local next=$1
  lock gpu_scheduler_blender
  echo "$(date -u +%H:%M:%S) Blender turn: $(blender_pending) batch(es) waiting; both queues paused, current jobs finish first" >> $LOG
  if [[ -n $DRY ]]; then echo "DRY blender turn then $next" >> $LOG; unlock; MODE=$next; SINCE=$(date +%s); LAST_BLENDER=$SINCE; return; fi
  curl -s -m 5 -X PATCH localhost:55302/v1/queue -H 'Content-Type: application/json' -d '{"paused":true}' >/dev/null
  curl -s -m 5 -X POST localhost:55205/api/queue/pause >/dev/null
  local i
  for i in {1..120}; do img_busy || break; sleep 3; done
  for i in {1..120}; do [[ $(voice_running) == 0 ]] && break; sleep 3; done
  if img_busy || [[ $(voice_running) != 0 ]]; then
    echo "$(date -u +%H:%M:%S) a generator is still busy after 6 min: no Blender turn" >> $LOG
    unlock; $HOME_DIR/gpu_swap.sh $next >> $LOG 2>&1; MODE=$next; SINCE=$(date +%s); return
  fi
  curl -s -m 30 -X POST localhost:5743/api/model/unload >/dev/null
  $CTL stop image >/dev/null 2>&1
  GPU_LOCK_HELD=1 $BATCH >> $LOG 2>&1
  unlock
  $HOME_DIR/gpu_swap.sh $next >> $LOG 2>&1
  MODE=$next; SINCE=$(date +%s); LAST_BLENDER=$SINCE
}
blender_due() { [[ $(blender_pending) -gt 0 && $(( $(date +%s) - LAST_BLENDER )) -ge $(( BLENDER_EVERY * 60 )) ]]; }
run_deferred() {
  if [[ -x $HOME_DIR/gpu_deferred.sh ]]; then echo "$(date -u +%H:%M:%S) running deferred image work" >> $LOG; $HOME_DIR/gpu_deferred.sh; mv $HOME_DIR/gpu_deferred.sh $HOME_DIR/gpu_deferred.done.sh; fi
}
MODE=${START_MODE:-$(detect_mode)}; SINCE=$(date +%s); LAST_BLENDER=0
echo $$ > $HOME_DIR/gpu_scheduler.pid
echo "start $(date -u +%H:%M:%S) mode $MODE (scheduler with Blender turns: at most ${BLENDER_MAX:-20} min each)" >> $LOG
[[ $1 == --once ]] && { echo "mode $MODE"; exit 0; }
while true; do
  i=$(img_pending); v=$(voice_pending); b=$(blender_pending); now=$(date +%s)
  if [[ $MODE == image ]]; then
    if [[ $i == 0 && $v == 0 && $b -gt 0 ]]; then echo "$(date -u +%H:%M:%S) both queues empty, $b Blender batch(es) waiting" >> $LOG; blender_turn image
    elif [[ $i == 0 && $v -gt 0 ]]; then echo "$(date -u +%H:%M:%S) images empty, $v voice waiting" >> $LOG; swap voice
    elif [[ $v -gt 0 && $(( now - SINCE )) -ge $(( IMAGE_MAX * 60 )) ]]; then echo "$(date -u +%H:%M:%S) images ran ${IMAGE_MAX} min, $i left, $v voice waiting" >> $LOG; swap voice; fi
  else
    if [[ $v == 0 ]]; then echo "$(date -u +%H:%M:%S) voice empty" >> $LOG
      if [[ $b -gt 0 ]] && { [[ $i == 0 ]] || blender_due; }; then blender_turn image; else swap image; fi
      run_deferred
    elif [[ $i -gt 0 && $(( now - SINCE )) -ge $(( VOICE_MIN * 60 )) ]]; then echo "$(date -u +%H:%M:%S) $i images waiting, $v voice left" >> $LOG
      if blender_due; then blender_turn image; else swap image; fi
    fi
  fi
  sleep 20
done
