# quake3-quickjoin

One-click "quick join" links for the Quake III servers at
[INARI_LOST_SHRINE](https://www.inari-lost-shrine.net/gameserver).

The buttons on that page hand your browser a link such as

```
q3join://ioquake3/q3a/quake3a.inari-lost-shrine.net:18485
```

A browser cannot start a game by itself, so the link only does something after
the `q3join://` link type is registered for your user account on your machine.
That is all these three small scripts do. Nothing runs in the background.

## Install

Download with `curl`, read it if you like, then run it. No root / administrator
rights are needed on any platform.

**Linux**

```sh
curl -fsSLO https://raw.githubusercontent.com/yomiplush/quake3-quickjoin/main/quickjoin.sh
sh quickjoin.sh --install
```

**Windows** (PowerShell; `curl.exe` ships with Windows 10 and later)

```powershell
curl.exe -fsSLO https://raw.githubusercontent.com/yomiplush/quake3-quickjoin/main/quickjoin.ps1
powershell -ExecutionPolicy Bypass -File .\quickjoin.ps1 -Install
```

**macOS**

```sh
curl -fsSLO https://raw.githubusercontent.com/yomiplush/quake3-quickjoin/main/quickjoin-macos.sh
sh quickjoin-macos.sh --install
```

Then click a *Quick join* button on the server page. Your browser asks once
whether to open the link — that prompt is normal, and no website can skip it.

The same files are also downloadable from the site page itself, for browsers:
`/quickjoin/quickjoin.sh`, `/quickjoin/quickjoin.ps1`, `/quickjoin/quickjoin-macos.sh`.

## What the scripts write

| Platform | Script | Registers the link type with | Files / keys |
|---|---|---|---|
| Linux | `quickjoin.sh` | `xdg-mime default … x-scheme-handler/q3join` | `~/.local/bin/inari-quickjoin`, `~/.local/share/applications/inari-quickjoin.desktop` |
| Windows | `quickjoin.ps1` | `HKCU\Software\Classes\q3join` | registry only (the script stays where you saved it) |
| macOS | `quickjoin-macos.sh` | LaunchServices (`lsregister -f`) | `~/Applications/QuickJoin.app` (contains a copy of the script) |

On a link click the handler runs one of:

| Client | Command |
|---|---|
| ioquake3 | `ioquake3 +connect <address>` (Linux/Windows), `open -a ioquake3 --args +connect <address>` (macOS) |
| Steam | `steam -applaunch 2200 +connect <address>` (Linux/Windows), `Steam.app/Contents/MacOS/steam_osx -applaunch 2200 …` (macOS) |

Team Arena links add `+set fs_game missionpack` before connecting.

Nothing else is written: no services, no scheduled tasks, no shell startup
files, no telemetry, and no network requests of the handler's own.

## Uninstall

```sh
sh quickjoin.sh --uninstall
```

```powershell
powershell -ExecutionPolicy Bypass -File .\quickjoin.ps1 -Uninstall
```

```sh
sh quickjoin-macos.sh --uninstall
```

## Link format

```
q3join://<client>/<game>/<host>:<port>
```

| Part | Values | Effect |
|---|---|---|
| `client` | `ioquake3` | launch ioquake3 (also tries `ioquake3.x86_64`, `ioq3`, `quake3`) |
| | `steam` | launch the Steam copy, `-applaunch 2200` |
| `game` | `q3a` | Quake III Arena |
| | `q3ta` | Quake III Team Arena (`+set fs_game missionpack`) |

`q3join://<game>/<address>` without a client part is also accepted: ioquake3 if
it is installed, Steam otherwise. If the client you asked for is missing, the
handler says so instead of silently launching a different one.

## Security notes

- The URL is validated before use: only the `q3join` scheme, the two client
  names, the two game names, and an address made of `A-Za-z0-9.:-[]` with a
  mandatory port are accepted. Anything else is refused with a message.
- The game is started with an argument list, never through a shell, so a
  malicious link cannot become an arbitrary command. The worst a hostile
  `q3join://` link can do is start your game and point it at a server of the
  attacker's choosing — the same as clicking a server in any server browser.
- All three scripts are plain text; read them before running them. They are a
  few kilobytes each and contain no obfuscation.

## Status

| Platform | State |
|---|---|
| Linux | **Tested**: install, dispatch through `xdg-open`, uninstall, rejection of malformed links |
| Windows | Written, **not yet tested on Windows**. Registry key: `HKCU\Software\Classes\q3join` |
| macOS | Written, **not yet tested on macOS**. The bundle and `Info.plist` were verified (valid plist, correct `CFBundleURLSchemes`), but LaunchServices registration and Apple's URL hand-off need a real Mac |

ioquake3 additionally has its own `quake3://` protocol handler in builds
configured with `PROTOCOL_HANDLER`; it only supports `connect`, so it cannot
switch to Team Arena. That is why these links use their own `q3join://` type.
