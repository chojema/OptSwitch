# Chojema OptSwitch

A small macOS window switcher. Hold **Option** and press **Tab** to cycle
through open documents (windows), then release Option to switch, just like
Alt+Tab on Windows.

[한국어](README.md)

## Keys

| Keys | Action |
|---|---|
| Option+Tab | Open the switcher, move to the next window |
| Option+Shift+Tab | Move to the previous window |
| Left / Right arrow (while open) | Move backward or forward |
| Release Option | Switch to the selected window |
| Release Option on the first (current) window | Cancel |

Windows are listed in most recently used order, with each document of an app
shown separately. Apps without a window are listed at the end.

## Language

The app menu is shown in Korean by default. Choose **English** from the
**언어 (Language)** menu in the menu bar icon to switch to English.

## Requirements

macOS 14 or later, on Apple silicon or Intel.

## Install

1. Download `Chojema-OptSwitch-<version>.zip` from
   [Releases](../../releases) and unzip it.
2. Move `Chojema OptSwitch.app` to `/Applications`.
3. Open it. The app is not notarized, so macOS blocks the first launch.
   Go to **System Settings > Privacy & Security** and choose **Open Anyway**.
4. The app opens the permission settings together with a guide window.
   As the guide shows, click the **+** button below the list, choose
   **Chojema OptSwitch** in the Applications folder, and click **Open**.
   When the guide closes, switching works per window.

The permission list is in **System Settings > Privacy & Security**. From
macOS 27 it is called **System & App Protection Override**. After adding the
app, click **Override System Protections** at the bottom of the “Choose Apps
… to Control” window and confirm with your password or Touch ID. Up to
macOS 26 it is called **Accessibility**; turn on the switch after adding the
app.

Option+Tab works before you grant the permission, switching per app. If
switching is not per window after an update, select the app in the permission
list, remove it with the **−** button, and add it again. You can reopen the
guide from **Per-Window Switching Permission…** in the menu bar icon.

## Why is the permission needed?

On macOS, bringing a specific document window of another app to the front and
reading window titles requires this permission. The app does not record,
store, or send any keystrokes.

## Privacy

The app makes no network connections and collects no data.

## License

[MIT](LICENSE)
