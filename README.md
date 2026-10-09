# BG3Tools

Shared tools for the BG3 mods [LootAdvisor](https://github.com/md12ol/LootAdvisor) and
[BuildAdvisor](https://github.com/md12ol/BuildAdvisor) (and a private play-testing mod). Check the repositories out
side by side in one folder (`<folder>/BG3Tools`, `<folder>/LootAdvisor`, `<folder>/BuildAdvisor`): the tools find
each mod as `../<project>/Mods/<Mod>`.

## Build and install
```bash
python tools/build_pak.py [Mod ...]     # packs <project>/Mods/<Mod> into dist/<Mod>.pak (Larian LSPK v18, no dependencies)
python tools/install_mods.py [--dry-run] # copies dist/*.pak into the game's Mods folder and enables them in modsettings.lsx
```
`build_pak.py` also copies the fresh pak of each public mod into that repo's install folder
(`LootAdvisor/LootAdvisor/LootAdvisor.pak`, `BuildAdvisor/BuildAdvisor/BuildAdvisor.pak`, list `RELEASE`), so the pak
players download always matches the source. `dist/` itself is not committed.

## Game driving (`tools/bg3drive/`)
Windows + Git Bash scripts that start, quit and drive the game for in-game tests (screen recognition, clicks, key
presses, save loading, camera, screen recording with game audio). Most of them talk to the play-testing mod through
files in the Script Extender folder. `loopcap.exe` (WASAPI loopback recorder used by `rec.sh`) is not committed; build
it from `loopcap.cs` with the .NET Framework compiler:
```
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /out:tools\bg3drive\loopcap.exe tools\bg3drive\loopcap.cs
```
