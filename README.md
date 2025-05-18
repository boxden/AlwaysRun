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

## Contributing
Contributions are welcome! If you'd like to add new features, fix bugs, or improve translations, feel free to submit a pull request.

## License
This addon is provided as-is. Feel free to modify and distribute it, but please give credit to the original author.

## Credits
- **Author**: [Web_Artur](https://steamcommunity.com/profiles/76561198115550963) ([steamID64: 76561198115550963])
- **Last Updated**: 12 May 2025