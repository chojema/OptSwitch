# Chojema OptSwitch

A small macOS app switcher. Hold **Option** and press **Tab** to cycle through
running apps, then release Option to switch, much like Alt+Tab on Windows.

[한국어](README.md)

## Keys

| Keys | Action |
|---|---|
| Option+Tab | Open the switcher, move to the next app |
| Option+Shift+Tab | Move to the previous app |
| Left / Right arrow (while open) | Move backward or forward |
| Escape (while open) | Cancel |
| Release Option | Switch to the selected app |

Apps are listed in most recently used order.

## Requirements

macOS 14 or later, on Apple silicon or Intel.

## Install

1. Download `Chojema-OptSwitch-<version>.zip` from
   [Releases](../../releases) and unzip it.
2. Move `Chojema OptSwitch.app` to `/Applications`.
3. Open it. The app is not notarized, so macOS blocks the first launch.
   Go to **System Settings > Privacy & Security** and choose **Open Anyway**.
4. Grant **Accessibility** permission when asked
   (**System Settings > Privacy & Security > Accessibility**).
   The switcher starts working within a few seconds.

After updating to a new version, macOS may ask for Accessibility permission
again. If the switcher stops responding, remove the app from the
Accessibility list and add it back.

## Why Accessibility permission?

The app needs to see keyboard events so it can catch Option+Tab before the
frontmost app does and notice when Option is released. It does not record,
store, or send any keystrokes.

## Privacy

The app makes no network connections and collects no data.

## Build from source

Requires the Xcode Command Line Tools.

```sh
scripts/test.sh        # run the ordering checks
scripts/build-app.sh   # build/Chojema OptSwitch.app and a release zip
```

## License

[MIT](LICENSE)
