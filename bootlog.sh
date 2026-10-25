#!/system/bin/sh
# Persistent shutdown recorder.
#
# A soft reboot from userspace leaves nothing behind: /proc/last_kmsg only has
# content after a panic, so a restart that init or a daemon asked for is
# invisible from the next boot. This keeps the kernel log and the useful logcat
# buffers in /data, which survives the reset, so the last lines before a restart
# say what asked for it ("sys.powerctl", a watchdog, a fatal error, ...).
#
# Started by service.sh at boot. Keeps the newest few boots, caps each file and
# restarts the writers instead of truncating a file they still hold open.

DIR=/data/local/tmp/bootlog
KEEP=5
CAP=8000000      # bytes per boot file
CHECK=60         # seconds between size checks

mkdir -p "$DIR" || exit 0

# One instance only.
if [ -f "$DIR/pid" ]; then
    old=$(cat "$DIR/pid" 2>/dev/null)
    if [ -n "$old" ] && kill -0 "$old" 2>/dev/null; then
        exit 0
    fi
fi
echo $$ > "$DIR/pid"

ls -1t "$DIR"/boot-*.log 2>/dev/null | tail -n +$((KEEP + 1)) | while read -r f; do
    rm -f "$f"
done

F="$DIR/boot-$(date +%Y%m%d-%H%M%S).log"

{
    echo "== boot $(date '+%Y-%m-%d %H:%M:%S') =="
    echo "kernel         : $(uname -r)"
    echo "bootreason     : $(getprop ro.boot.bootreason)"
    echo "bootreason hist: $(getprop persist.sys.boot.reason.history | tr '\n' ' ')"
    echo
} > "$F"

pids=""

stop_writers() {
    for p in $pids; do
        kill "$p" 2>/dev/null
    done
    pids=""
    sleep 1
}

# WLAN and IPA print thousands of lines a minute and never explain a reboot.
start_writers() {
    dmesg -w 2>/dev/null \
        | grep -vE '\[(schedu|soft_i|cds_ol|binder)\]|wlan:|\[ipa|ipa-wan|rmnet' \
        | sed 's/^/k: /' >> "$F" &
    pids="$pids $!"
    logcat -b main -b system -b crash -b events -v threadtime 2>/dev/null >> "$F" &
    pids="$pids $!"
}

trap 'stop_writers; rm -f "$DIR/pid"; exit 0' INT TERM HUP

start_writers

while :; do
    sleep "$CHECK"
    if [ -f "$F" ] && [ "$(wc -c < "$F")" -gt "$CAP" ]; then
        stop_writers
        tail -c $((CAP / 2)) "$F" > "$DIR/.trim"
        mv "$DIR/.trim" "$F"
        start_writers
    fi
done
