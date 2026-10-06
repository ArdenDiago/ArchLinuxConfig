#!/bin/sh
# Apps started from the noctalia launcher inherit noctalia.service's cgroup and
# its MemoryHigh=2G leak cap, which makes them swap-thrash. Move them into their
# own scope, then restart noctalia: that drops the leak, and the old cgroup's
# lingering memory/swap charges get reparented to the uncapped app.slice.
set -u

# noctalia spawned straight from niri (no unit, so no cap to escape): the only
# memory to clear is noctalia's own leak, so just restart the daemon.
if ! systemctl --user -q is-active noctalia.service; then
    pkill -x noctalia
    while pgrep -x noctalia >/dev/null; do sleep 0.1; done
    exec noctalia --daemon
fi

cg=/sys/fs/cgroup$(systemctl --user show noctalia.service -p ControlGroup --value)/cgroup.procs

strays() {
    for p in $(cat "$cg" 2>/dev/null); do
        [ "$(cat "/proc/$p/comm" 2>/dev/null)" = noctalia ] || echo "$p"
    done
}

pids=$(strays)
if [ -n "$pids" ]; then
    # shellcheck disable=SC2086
    busctl --user call org.freedesktop.systemd1 /org/freedesktop/systemd1 \
        org.freedesktop.systemd1.Manager StartTransientUnit 'ssa(sv)a(sa(sv))' \
        "app-rescued-$(date +%s).scope" fail 2 \
        PIDs au "$(echo "$pids" | wc -w)" $pids \
        Slice s app.slice 0 >/dev/null || exit 1
    for _ in 1 2 3 4 5 6 7 8 9 10; do [ -z "$(strays)" ] && break; sleep 0.2; done
fi

# Restarting kills the whole cgroup, so never do it while apps are still inside.
if [ -n "$(strays)" ]; then
    notify-send -u critical "Free memory" "Could not move apps out of noctalia's cgroup; not restarting it."
    exit 1
fi
systemctl --user restart noctalia.service
