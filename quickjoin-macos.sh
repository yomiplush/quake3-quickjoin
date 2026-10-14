#!/bin/sh
# INARI_LOST_SHRINE — Quick join handler for Quake III Arena / Quake III Team Arena (macOS).
#
# Links on the site look like:
#   q3join://ioquake3/q3a/quake3a.inari-lost-shrine.net:18485     ioquake3, Q3 Arena
#   q3join://ioquake3/q3ta/quake3ta.inari-lost-shrine.net:7093    ioquake3, Team Arena
#   q3join://steam/q3a/quake3a.inari-lost-shrine.net:18485        Steam, Q3 Arena
#   q3join://steam/q3ta/quake3ta.inari-lost-shrine.net:7093       Steam, Team Arena
#
# macOS has no xdg-mime equivalent, so --install builds a tiny app bundle in
# ~/Applications whose Info.plist claims the q3join:// scheme, and asks
# LaunchServices to register it. The bundle contains this same script.
#
# Usage (no admin rights needed):
#   sh quickjoin-macos.sh --install      build and register the handler
#   sh quickjoin-macos.sh --uninstall    remove it again
#   sh quickjoin-macos.sh <url>          launched by the link, not normally by hand
set -eu

SCHEME="q3join"
CLIENTS="ioquake3 steam"
GAMES="q3a q3ta"
APP_NAME="QuickJoin"
APP="$HOME/Applications/$APP_NAME.app"
BUNDLE_ID="net.inari-lost-shrine.quickjoin"
STEAM_APP="2200"
SITE="https://www.inari-lost-shrine.net/gameserver"

LSREGISTER_PATHS="
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister
"

die() { printf 'quickjoin: %s\n' "$*" >&2; exit 1; }

notify() {
    if command -v osascript >/dev/null 2>&1; then
        osascript -e "display alert \"Quick join\" message \"$1\"" >/dev/null 2>&1 || true
    fi
    printf 'quickjoin: %s\n' "$*" >&2
}

in_list() {
    case " $2 " in *" $1 "*) return 0 ;; *) return 1 ;; esac
}

launch_game_client() {
    # open(1) resolves the app by name through LaunchServices and returns
    # non-zero when nothing matches.
    for app in ioquake3 ioq3; do
        if open -a "$app" --args "$@" 2>/dev/null; then
            return 0
        fi
    done
    notify "ioquake3 was not found. Install ioquake3, or use the Steam quick join button instead ($SITE)"
    exit 1
}

launch_steam_client() {
    if [ -x "/Applications/Steam.app/Contents/MacOS/steam_osx" ]; then
        exec "/Applications/Steam.app/Contents/MacOS/steam_osx" -applaunch "$STEAM_APP" "$@"
    fi
    if command -v steam >/dev/null 2>&1; then
        exec steam -applaunch "$STEAM_APP" "$@"
    fi
    notify "Steam was not found. Install Steam, or use the ioquake3 quick join button instead ($SITE)"
    exit 1
}

install_handler() {
    self=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
    mkdir -p "$APP/Contents/MacOS"
    install -m 0755 "$self" "$APP/Contents/MacOS/quickjoin"
    cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>quickjoin</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>$BUNDLE_ID</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>$SCHEME</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
EOF
    registered=no
    for lsr in $LSREGISTER_PATHS; do
        if [ -x "$lsr" ]; then
            "$lsr" -f "$APP" >/dev/null 2>&1 && registered=yes
            break
        fi
    done
    printf 'quickjoin: installed\n  app:        %s\n' "$APP"
    if [ "$registered" = yes ]; then
        printf '  registered: yes (LaunchServices)\n'
    else
        printf '  registered: lsregister not found — the bundle still works once LaunchServices\n'
        printf '              picks it up (log out and back in if the link does nothing).\n'
    fi
    if ! command -v osascript >/dev/null 2>&1; then
        printf '  note:       this does not look like macOS; only the bundle was written.\n'
    fi
}

uninstall_handler() {
    rm -rf "$APP"
    for lsr in $LSREGISTER_PATHS; do
        if [ -x "$lsr" ]; then
            "$lsr" -u "$APP" >/dev/null 2>&1 || true
            break
        fi
    done
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
            if open -a ioquake3 --args "$@" 2>/dev/null; then exit 0; fi
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
