# quake3-quickjoin

One-click "quick join" links for the Quake III servers at
[INARI_LOST_SHRINE](https://www.inari-lost-shrine.net/gameserver).

The buttons on that page hand your browser a link such as

```
q3join://ioquake3/q3a/quake3a.inari-lost-shrine.net:18485
```

A browser cannot start a game by itself, so the link only does something after
the `q3join://` link type is registered for your user account on your machine.
That is all these two small scripts do. Nothing runs in the background.

## What the scripts do

| Step | Linux (`quickjoin.sh`) | Windows (`quickjoin.ps1`) |
|---|---|---|
| 1. Copy the handler | `~/.local/bin/inari-quickjoin` (`chmod 0755`) | — (runs from where you saved it) |
| 2. Register the link type | `~/.local/share/applications/inari-quickjoin.desktop` + `xdg-mime default` for `x-scheme-handler/q3join` | `HKCU\Software\Classes\q3join` |
| 3. On a link click | runs `ioquake3 +connect <address>` or `steam -applaunch 2200 +connect <address>` | same |

- No root / administrator rights: everything is inside your own user account.
- No files outside the paths above, no services, no scheduled tasks, no telemetry,
  no network requests of its own.
- Team Arena links add `+set fs_game missionpack` before connecting.

## Install

Linux:

```sh
sh quickjoin.sh --install
```

Windows (PowerShell, no admin needed):

```powershell
powershell -ExecutionPolicy Bypass -File .\quickjoin.ps1 -Install
```

Then click a *Quick join* button on the server page. Your browser asks once
whether to open the link — that prompt is normal, and no website can skip it.

## Uninstall

```sh
sh quickjoin.sh --uninstall
```

```powershell
powershell -ExecutionPolicy Bypass -File .\quickjoin.ps1 -Uninstall
```

## Link format

```
q3join://<client>/<game>/<host>:<port>
```

| Part | Values | Effect |
|---|---|---|
| `client` | `ioquake3` | launch `ioquake3` (also `ioquake3.x86_64`, `ioq3`, `quake3` if found) |
| | `steam` | launch the Steam copy, `steam -applaunch 2200` |
| `game` | `q3a` | Quake III Arena |
| | `q3ta` | Quake III Team Arena (`+set fs_game missionpack`) |

`q3join://<game>/<address>` without a client part is also accepted: ioquake3 if
it is installed, Steam otherwise. If the client you asked for is missing, the
handler says so instead of silently launching a different one.

## Security notes

- The URL is validated before use: only `q3join`, the two client names, the two
  game names, and an address made of `A-Za-z0-9.:-[]` with a mandatory port are
  accepted. Anything else is refused with a message.
- The game is started with an argument list, never through a shell, so a
  malicious link cannot become an arbitrary command. The worst a hostile
  `q3join://` link can do is start your game and point it at a server of the
  attacker's choosing — the same as clicking a server in any server browser.
- Both scripts are plain text; read them before running them. They are a few
  kilobytes and contain no obfuscation.

## Status

- Linux: tested (install, dispatch through `xdg-open`, uninstall, rejection of
  malformed links).
- Windows: written, **not yet tested on a real Windows machine**. The registry
  key is `HKCU\Software\Classes\q3join`; uninstall it if it misbehaves.
- macOS: not supported.
- ioquake3 additionally has its own `quake3://` protocol handler in builds
  configured with `PROTOCOL_HANDLER`; it only supports `connect`, so it cannot
  switch to Team Arena. That is why these links use their own `q3join://` type.
