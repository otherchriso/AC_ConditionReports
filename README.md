# ConditionReports
Author: otherChrisO


## About this app

This app displays useful information about the current driving conditions. It uses three separate app windows:
### Time
- In-game date
- In-game time
- Time advancement multiplier in-game
- Your computer's local time
- Your computer's local time converted to UTC
- Session time remaining (if applicable)
### Weather
- CSP weather condition name
- Weather transition progress (if in transition)
- Next weather condition name (if scheduled)
- Air and track temperatures
- Wind speed and direction
- Wet weather details
### Grip
- Current track grip level as a percentage

It is inspired by Dave Esotic's "Esotic Local Time" app available at https://www.overtake.gg/downloads/esotic-local-time.13573/ which I've used for years while streaming league races with [Occasional Racing](https://occasional.racing/).

It replaces the functionality of that older Python-based app with a more modern and flexible Lua implementation, reliant on Custom Shaders Patch (CSP) for rendering.

It was vibe-coded quickly, so please accept my apologies for any rough edges!

## Installation and Updates

### Obtaining the app and updates

The app's canonical source is hosted on GitHub at otherchriso/AC-ConditionReports: https://github.com/otherchriso/AC-ConditionReports

It may also be published at overtake.gg but the GitHub repository will always have the latest version.

### Installation

Copy the `ConditionReports` folder into your Assetto Corsa `apps/lua/` directory. If you already have an older version of the app installed, it is recommended to delete the old `ConditionReports` folder first to avoid conflicts **but take care if you have modified any of the included language files, as those will be lost if you delete the folder. Back them up first if needed.**

Each release archive file should be compatible with Content Manager's auto-installer for drag-and-drop installation if you prefer.

### Language Support

The app supports multiple languages, selectable in the settings pane of any of the included apps. Changing the language in one of those settings pages will affect all of the included apps at the same time.

Language files are located in the app's `i18n/` subfolder. You can add or modify language files to customize the app's output. See the existing `.ini` files for examples of how to structure your translations.

If there's a problem with a translation file (e.g., missing or malformed), the app will fall back to built-in English defaults.

I don't speak all the languages provided, so if you find any mistakes or have suggestions for better translations, please feel free to contribute via GitHub.

## Usage

To use the app, launch Assetto Corsa with Custom Shaders Patch (CSP) enabled. Open the in-game apps menu and select any or all "ConditionReports" apps (Time, Weather, Grip). 
The app windows can be moved and resized like other CSP apps. Open the settings panel (via the cog icon in the title bar of the app) to customize which fields are displayed, formatting options, colors, fonts, and other preferences.

### Changing and using custom fonts

The app supports custom fonts installed for Assetto Corsa. To use a custom font, ensure it is installed in the game under the `steamapps\common\assettocorsa\content\fonts\` folder. Then, open the app's settings panel and select the desired font from the dropdown list. If you add new fonts while the game is running, click the "Rescan Fonts" button in the settings panel to refresh the list.

## Information layout

Each app window displays information in a two-column layout, with labels on the left and corresponding values on the right. Each field is displayed on its own row, but the settings also contain an option for each to be displayed "inline" with the previous item.

The order of fields can be customized in the settings panel by using the up and down arrow buttons next to each field name.

The name of the field can be suppressed if desired, leaving only the value displayed. Edit the appropriate language file to change the default labels (you may wish to copy a language file to work on your own edits; just remember to rename it appropriately with the "DisplayName" value in your ini file so you can find it in the list).

Each field can have independently-managed text colors for the label and value, as can the window background. Use the sliders in the settings panel to adjust window opacity.

A base text size can be set in the settings panel, and the app can automatically scale the text size based on the window width to maintain readability if preferred. The base "Size" slider then acts as the reference point for the min/max scale limits.

Note: Like most CSP apps and Content Manager itself, holding CTRL while clicking the value of the slider allows you to type in a precise value for fields like window background opacity and font size. You can use this to go beyond the slider limits if needed e.g. for really big text.