<img src="Linger/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" width="128" alt="">

# Linger

Linger is a macOS menu bar app that keeps you showing as available in presence apps such
as Microsoft Teams while you're away from the keyboard, without stopping macOS from
switching between light and dark appearance.

## Why

Presence apps mark you as away when your Mac has seen no input for a few minutes. Mouse
jigglers fix that by faking input. But with Appearance set to Auto, macOS only switches
between Light and Dark while you're idle, so with a jiggler running the switch never
happens.

While you're away, Linger posts a mouse event that doesn't move the pointer, once a minute.
macOS treats you as idle after about 60 seconds without input, so its light/dark switch
still fits between two of Linger's events. If the switch still hasn't happened a little
after it was due, Linger pauses for up to 15 minutes (configurable) to make room for it.

## Features

- Starts once you've been idle for 30 seconds to 3 minutes (1 minute by default), and
  stops as soon as you're back.
- Pause for 15 minutes, an hour, or until midnight.
- Never posts while the screen is locked or the Mac is asleep.
- Makes room for the light/dark switch at dusk and dawn. The timing comes from the sun's
  position, estimated from your time zone; Linger doesn't use Location Services.
- Launches at login (you can turn this off in Settings).
- Sandboxed, with no network access. The only permission it needs is Accessibility,
  which macOS requires before an app can post input events.

## Requirements

- macOS 26 or later.
- To build: Xcode 26 or later, and [mise](https://mise.jdx.dev) for XcodeGen.

## Build and install

There are no signed releases yet, so build it yourself. `xcodebuild` needs the full Xcode
selected, not the Command Line Tools (check with `xcode-select -p`).

```sh
mise exec -- xcodegen generate
xcodebuild -project Linger.xcodeproj -scheme Linger -configuration Release -derivedDataPath build -quiet build
ditto build/Build/Products/Release/Linger.app /Applications/Linger.app
open /Applications/Linger.app
```

Then click **Allow…** in Linger's menu and switch Linger on in the Accessibility list
that opens (System Settings → Privacy & Security → Accessibility).

Builds are signed ad hoc, so macOS treats each new build as a different app, and the old
build's entry stays in the list without working. After installing a new build, reset the
entry and grant access again:

```sh
tccutil reset All com.michaelrigart.linger
```

## Tests

```sh
swift test --package-path Packages/LingerCore
```

## Limitations

- macOS has no documented way to ask whether the screen is locked. Linger reads two
  undocumented signals and treats the screen as locked if either says so, and a future
  macOS release could change them.
- Linger can only reset the idle time that presence apps read. Whether an app shows you
  as available is up to that app.

## License

[MIT](LICENSE)
