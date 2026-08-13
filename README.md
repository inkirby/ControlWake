# ControlWake

ControlWake is a tiny macOS utility that puts a stateful **Keep Awake** toggle
in Control Center. It prevents the display from turning off due to inactivity,
which also prevents idle system sleep.

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

For subsequent command-line builds, run:

```sh
./build.sh
```

The script creates a signed Debug `.app` without installing or launching it,
and allows Xcode to update automatic signing profiles when needed. Set
`CONFIGURATION=Release` to create the Release app. As part of a normal macOS
app build, Xcode itself may register the build product with Launch Services;
the script does not invoke registration tools or manage the Control Widget.

To replace the installed app with the existing Release artifact, run:

```sh
./install.sh
```

The installer asks a running ControlWake instance to quit, verifies the app and
embedded extension, replaces `/Applications/ControlWake.app`, and leaves app
launch and Control Widget discovery to macOS. It does not invoke PluginKit or
Launch Services registration tools directly.

The app registers itself as a login item while Keep Awake is enabled and
unregisters when it is disabled. macOS may require approval in **System
Settings → General → Login Items & Extensions**.

## Verification

After enabling the control, run:

```sh
pmset -g assertions
```

The output should include a `PreventUserIdleDisplaySleep` assertion named
`ControlWake`.
Disable the control and confirm that assertion disappears.

## Privacy

ControlWake does not access the network and collects no user data. It stores
only the local enabled state in an App Group preference.

## License

MIT
