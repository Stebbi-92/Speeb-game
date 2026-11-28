# Saves and Updates

## Saves

Each world of the Ashen Waste has its own save. On the title screen, **The Ashen Waste** lists them:

- **Walk** continues a world.
- **Export** packs the world and your characters for it into a zip in `Documents/Brelm`, to keep or share.
- **Delete** removes it, after asking.
- **Open the saves folder** shows where the saves are kept.

**Continue** at the top of the title screen opens the world you played last.

## Loading

The waste loads in steps. A bar shows how far it has got, with hints that change every few seconds.

## Updates

The game checks for a new version when it starts, downloads it, and restarts into it. Saves are kept. When you join a friend, the game checks you both have the same version.

An update fetches only what changed. The game's data comes in parts (the code, arms, foes, the world's models, textures and sound), so an update that only changes code is about 15 MB instead of the whole 550 MB. The first such update still fetches every part once, unless you install that version fresh.

When a version brings a new engine or a new file beside the game, the game fetches the whole new version and puts it in place itself after it closes (on Windows and Linux). On macOS, it points you to the download.

**Check game files** (Settings, Game) reads the parts an update brought and fetches again any that are damaged. If anything goes wrong, download the latest zip from the [Releases page](https://github.com/Stebbi-92/Speeb-game/releases) and unpack it over the old one.

## Error reports

If Brelm hit an error last time, or closed without you quitting, the title asks once whether to send a short report. A report holds only the error lines and the game version (and the system's name, such as Windows). Nothing else is sent, and file paths have your user name taken out. The reports go to game.speeb.org, which keeps no addresses.

In Settings, **Error reports to the game's makers** can be set to Ask me (the default), Always send, or Never send.

