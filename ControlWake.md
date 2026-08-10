# ControlWake

> A tiny macOS utility that adds a **stateful “Keep Awake” toggle to Control Center**, without occupying the menu bar or Dock.

Working name: **ControlWake**  
Trademark status: absolutely not™.

---

## Goal

Build a minimal macOS app that:

- Adds a **Keep Awake** toggle to macOS Control Center.
- Shows the toggle as **active while Keep Awake is enabled**.
- Prevents the Mac from entering idle system sleep.
- Does **not** require a menu-bar icon.
- Does **not** show a Dock icon.
- Uses native macOS APIs instead of shelling out to `caffeinate`.
- Remembers enabled state across app restarts and ideally across login/reboot.
- Is simple enough to publish as an open-source GitHub project.

The intended UX is:

```text
Control Center

┌────────────────────┐
│ ☕ Keep Awake      │
│        ON          │
└────────────────────┘
```

When highlighted, the Mac should remain awake even if the display sleeps.

---

# Product Philosophy

ControlWake should solve exactly one problem:

> Keep the Mac awake from a Control Center toggle without wasting menu-bar space.

Avoid turning the project into another Amphetamine-style full-featured utility.

For the initial versions, prioritize:

- simplicity
- reliability
- native macOS behavior
- very small UI footprint
- clear state
- minimal background resource usage

---

# Target Platform

Initial target:

- macOS 26 Tahoe or newer
- Swift
- SwiftUI
- WidgetKit
- AppIntents
- IOKit / macOS Power Management APIs

The project should use the native Control Center control APIs introduced through WidgetKit controls.

---

# Core Architecture

Proposed structure:

```text
ControlWake
├── Main macOS app
│   ├── manages sleep assertion
│   ├── owns persistent application state
│   └── runs invisibly when needed
│
├── Control Widget extension
│   ├── exposes Keep Awake in Control Center
│   ├── displays ON/OFF state
│   └── invokes App Intent when tapped
│
├── App Intent
│   └── handles requested state change
│
└── Shared state
    └── stores whether Keep Awake is enabled
```

Possible repository structure:

```text
ControlWake/
├── ControlWake/
│   ├── ControlWakeApp.swift
│   ├── SleepAssertionManager.swift
│   └── SharedState.swift
│
├── ControlWakeExtension/
│   ├── ControlWakeControl.swift
│   ├── ControlWakeValueProvider.swift
│   └── SetAwakeIntent.swift
│
├── Shared/
│   └── Constants.swift
│
├── README.md
├── LICENSE
└── ControlWake.xcodeproj
```

---

# Control Center Integration

Use a WidgetKit stateful control, likely:

```swift
ControlWidgetToggle
```

The control should conceptually behave like:

```text
Current state = OFF
        ↓
User taps toggle
        ↓
SetKeepAwakeIntent(enabled: true)
        ↓
Background app acquires sleep assertion
        ↓
Persist enabled = true
        ↓
Control reports state = true
        ↓
Control Center highlights toggle
```

And when disabling:

```text
Current state = ON
        ↓
User taps toggle
        ↓
SetKeepAwakeIntent(enabled: false)
        ↓
Release sleep assertion
        ↓
Persist enabled = false
        ↓
Control reports state = false
```

The Control Center item should represent **persistent desired state**, not simply behave like a momentary action button.

---

# Keep-Awake Implementation

Do not use:

```bash
caffeinate
```

as the main implementation.

Instead use native macOS IOKit power assertions.

Likely API:

```swift
IOPMAssertionCreateWithDescription(...)
```

or another appropriate IOPM assertion creation API.

Release using:

```swift
IOPMAssertionRelease(...)
```

Initial sleep behavior should correspond to:

```text
Prevent idle system sleep
Allow display sleep
```

Likely assertion type:

```swift
kIOPMAssertionTypeNoIdleSleep
```

Conceptual implementation:

```swift
final class SleepAssertionManager {

    private var assertionID: IOPMAssertionID = 0

    func enable() {
        // Create NoIdleSleep assertion
    }

    func disable() {
        // Release assertion
    }
}
```

The assertion should have a clear descriptive reason such as:

```text
ControlWake Keep Awake enabled by user
```

---

# Important Process-Lifetime Problem

A macOS power assertion normally belongs to the process that created it.

Therefore this design is probably invalid:

```text
Control Widget extension
        ↓
creates IOPM assertion
        ↓
extension finishes
        ↓
assertion disappears
```

The project needs to determine the correct architecture for maintaining the assertion while Keep Awake is enabled.

Likely solution:

```text
Control Center toggle
        ↓
App Intent
        ↓
Main/background application process
        ↓
IOPM sleep assertion
```

The host application should ideally be able to run as an invisible/background accessory application with:

```text
Dock icon       NO
Menu-bar icon   NO
Normal window   NO

Background app  YES
```

This is one of the first technical assumptions that must be validated during the prototype.

Do not blindly assume that an App Intent or Widget extension can hold the assertion indefinitely.

---

# Shared State

The Control Widget extension and host application need access to the same desired state.

Recommended approach:

```text
App Group
    +
UserDefaults(suiteName:)
```

Example:

```text
group.<bundle-id>.ControlWake
```

Stored state:

```text
keepAwakeEnabled: Bool
```

Example:

```swift
let defaults = UserDefaults(
    suiteName: "group.example.ControlWake"
)

defaults?.set(true, forKey: "keepAwakeEnabled")
```

The Control Widget value provider should read this state and report it to Control Center.

---

# Desired State vs Actual Assertion

Treat these as separate concepts.

## Desired state

```text
keepAwakeEnabled = true
```

means:

> The user wants ControlWake to keep the Mac awake.

## Actual state

The app process currently owns an active macOS power assertion.

Normally:

```text
desired = true
actual  = true
```

But failures are possible:

```text
desired = true
actual  = false
```

Examples:

- app crashed
- process was killed
- machine restarted
- assertion unexpectedly disappeared

When the app starts:

```text
if keepAwakeEnabled == true
    ensure assertion exists
```

This allows recovery without requiring the user to toggle ControlWake off and on again.

---

# Restart / Login Behavior

Desired behavior:

```text
ControlWake enabled
        ↓
Mac restarts
        ↓
User logs in
        ↓
ControlWake starts
        ↓
Reads keepAwakeEnabled = true
        ↓
Recreates sleep assertion
```

Research the cleanest macOS-native way to start the required background component at login.

Potential approaches should be evaluated before implementation.

Avoid unnecessarily complex helper daemons unless required.

---

# App Visibility

The application should ideally have no persistent visible UI.

Desired behavior:

```text
Menu bar icon: NO
Dock icon:     NO
Main window:   NO
```

Possible approaches include an accessory/background application configuration.

Research which method is appropriate for current macOS versions and App Store/notarization rules.

A tiny settings/about window may be added later if needed, but it should not be required for normal operation.

---

# MVP / v0.1

Implement only:

- [ ] ControlWake appears as an available Control Center control.
- [ ] User can add it to Control Center.
- [ ] Toggle has visible ON/OFF state.
- [ ] Tapping ON prevents idle system sleep.
- [ ] Tapping OFF restores normal sleep behavior.
- [ ] Display is still allowed to sleep.
- [ ] State is shared correctly between the control and host app.
- [ ] No menu-bar item.
- [ ] No Dock icon.
- [ ] Sleep assertion is restored if the app restarts while enabled.

Do NOT initially implement:

- timers
- schedules
- battery thresholds
- process-based triggers
- Wi-Fi triggers
- application triggers
- display-awake mode
- lid behavior modifications
- custom profiles
- command-line interface
- complicated settings
- Amphetamine feature parity

---

# Prototype Acceptance Tests

The first prototype should prove these things before polishing anything else.

## 1. Control exists

The ControlWake control appears in:

```text
Control Center
→ Edit Controls
```

and can be added.

## 2. Toggle state works

OFF:

```text
Control Center shows inactive state
```

ON:

```text
Control Center shows highlighted/active state
```

The state must survive Control Center closing and reopening.

## 3. Sleep assertion works

After enabling ControlWake:

```bash
pmset -g assertions
```

should show a relevant assertion belonging to ControlWake.

The Mac should not enter idle system sleep while that assertion exists.

## 4. Display sleep still works

The display should still be allowed to turn off normally.

ControlWake v0.1 should prevent **system idle sleep**, not force the screen to remain on.

## 5. Disable works

After toggling OFF:

```bash
pmset -g assertions
```

should no longer show the ControlWake assertion.

## 6. Process recovery

Test:

```text
ControlWake ON
↓
Terminate ControlWake process
↓
Restart ControlWake
```

Expected:

```text
Stored state = ON
↓
Assertion automatically recreated
```

## 7. Login/reboot recovery

If feasible for v0.1:

```text
ControlWake ON
↓
Restart Mac
↓
Login
↓
ControlWake restores assertion
↓
Control Center remains logically ON
```

---

# State Synchronization

Any state change should refresh the Control Widget.

Conceptually:

```text
State updated
      ↓
WidgetKit / Control Center reload
      ↓
Control value provider rereads state
```

Do not rely on Control Center keeping stale local state indefinitely.

Determine the correct WidgetKit API for notifying Control Center that the control value has changed.

---

# Failure Handling

The project should fail safely.

If creating the power assertion fails:

```text
do NOT leave UI permanently showing ON
```

Prefer:

```text
request ON
↓
assertion creation fails
↓
state returns to OFF
```

or another clearly documented recovery mechanism.

Logging should make assertion failures diagnosable.

---

# Logging

Keep logging minimal.

Useful events:

```text
ControlWake enabled
ControlWake disabled
Assertion created: <id>
Assertion released: <id>
Assertion creation failed
Restoring assertion from persisted state
```

Prefer unified logging / `Logger` rather than random `print()` calls in production.

---

# Security / Privacy

ControlWake should:

- require no network access
- collect no telemetry
- require no account
- send no analytics
- contain no third-party service integration
- store only local preference/state data

README should explicitly state:

> ControlWake does not access the network and collects no user data.

---

# Permissions

Determine whether macOS power assertions require any user permission.

Ideally:

```text
No Accessibility permission
No Screen Recording permission
No Full Disk Access
No administrator privilege
```

If additional entitlements or capabilities are required for Control Widgets/App Groups, document them clearly.

---

# Future Features

Only consider these after the core project is stable.

## Keep Display Awake

Possible second control or configurable mode:

```text
Keep System Awake
Keep Display Awake
```

Display-awake behavior would correspond conceptually to:

```bash
caffeinate -d
```

but should still use native APIs.

---

## Timed Sessions

Possible durations:

```text
30 min
1 hour
2 hours
Until disabled
```

Avoid making this part of the initial architecture unless necessary.

---

## Shortcuts / App Intents

Expose actions such as:

```text
Enable ControlWake
Disable ControlWake
Toggle ControlWake
```

This could allow:

- Shortcuts
- Siri
- automations
- scripting

The Control Center toggle should remain the primary UI.

---

## Automatic Conditions

Possible later ideas:

```text
Keep awake while:
- a specific application is running
- external display is connected
- charger is connected
- specific network is connected
```

These are explicitly out of scope for MVP.

---

# Distribution

Initial development:

```text
Build locally with Xcode
```

GitHub repository should contain full source.

Later distribution options:

## Source only

Users clone repository and build themselves.

Pros:

- simple for developer
- no signing distribution workflow

Cons:

- terrible UX for ordinary users

## GitHub Releases

Preferred long-term:

```text
ControlWake.app
or
ControlWake.dmg
```

Application should ideally be:

- Developer ID signed
- notarized by Apple

Desired install flow:

```text
Download
→ drag ControlWake into Applications
→ launch once if required
→ Control Center → Edit Controls
→ add ControlWake
```

---

# GitHub

Suggested repository:

```text
ControlWake
```

Suggested description:

> Keep your Mac awake from Control Center — without wasting menu-bar space.

Suggested license:

```text
MIT
```

Possible README header:

```markdown
# ControlWake

A tiny macOS utility that puts a stateful **Keep Awake** toggle directly in Control Center.

No menu-bar icon.  
No Dock icon.  
No telemetry.  
Just one toggle.
```

---

# Development Strategy

Do not build the whole application first.

Implement in this order:

```text
1. Create minimal macOS project
2. Add Control Widget extension
3. Make boolean ControlWidgetToggle work
4. Add shared App Group state
5. Add IOPM sleep assertion
6. Determine correct persistent-process architecture
7. Verify using pmset -g assertions
8. Remove Dock/menu-bar presence
9. Add state restoration
10. Test login/reboot behavior
11. Package / document
```

The most important technical spike is:

> Can the Control Widget/App Intent reliably communicate with an invisible host process that owns a persistent IOPM assertion?

Solve that before spending time on design or extra features.

---

# Definition of Done for v0.1

ControlWake v0.1 is complete when this works reliably:

```text
Open Control Center
↓
Tap ControlWake
↓
Button highlights
↓
Mac stays awake
↓
Display may still sleep
↓
Tap ControlWake again
↓
Button becomes inactive
↓
Normal idle sleep resumes
```

And throughout the whole process:

```text
Menu bar: clean
Dock:     clean
```

That is the entire point of ControlWake.