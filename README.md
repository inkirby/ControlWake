# ControlWake

ControlWake is a tiny macOS utility that puts a stateful **Keep Awake** toggle
in Control Center. It prevents idle system sleep while still allowing the
display to sleep.

- No menu-bar icon
- No Dock icon
- No telemetry or network access
- No shelling out to `caffeinate`

## Requirements

- macOS 26 Tahoe or newer
- Xcode 26 or newer
- An Apple development team configured for both targets

## Development setup

1. Open `ControlWake.xcodeproj` in Xcode.
2. Select a development team for the `ControlWake` and
   `ControlWakeExtension` targets.
3. Ensure the App Groups capability contains
   `group.com.inkirby.ControlWake` for both targets.
4. Build and run the `ControlWake` scheme once.
5. Open Control Center, choose **Edit Controls**, and add **Keep Awake**.

The app registers itself as a login item while Keep Awake is enabled and
unregisters when it is disabled. macOS may require approval in **System
Settings → General → Login Items & Extensions**.

## Verification

After enabling the control, run:

```sh
pmset -g assertions
```

The output should include a `NoIdleSleepAssertion` named `ControlWake`.
Disable the control and confirm that assertion disappears.

## Privacy

ControlWake does not access the network and collects no user data. It stores
only the local enabled state in an App Group preference.

## License

MIT
