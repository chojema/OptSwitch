# Chojema OptSwitch

A small macOS app switcher. Hold **Option** and press **Tab** to cycle through
running apps, then release Option to switch, much like Alt+Tab on Windows.

[한국어 안내](#한국어)

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

## Versioning

Versions follow [Semantic Versioning](https://semver.org). The version lives
in `VERSION`; the build number is the commit count. Pushing a tag `vX.Y.Z`
that matches `VERSION` builds and publishes a GitHub release.

## License

[MIT](LICENSE)

---

## 한국어

Option 키를 누른 채 Tab을 누르면 실행 중인 앱 사이를 이동하고, Option 키를
떼면 선택한 앱으로 전환합니다. Windows의 Alt+Tab과 같은 방식입니다.

- Option+Shift+Tab 또는 왼쪽, 오른쪽 화살표로 이동하고 Escape로 취소합니다.
- macOS 14 이상에서 동작합니다.
- 공증되지 않은 앱이므로 처음 실행할 때 **시스템 설정 > 개인정보 보호 및 보안**에서
  **그래도 열기**를 선택합니다.
- 키 입력을 감지하기 위해 **손쉬운 사용** 권한이 필요합니다. 키 입력을 기록하거나
  저장하거나 전송하지 않으며, 네트워크 연결도 하지 않습니다.
- 새 버전으로 업데이트한 뒤 동작하지 않으면 손쉬운 사용 목록에서 앱을 제거한 뒤
  다시 추가합니다.
