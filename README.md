<img src="Linger/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" width="128" alt="">

# Linger

Linger is a macOS menu bar app that keeps your Mac active while you're away from the
keyboard, so you keep showing as available, without stopping macOS from switching between
light and dark appearance.

## Why

Presence apps mark you as away when your Mac has seen no input for a few minutes. Mouse
jigglers fix that by faking input. But with Appearance set to Auto, macOS only switches
between Light and Dark while you're idle, so with a jiggler running the switch never
happens.

While you're away, Linger posts a mouse event that doesn't move the pointer, once a minute.
macOS treats you as idle after about 60 seconds without input, so its light/dark switch
still fits between two of Linger's events. If the switch still hasn't happened a little
after it was due, Linger steps aside (stops posting) for up to 15 minutes (configurable)
to make room for it.

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

- macOS 26 or later, on Apple silicon.
- To build: Xcode 27 or later, and [mise](https://mise.jdx.dev) for XcodeGen.

## Install

```sh
brew install --cask michaelrigart/tap/linger
```

If you built or copied Linger yourself, quit it and delete every copy first, including the
build in your checkout's `build/`, then run `tccutil reset All com.michaelrigart.linger`
(or remove Linger from the Accessibility list). Your own build is signed differently from
the Homebrew one: its old Accessibility entry stays in the list, looks switched on, and
stops macOS from asking again, and a copy left on disk can take the new grant instead.

Linger is signed with a free developer certificate and is not notarized, so macOS blocks
it the first time you open it. Once, after the first install, open System Settings →
Privacy & Security, find the message about Linger and click **Open Anyway**. Then click
**Allow…** in Linger's menu and switch Linger on in the Accessibility list that opens
(System Settings → Privacy & Security → Accessibility).

Upgrade with `brew upgrade --cask linger`. Releases are signed with the same certificate,
so an upgrade should need neither step again. If macOS asks anyway, repeat them.

## Build and install

To build it yourself, you need the full Xcode. If `xcode-select -p` points at the Command
Line Tools, prefix the `xcodebuild` and `swift` commands with
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

The project is set up to sign with the maintainer's certificate, which you won't have.
Add `CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=` to `xcodebuild` to sign ad hoc instead.

```sh
mise trust mise.toml
mise exec -- xcodegen generate
xcodebuild -project Linger.xcodeproj -scheme Linger -configuration Release -derivedDataPath build CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= -quiet build
rm -rf /Applications/Linger.app
ditto build/Build/Products/Release/Linger.app /Applications/Linger.app
open /Applications/Linger.app
```

Remove the old app first: `ditto` merges into an existing bundle and would keep stale
files. Quit Linger before you replace it, so that `open` starts the new build instead of
bringing the old one forward.

Then click **Allow…** in Linger's menu and switch Linger on in the Accessibility list
that opens (System Settings → Privacy & Security → Accessibility).

An ad hoc build is a different app to macOS every time you rebuild it, so you need to give
the Accessibility permission again, and the old build's entry stays in the list without
working. Run `tccutil reset All com.michaelrigart.linger` to clear it; then click **Allow…**
and switch Linger on again.

## Releasing

The maintainer cuts a release with `scripts/release`. It needs the signing certificate, so
it runs on the maintainer's Mac, not in CI. `CHANGELOG.md` lists what each release changed.

## Tests

```sh
swift test --package-path Packages/LingerCore
```

## Limitations

- If you start moving the mouse at the very moment Linger posts, the pointer can jump back
  to where it was, once.
- The dusk and dawn timing uses your time zone's reference location. In wide time zones,
  far from that location, it can be off by enough that Linger steps aside while macOS
  isn't ready to switch yet. You may then show as away for up to the step-aside limit for
  nothing; macOS still switches later, between Linger's events.
- macOS has no documented way to ask whether the screen is locked. Linger reads two
  undocumented signals and treats the screen as locked if either says so, and a future
  macOS release could change them.
- Linger can only reset the idle time that presence apps read. Whether an app shows you
  as available is up to that app.

## License

[MIT](LICENSE)
