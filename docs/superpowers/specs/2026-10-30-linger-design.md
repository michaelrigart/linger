# Linger — design

**Date:** 2026-10-30
**Owner:** Michael Rigart
**Status:** Implemented ([PR #1](https://github.com/michaelrigart/linger/pull/1))
**Revised:** 2026-10-31. The activity mechanism changed from
`IOPMAssertionDeclareUserActivity` to a zero-distance mouse event, which needs the
Accessibility permission. Michael decided this after the idle-timer measurements in
Evidence. Later the same day, Michael also accepted two undocumented signals for detecting a
locked screen (see Constraints).

## Why

Michael uses Jiggler (Stick Software) in Zen Jiggle mode so that Microsoft Teams keeps
showing them as Available when they step away from the keyboard.

Two problems:

1. **It breaks Auto appearance.** macOS (WindowServer) performs the scheduled light/dark
   switch only while the user is idle, and Jiggler makes sure the user never looks
   idle. Teams' away detection and the appearance switch read the same "is the user
   idle?" signal, so any tool that keeps Teams green blocks the switch unless it
   deliberately makes room for it. The evidence is below.
2. **It looks dated.**

Linger is a modern successor: set-and-forget, and it cooperates with Auto appearance
instead of blocking it.

## Evidence (measured on the owner's Mac, October 2026)

### Appearance switching

From WindowServer's log (`user_is_idle_for_appearance_switch`, `set_appearance_theme`)
and `pmset -g log`:

- **The check runs all the time.** WindowServer checks every ~60 s, all day, whether the
  user is idle, whether or not a switch is due. A "user is not idle (try again)" line
  does not mean a switch is pending.
- **An idle user plus a due switch means an immediate switch.** Every time the check
  passed while a switch was due, macOS switched within 0.1 s. This held for every
  switch in the logs.
- **"Idle" means about 60 s without input.** When the check finds the user active, it
  retries at the moment the idle time will reach about 60 s ("try again in 2.998").
  Linger's posts are at least 60 s apart, so the idle time reaches that mark between
  posts and the retry catches it. In acceptance, with Linger posting every 60–65 s, the
  Mac went Dark at a sun altitude of −2.8° and Light at −3.1°, before stepping aside was
  due either time. Stepping aside at −5° and −1° covers the case where the switch has not
  happened by then, for example when Michael only steps away after that point.
- **Jiggler blocks it.** On evenings when Jiggler kept running there was no automatic
  switch, and forcing one meant switching Appearance from Light back to Auto by hand.
- **When the switch is due.** macOS does not switch at sunrise or sunset. Using the
  Europe/Brussels reference coordinates (50.85 N, 4.35 E):
  - Light was not due at a sun altitude of −3.7° and was due by −2.0°,
    that is, roughly 10–20 minutes before sunrise.
  - Dark was not yet due at −1.6°, five minutes after sunset.

  Best estimate: macOS switches at a sun altitude near −3° on both sides. Michael's exact
  location is unknown, so this is accurate to a few minutes.

### Keeping Teams green

- **Teams reads `CGEventSourceSecondsSinceLastEventType`.** Both its main binary
  (`MSTeams`) and its embedded Edge engine call it. The binary doesn't show which event
  source state it passes.
- **How Jiggler does it.** Jiggler's binary imports `CGEventCreateMouseEvent`,
  `CGEventPost`, `UpdateSystemActivity`, `AXIsProcessTrusted` and
  `IOPMAssertionCreateWithName`. It also contains "Turn on accessibility" prompts. In
  other words, Zen Jiggle posts synthetic mouse events, which needs the Accessibility
  permission.
- **What resets which idle timer.** Measured 2026-10-31 with a probe run after 6 s of
  real idleness:

  | Method | `HIDIdleTime` / `.hidSystemState` | `.combinedSessionState` | Permission |
  |---|---|---|---|
  | `IOPMAssertionDeclareUserActivity` | not reset | not reset | none |
  | `UpdateSystemActivity` (deprecated) | reset | **not reset** | none |
  | `CGEventPost` of a null event (HID or session tap) | reset | **not reset** | Accessibility |
  | `CGEventPost` of a zero-distance `mouseMoved` | reset | reset | Accessibility |

  Only the mouse event resets every timer Teams could be reading, so Linger uses it.
  Unlike a null event, a mouse event carries a position.
  The probe ran unsandboxed, from a terminal that already had the permission. Sandboxed
  behaviour is feasibility check 1.

## Success

- Runs from login all week without attention.
- Teams stays Available while Michael is away from the keyboard, apart from the
  light/dark gap described below.
- With Appearance set to Auto, the Mac goes Dark in the evening and Light in the morning
  once Michael steps away, without touching System Settings.
- No noticeable CPU or battery cost while running.
- Built so it can ship on the Mac App Store later, under Michael's own name, without a
  rewrite.

## Goals (v1)

- Keep the user "active" for presence purposes while they are away from the keyboard.
- Step aside around dusk and dawn so macOS's own Auto appearance can switch.
- A clean, current-looking menu bar panel (design B below) and a small Settings window.
- Launch at login; remember state across restarts.

## Non-goals (v1)

- **Scheduling** (working hours, weekdays, holidays). Michael said they would most
  likely not use it; "Pause for today" covers ending the day. Keep the code shaped so it
  can be added before an App Store release.
- **Core Location.** v1 estimates coordinates from the system time zone. That is
  accurate to minutes in Belgium, but not in wide time zones, so it must be added before
  an App Store release.
- The App Store submission itself: listing, screenshots, review, formal name clearance.
- Per-app rules (for example, only while Teams runs) and any Teams or Microsoft Graph
  integration. Linger cannot see Teams' status and does not try to.
- Keeping the Mac awake with the lid closed, or battery-specific behaviour.
- Localisation. English only.

## Anti-goals

Linger has failed, even if it works, if it:

- moves the cursor, apart from the rare accepted race described under "Keeping the
  cursor still";
- posts anything other than a zero-distance `mouseMoved` event at the cursor's current
  position: no keyboard events, no clicks, no scrolls;
- needs any permission other than Accessibility, or uses the Accessibility API to read
  or control other apps;
- uses private API, or entitlements App Store review rejects (for example SkyLight
  appearance calls, or Apple Events to System Events to set dark mode);
- makes any network connection, or collects telemetry or analytics;
- shows a Dock icon, or opens windows nobody asked for;
- posts events while the screen is locked or the Mac is asleep, which could wake the
  display.

## Constraints

- **Platform.** Michael's Mac runs macOS Golden Gate (27). The deployment target is
  macOS 26, to reach more App Store users *(my call)*. The builder may raise it to 27 if
  a needed API exists only there, and must say so.
- **Stack.** Native Swift 6 and SwiftUI. A `MenuBarExtra` in `.window` style, and
  `LSUIElement` so there is no Dock icon *(my call)*.
- **App Store readiness from the first build.** App Sandbox and Hardened Runtime are on
  from day one, with no further entitlements in v1. Every system API used must be
  public and allowed in the sandbox. The one exception is screen-lock detection. macOS
  has no documented screen-lock API, so Linger reads the undocumented
  `CGSSessionScreenIsLocked` key from the public `CGSessionCopyCurrentDictionary()`. It
  also observes the `com.apple.screenIsLocked` and `com.apple.screenIsUnlocked`
  distributed notifications, and treats the screen as locked if either signal says so
  *(Michael's decision, 2026-10-31)*.
- **Identity.** Bundle identifier `com.michaelrigart.linger`. For local use it is signed
  with Michael's personal Apple development team if one is set up in Xcode, and
  ad-hoc otherwise. The Accessibility grant is tied to the code signature, so a stable
  signature matters. No code-signing identity was set up for v1, so
  ad-hoc builds need the grant renewed after every reinstall, until an Apple ID is added
  in Xcode for a free Personal Team development certificate.
- **Toolchain.** Xcode is installed at `/Applications/Xcode.app`, but `xcode-select`
  points at the Command Line Tools. Pass
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` per command. Don't change
  the global selection, which needs sudo and is Michael's call.
- **Tools** are never installed ad hoc. XcodeGen (`project.yml`) generates the Xcode
  project, so the project stays readable and reviewable as text. It is pinned in the
  repository's own `mise.toml`, the way provisioning repositories pin Ansible, so the
  dotfiles don't change *(my call; the builder may choose otherwise, with a reason)*.
- **Repository.** `~/Code/linger`. No remote yet; Michael decides where it goes.

## How it works

### Keeping you active

- Linger reads system idle time with
  `CGEventSourceSecondsSinceLastEventType(.combinedSessionState, any input event)` on a
  coarse timer with tolerance.
- When Linger is on and not paused, and idle time reaches the **idle delay** (default
  1 minute; choices 30 s, 1, 2, 3 min), it posts one zero-distance `mouseMoved` event at
  the cursor's current position with `CGEventPost`. It repeats about once a minute
  while the user stays away.
- **Keeping the cursor still.** A mouse event carries a position, so Linger re-reads
  the idle time and the cursor position immediately before every post. It skips the
  post if that re-read shows the user has come back, using the rule in the next
  bullet but one. That narrows the race, but it
  can't close it. If macOS pauses Linger between the read and the post while the user
  starts moving, the cursor snaps back to where it rested, and the user's first
  movement is undone once. No bound on the distance is claimed. **Michael accepted this
  residual race (2026-10-31)** and will judge in use whether it bothers them; Jiggler
  behaves the same way.
- **Teams' away timeout bounds the timings.** Teams marks a user Away after about
  5 minutes of inactivity. The idle delay, plus the polling interval and timer tolerance,
  must stay below that, which is why the longest idle delay is 3 minutes. The same bound
  applies to the gap between two events.
- **Real input versus Linger's own events.** Linger's events reset the idle timer it
  reads, so it records the monotonic time of its last post. The user has come back
  when the idle time is shorter than the time since Linger's last event, minus a
  0.25-second tolerance. Input in the first 0.25 s after one of Linger's events goes
  unnoticed. That blind interval is accepted *(my ruling)*. Its only effect is that
  Linger treats that moment as part of the same absence.
- Linger holds no power assertions. Stopping the events is all it takes to let the Mac
  go idle.
- Linger never posts while it is off, paused, stepping aside, the screen is locked, the
  Mac or display is asleep, or another user session is active. It resumes by itself on
  unlock or wake.

### Accessibility permission

- Linger checks `AXIsProcessTrusted()` at launch, on each poll tick and whenever the panel
  opens. It doesn't use `CGPreflightPostEventAccess()`, which caches its answer for the
  life of the process and so misses both a grant and a revocation while Linger runs.
- While access is missing:
  - The status line reads "Needs permission to keep you active".
  - The on/off switch is disabled.
  - An **Allow…** button calls `CGRequestPostEventAccess()` and, while access is still
    missing, opens the Accessibility pane in System Settings. macOS shows its own prompt
    only while it has no entry for the app. Once an entry exists, including one left by a
    build with a different signature, the request alone shows nothing.
  - The menu bar icon shows the off state.
- Linger notices a grant without being relaunched. It re-checks on each poll tick
  until access arrives. If access is revoked later, it returns to the missing state.

### Light/dark: stepping aside

- This applies only when light/dark handling is on (the default) **and** System Settings
  Appearance is Auto (`AppleInterfaceStyleSwitchesAutomatically` = 1 in the global
  domain). With a fixed Light or Dark appearance, Linger never steps aside.
- **Location:** coordinates come from the system time zone. Use a bundled
  zone-to-coordinates table copied from IANA `zone.tab`. macOS ships that file, not
  `zone1970.tab`, and it also lists aliases such as `Europe/Amsterdam`. Settings shows the
  source, for example "Estimated from time zone (Europe/Brussels)".
- Linger computes the sun's altitude on the device with a standard solar algorithm such
  as NOAA's. It makes no network calls.
- **A switch is due:**
  - in the evening once the sun is at or below **−5°** while the effective appearance is
    still Light;
  - in the morning once the sun is at or above **−1°** while it is still Dark.

  Both thresholds sit about 2° beyond macOS's observed ~−3°, which is roughly 10 minutes
  at this latitude. Linger therefore never steps aside before macOS is ready, and the
  location estimate has some room to be wrong *(my call; constants confirmed in
  feasibility check 3)*.
- While a switch is due and the user has been idle for at least the idle delay, Linger
  stops posting events. This is **stepping aside**, and the icon shows its half state.
  macOS then sees the user as idle and switches on its next check.
- Linger resumes as soon as one of these happens:
  - the effective appearance changes;
  - the user comes back;
  - the **gap budget** passes: default 15 minutes, set in Settings to 5, 10, 15 or
    30 minutes *(Michael's decision: 15 minutes, configurable)*.

  If the budget runs out, Linger doesn't try again during the same absence. It tries on
  the next one, until the switch happens or the next dusk or dawn takes over.
- If the user is at the keyboard when a switch becomes due, nothing happens until they
  step away. macOS behaves the same way without Linger.
- Teams may show Away during the gap. **Michael accepted this, up to the gap budget.**
- If the Mac locks during a gap (on Macs that lock from idleness), Linger stops as it always does while the screen is locked. Teams shows Away
  until the user returns.
- Sun altitude is recomputed on day change, wake, and time-zone or clock changes. If the
  sun never crosses a threshold that day (polar regions), Linger doesn't step aside.

### Menu bar panel (design B, chosen by Michael)

The mockup Michael chose is in `2026-10-30-linger-panel-mockup.html` next to this
document. Its visual direction is the reference: a compact, Control Center–style card.

```
┌──────────────────────────────────────┐
│ Keeping you active            [ ●━ ] │  ← big on/off switch
│ Since 08:12                          │
│                                      │
│ Pause for                            │
│ [ 15 min ] [ 1 hour ] [  Today  ]    │
│                                      │
│ 🌙 Dark mode around 17:40. I'll step │
│    aside for a moment once you're    │
│    away so macOS can switch.         │
│                                      │
│ Settings…                       Quit │
└──────────────────────────────────────┘
```

- **Status line** reads one of:
  - "Since 08:12"
  - "Paused until 15:30"
  - "Off"
  - "Stepping aside so macOS can switch to Dark"
  - "Needs permission to keep you active"
- While paused, a **Resume** button replaces the pause buttons. "Today" pauses until
  local midnight *(my call)*.
- **Light/dark row** shows the approximate time Linger will next step aside. It is
  hidden when handling is off. When Appearance isn't Auto, it shows a one-line hint
  pointing to System Settings instead.
- Copy never claims to know Teams' status. The mockup's "Teams stays Available" becomes
  neutral wording.
- **Icon:** a monochrome template image with three states: active (filled), off, paused
  or missing permission (outline), and stepping aside (half). The mockup glyph is a
  placeholder; the final artwork is the builder's call within this brief.

### Settings window

- **General:**
  - Launch at login (via `SMAppService`, on by default).
  - "Start after you've been idle for", with the idle-delay choices.
  - The Accessibility permission state, with the Allow… button.
- **Light/dark:**
  - the toggle "Step aside so macOS can switch light/dark" (on by default);
  - "Allow up to [15 min] away per switch" (the gap budget);
  - the current Appearance mode;
  - today's estimated step-aside times;
  - the location source.
- **About:** the version.
- The on/off state, pause end time, idle delay, light/dark toggle and gap budget
  persist in `UserDefaults`.

### First launch

Linger starts on and registers itself to launch at login. If Accessibility access is
missing, the panel shows the permission state and Linger waits until access is granted.
There is no other onboarding. Michael quits Jiggler and removes it from Login Items; Linger doesn't detect it.

### Logging

Linger writes state changes, posted events and step-aside decisions to the unified log
under the subsystem `com.michaelrigart.linger`. That gives acceptance testing something
to check. It logs no personal data.

## Verification

- Core logic is a pure Swift module with no AppKit dependency: the activity scheduler,
  the stepping-aside state machine, the sun calculator and the pause timers. The clock,
  idle source, appearance source, lock state, permission state and event poster are
  injected.
- Unit tests pin exact expected values:
  - Sun altitude and threshold-crossing times for Brussels (50.85 N, 4.35 E) on fixed
    dates match NOAA reference values to within 1 minute.
  - The state machine steps aside, resumes on an appearance change, the user's return or
    the end of the gap budget, and does not retry within the same absence.
  - No event is posted while off, paused, stepping aside, locked, asleep, in another
    session, or without permission.
  - Linger's own events are never mistaken for the user's return. Real input is
    detected, including input 0.5 s after one of Linger's events.
  - A post is skipped when the idle time re-read just before posting shows the user
    has come back.
- Manual acceptance on Michael's Mac:
  - Teams stays Available after 15 minutes away.
  - After dusk, stepping away switches the Mac to Dark, and after dawn to Light. Evidence
    comes from WindowServer's log:
    `/usr/bin/log show --start "<YYYY-MM-DD HH:MM:SS>" --style compact --predicate 'process == "WindowServer" AND (eventMessage CONTAINS "user_is_idle_for_appearance_switch" OR eventMessage CONTAINS "set_appearance_theme")'`.
    Use `/usr/bin/log`, because zsh has a `log` builtin. It must run outside the
    sandbox.
  - Linger's own log (`subsystem == "com.michaelrigart.linger"`) shows no posted events
    while the screen is locked, stepping aside, paused or off.
  - The cursor doesn't move when Linger posts while the mouse rests.

## Delivery

- **v1 deliverable:** Linger.app built locally, installed in `/Applications`, launching
  at login, replacing Jiggler.
- **The plan's first task is a feasibility check** in a sandboxed build, before any UI
  work:
  1. A sandboxed app can obtain post-event access with `CGRequestPostEventAccess`. Its
     zero-distance event then resets `.combinedSessionState` idle time, and Teams stays
     Available for at least 10 minutes away. A debug build with an artificial delay
     between reading the position and posting shows the worst case of the accepted
     race to Michael. Without the delay, posting once a second while the mouse rests
     shows no cursor movement.
  2. Idle time can be read from inside the sandbox, and real input can be told apart from
     Linger's own events.
  3. With Linger posting nothing, stepping aside lets macOS switch appearance. Record how
     long the user must be idle before it does, and confirm that the −5° and −1°
     thresholds come after macOS's own switch point.
- **Stop and bring it to Michael** if check 1 or 2 fails, or if macOS needs more idle
  time than 15 minutes (the default gap budget) to switch. Each of these changes what
  gets built.

## Left to the builder

Code structure, the polling interval and event cadence (within the bounds above), the
solar algorithm implementation, the time-zone coordinate table, the icon artwork, the
test framework (Swift Testing preferred), and the project generator if there's a good
reason to replace XcodeGen.

## Decisions

**Michael decided:**
- Keeping Teams Available is the purpose. Linger is always on.
- A short Away gap around each light/dark switch is acceptable, up to 15 minutes by
  default and configurable.
- Panel design B.
- Plan for the App Store from day one, shipping under their own name.
- No scheduling in v1.
- The name is Linger.
- Keep users active with a zero-distance mouse event, which needs the Accessibility
  permission (2026-10-31).
- Accept the rare cursor snap-back race that comes with it, and judge it in use
  (2026-10-31).
- Detect a locked screen with two undocumented signals (the `CGSSessionScreenIsLocked`
  session key and the `com.apple.screenIsLocked`/`screenIsUnlocked` notifications),
  because no documented API exists (2026-10-31).

**My calls** (Michael to confirm when reading):
- Deployment target macOS 26.
- `MenuBarExtra` with no Dock icon.
- XcodeGen, pinned in the repository's `mise.toml`.
- Accepting the 0.25 s blind interval.
- Time-zone location only in v1, with Core Location before the App Store.
- Thresholds of −5° in the evening and −1° in the morning.
- No retry within the same absence.
- "Today" pauses until midnight.
- Default idle delay of 1 minute, with choices capped at 3 minutes to stay under Teams'
  away timeout.
- Launch at login on by default.
- English only.
