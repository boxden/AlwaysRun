# Always Run Addon for Garry's Mod

The **Always Run** addon for Garry's Mod lets players keep running by default on the client, while still being able to temporarily stop auto-run with their normal movement modifier keys. The addon also remembers preferences between sessions and across gamemodes.

## Features
- **Always Run Toggle**: Automatically holds run unless the player is holding their current `+speed` or `+walk` bind.
- **Settings Menu Integration**: Available in `Utilities -> User`.
- **Custom Toggle Key**: Supports an optional custom key for enabling or disabling auto-run.
- **Protected Keys Option**: The GUI can block assigned or sensitive keys by default, with an option to disable that protection.
- **Console Commands**: Supports direct console control for toggling and assigning the custom key.
- **Localized UI**: Includes translations for 20+ languages.
- **Persistent Profiles**: Saves per-gamemode preferences to a client data file.

## Installation
1. Download the addon files.
2. Place the `AlwaysRun` folder into your `garrysmod/addons` directory.
3. Restart Garry's Mod.

## Usage
1. Open the spawn menu (`Q` by default).
2. Navigate to `Utilities -> User`.
3. Find the `Always Run` section.
4. Toggle the checkbox to enable or disable the feature.
5. Optional: enable a custom toggle key and choose a key.
6. Optional: disable `Protected keys` if you want the GUI to allow assigned or sensitive keys.
7. Your preferences will be saved automatically.

## Key Bindings
- **Your `+speed` bind**: Temporarily stops auto-run while held.
- **Your `+walk` bind**: Also temporarily stops auto-run while held.
- **Custom toggle key**: Optional key for turning auto-run on or off.
- **Protected keys**: By default, the GUI blocks keys that are already assigned or marked as protected.
- **ESC during key capture**: Cancels custom key assignment.

## Console Commands
- `web_always_run_toggle`: Toggles auto-run directly.
- `web_always_run_set_toggle_key <key>`: Assigns the custom toggle key by key name or key code and enables custom key mode.
- The console assignment command bypasses GUI protected-key restrictions.
- Example: `web_always_run_set_toggle_key SHIFT`
- Example: `web_always_run_set_toggle_key 79`

## Localization

Supports 20+ languages, including:

English, Russian, French, German, Spanish, Chinese, Korean, Japanese, Polish, Portuguese, Turkish, Danish, Dutch, Norwegian, Finnish, Swedish, Czech, Hungarian, Italian, Ukrainian, Thai.

If your language is not supported or you notice an issue with a translation, feel free to contribute!

## File Structure
- `lua/autorun/client/always_run.lua`: Main logic for the addon.
- `lua/autorun/client/always_run_localization.lua`: Localization strings for supported languages.
- `data/web_always_run_settings.txt`: File where the player's client preferences are saved.

## How It Works (for beginners)
The addon is fully client-side and relies on Garry's Mod hooks:

1. **Startup and state loading**
   - On `Initialize`, `InitPostEntity`, and `PopulateToolMenu`, the addon loads saved settings from `data/web_always_run_settings.txt`.
   - It restores:
     - whether always-run is enabled,
     - selected toggle key,
     - mute-sound setting,
     - whether custom key mode is enabled,
     - whether protected keys are enabled,
     - the current gamemode profile.

2. **Movement control**
   - In the `CreateMove` hook, the addon modifies movement buttons each frame.
   - If always-run is active, it forces `IN_SPEED` unless the player is holding a key bound to `+speed` or `+walk`.

3. **Toggle key handling**
   - In the `Think` hook, it listens for key press transitions (up -> down) for the configured toggle key.
   - When pressed, it toggles the state, writes settings to disk, and optionally plays UI sounds.
   - During key capture, pressing `ESC` cancels the assignment.
   - The GUI can optionally block protected or already-assigned keys while selecting a custom toggle key.
   - The addon also exposes console commands for toggling and assigning the custom key without the menu.

4. **Spawnmenu UI**
   - In `PopulateToolMenu`, it adds a panel under `Utilities -> User`.
   - The panel includes:
     - master enable checkbox,
     - dynamic description based on the player's current `+speed` and `+walk` binds,
     - custom key enable checkbox,
     - protected keys checkbox,
     - key capture button,
     - mute sound checkbox,
     - GitHub button.

5. **Localization**
   - All visible UI text is loaded from `always_run_localization.lua` based on `gmod_language`.
   - Missing translation keys fall back to English phrases.
   - The movement description inserts the player's current `+speed` and `+walk` keys dynamically.

## Contributing
Contributions are welcome! If you'd like to add new features, fix bugs, or improve translations, feel free to submit a pull request.

## License
This addon is provided as-is. Feel free to modify and distribute it, but please give credit to the original author.

## Credits
- **Author**: [Web_Artur](https://steamcommunity.com/profiles/76561198115550963)
- **Last Updated**: 26 April 2026
