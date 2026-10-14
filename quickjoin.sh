#!/bin/sh
# INARI_LOST_SHRINE — Quick join handler for Quake III Arena / Quake III Team Arena.
#
# Links on the site look like:
#   q3join://ioquake3/q3a/quake3a.inari-lost-shrine.net:18485     ioquake3, Q3 Arena
#   q3join://ioquake3/q3ta/quake3ta.inari-lost-shrine.net:7093    ioquake3, Team Arena
#   q3join://steam/q3a/quake3a.inari-lost-shrine.net:18485        Steam copy (app 2200), Q3 Arena
#   q3join://steam/q3ta/quake3ta.inari-lost-shrine.net:7093       Steam copy (app 2200), Team Arena
#
# The client part picks the game binary, so vanilla (Steam) and ioquake3 are two
# separate buttons rather than one link that guesses. "q3join://<game>/<addr>"
# without a client is still accepted: ioquake3 if installed, Steam otherwise.
#
# Team Arena always gets "+set fs_game missionpack" first.
#
# Usage (no root needed):
#   sh quickjoin.sh --install      register the q3join:// handler for this user
#   sh quickjoin.sh --uninstall    remove it again
#   sh quickjoin.sh <url>          launched by the browser, not normally by hand
set -eu

SCHEME="q3join"
CLIENTS="ioquake3 steam"
GAMES="q3a q3ta"
BIN_CANDIDATES="ioquake3 ioquake3.x86_64 ioq3 quake3 quake3.x86_64"
STEAM_APP="2200"
SITE="https://www.inari-lost-shrine.net/gameserver"

APP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
MIMEAPPS="$CONFIG_HOME/mimeapps.list"
DESKTOP_ID="inari-quickjoin.desktop"
DESKTOP="$APP_DIR/$DESKTOP_ID"
HANDLER="$BIN_DIR/inari-quickjoin"

die() { printf 'quickjoin: %s\n' "$*" >&2; exit 1; }

notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Quick join" "$*" 2>/dev/null || true
    elif command -v kdialog >/dev/null 2>&1; then
        kdialog --error "$*" 2>/dev/null || true
    fi
    printf 'quickjoin: %s\n' "$*" >&2
}

in_list() {
    case " $2 " in *" $1 "*) return 0 ;; *) return 1 ;; esac
}

find_game() {
    for cand in $BIN_CANDIDATES; do
        if p=$(command -v "$cand" 2>/dev/null) && [ -n "$p" ]; then
            printf '%s\n' "$p"
            return 0
        fi
    done
    return 1
}

launch_game_client() {
    if bin=$(find_game); then
        exec "$bin" "$@"
    fi
    notify "ioquake3 was not found. Install ioquake3, or use the Steam quick join button instead ($SITE)"
    exit 1
}

launch_steam_client() {
    for cand in steam steam.exe; do
        if command -v "$cand" >/dev/null 2>&1; then
            exec "$cand" -applaunch "$STEAM_APP" "$@"
        fi
    done
    notify "Steam was not found. Install Steam, or use the ioquake3 quick join button instead ($SITE)"
    exit 1
}

install_handler() {
    self=$(readlink -f "$0") || die "cannot resolve own path"
    mkdir -p "$APP_DIR" "$BIN_DIR" "$CONFIG_HOME"
    install -m 0755 "$self" "$HANDLER"
    cat > "$DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Name=Quick join (INARI_LOST_SHRINE)
Comment=Launch Quake III Arena / Team Arena and connect to the INARI_LOST_SHRINE servers
Exec=$HANDLER %u
Terminal=false
NoDisplay=true
MimeType=x-scheme-handler/$SCHEME;
EOF
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true
    fi
    if command -v xdg-mime >/dev/null 2>&1; then
        xdg-mime default "$DESKTOP_ID" "x-scheme-handler/$SCHEME" || true
        if ! grep -qx "x-scheme-handler/$SCHEME=$DESKTOP_ID" "$MIMEAPPS" 2>/dev/null; then
            rm -f "$HANDLER" "$DESKTOP"
            die "could not register the handler in $MIMEAPPS (check xdg-utils and that \$HOME is writable); nothing was installed"
        fi
    else
        die "xdg-mime not found; install xdg-utils and re-run"
    fi
    printf 'quickjoin: installed\n  handler: %s\n  desktop: %s\n' "$HANDLER" "$DESKTOP"
    if game=$(find_game); then
        printf '  ioquake3: %s\n' "$game"
    else
        printf '  ioquake3: not found — the ioquake3 buttons will tell you, the Steam buttons still work\n'
    fi
    if command -v steam >/dev/null 2>&1; then
        printf '  steam:    %s\n' "$(command -v steam)"
    else
        printf '  steam:    not found — the Steam buttons will tell you\n'
    fi
}

uninstall_handler() {
    rm -f "$HANDLER" "$DESKTOP"
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true
    fi
    printf 'quickjoin: uninstalled\n'
}

open_url() {
    url=$1
    rest=${url#*:}
    rest=${rest#//}

    first=${rest%%/*}
    remainder=${rest#*/}
    [ "$remainder" != "$rest" ] || die "malformed link: $url"

    if in_list "$first" "$CLIENTS"; then
        client=$first
        game=${remainder%%/*}
        addr=${remainder#*/}
        [ "$addr" != "$remainder" ] || die "malformed link: $url"
    else
        client=auto
        game=$first
        addr=$remainder
    fi

    in_list "$game" "$GAMES" || die "unknown game in link: $game"
    case "$addr" in
        ""|*/*|*' '*) die "malformed address in link: $addr" ;;
        *:*) ;;
        *) die "missing port in link: $addr" ;;
    esac

    if [ "$game" = "q3ta" ]; then
        set -- +set fs_game missionpack +connect "$addr"
    else
        set -- +connect "$addr"
    fi

    case "$client" in
        ioquake3) launch_game_client "$@" ;;
        steam)    launch_steam_client "$@" ;;
        auto)
            if bin=$(find_game); then exec "$bin" "$@"; fi
            launch_steam_client "$@"
            ;;
    esac
}

case "${1:-}" in
    --install)   install_handler ;;
    --uninstall) uninstall_handler ;;
    -h|--help|"") sed -n '2,/^set -eu$/p' "$0" | sed 's/^# \{0,1\}//' ;;
    *)           open_url "$1" ;;
esac
