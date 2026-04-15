# Always Run Addon for Garry's Mod

The **Always Run** addon for Garry's Mod allows players to enable or disable a feature where their character always runs by default. This can be toggled on or off via a checkbox in the settings menu. The addon also remembers the player's preference between sessions.

## Features
- **Always Run Toggle**: Automatically run unless holding `ALT` or `SHIFT` to walk.
- **Settings Menu Integration**: Easily toggle the feature on or off via the `Utilities -> Server` menu.
- **Localization Support**: Supports multiple languages, including English, Russian, French, German, and more.
- **Persistent Settings**: Saves the player's preference to a file, ensuring it is remembered between sessions.

## Installation
1. Download the addon files.
2. Place the `AlwaysRun` folder into your `garrysmod/addons` directory.
3. Restart Garry's Mod.

## Usage
1. Open the spawn menu (`Q` by default).
2. Navigate to `Utilities -> Server`.
3. Find the `Always Run` section.
4. Toggle the checkbox to enable or disable the feature.
5. Your preference will be saved automatically.

## Key Bindings
- **ALT**: Temporarily walk while Always Run is enabled.
- **SHIFT**: Temporarily walk while Always Run is enabled.

## Localization

Supports 20+ languages, including:

English, Russian, French, German, Spanish, Chinese, Korean, Japanese, Polish, Portuguese, Turkish, Danish, Dutch, Norwegian, Finnish, Swedish, Czech, Hungarian, Italian, Ukrainian, Thai.

If your language is not supported or you notice an issue with a translation, feel free to contribute!

## File Structure
- `lua/autorun/client/always_run.lua`: Main logic for the addon.
- `lua/autorun/client/always_run_localization.lua`: Localization strings for supported languages.
- `data/always_run_settings.txt`: File where the player's preference is saved.

## How It Works (for beginners)
The addon is fully client-side and relies on Garry's Mod hooks:

1. **Startup and state loading**
   - On `Initialize`, `InitPostEntity`, and `PopulateToolMenu`, the addon loads saved settings from `data/always_run_settings.txt`.
   - It restores:
     - whether always-run is enabled,
     - selected toggle key,
     - mute-sound setting,
     - whether custom key mode is enabled.

2. **Movement control**
   - In the `CreateMove` hook, the addon modifies movement buttons each frame.
   - If always-run is active, it forces `IN_SPEED` (run) unless the user is holding `ALT` or `SHIFT`, which temporarily switches to walk.

3. **Toggle key handling**
   - In the `Think` hook, it listens for key press transitions (up -> down) for the configured toggle key.
   - When pressed, it toggles the state, writes settings to disk, and optionally plays UI sounds.

4. **Spawnmenu UI**
   - In `PopulateToolMenu`, it adds a panel under `Utilities -> Server`.
   - The panel includes:
     - master enable checkbox,
     - custom key enable checkbox,
     - key capture button,
     - mute sound checkbox,
     - GitHub button.

5. **Localization**
   - All visible UI text is loaded from `always_run_localization.lua` based on `gmod_language`.
   - Missing translation keys fall back to English phrases.

## Contributing
Contributions are welcome! If you'd like to add new features, fix bugs, or improve translations, feel free to submit a pull request.

### Local smoke checks
Before opening a PR, run:

```bash
./scripts/smoke.sh
```

This script verifies:
- no legacy global UI references (`_G.AlwaysRunMainCheckbox` / `_G.AlwaysRunKeyButton`);
- Lua syntax is valid for client scripts.

## Ideas for future improvements
- **Per-gamemode behavior**: allow separate profiles for Sandbox, DarkRP, etc.
- **Advanced key handling**: support modifier combos (e.g. `ALT + CAPSLOCK`) for toggling.
- **Optional HUD indicator**: show a small on-screen status icon when Always Run is active.
- **Config migration/versioning**: add a settings version field to safely evolve saved format.
- **More localization coverage**: fill newer phrases in all supported languages.
- **Automated release checks**: add luacheck/stylua jobs in CI in addition to smoke checks.

## License
This addon is provided as-is. Feel free to modify and distribute it, but please give credit to the original author.

## Credits
- **Author**: [Web_Artur](https://steamcommunity.com/profiles/76561198115550963)
- **Last Updated**: 12 May 2025
