# iPhone Simulator Launch Smoke

Date: 2026-04-10

Scope:

- confirm iOS simulator runtimes and devices exist on this machine
- confirm the current Swift app still builds for the simulator SDK
- confirm the built app can be installed and launched on a live iPhone simulator

Commands run:

```bash
xcrun simctl list runtimes
xcrun simctl list devices available
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -sdk iphonesimulator build
xcodebuild -project apple_app/task-manager/task-manager.xcodeproj -scheme task-manager -sdk iphonesimulator build-for-testing
xcrun simctl boot D015EDAE-E08D-4EA4-9178-80164B787D70
xcrun simctl bootstatus D015EDAE-E08D-4EA4-9178-80164B787D70 -b
xcrun simctl install D015EDAE-E08D-4EA4-9178-80164B787D70 ~/Library/Developer/Xcode/DerivedData/task-manager-fobpkxfsimvnjfgzfmyzdwkalkav/Build/Products/Debug-iphonesimulator/task-manager.app
xcrun simctl launch D015EDAE-E08D-4EA4-9178-80164B787D70 camp.task-manager
```

Observed results:

- `xcrun simctl list runtimes` returned `iOS 26.3 (26.3.1 - 23D8133)`
- `xcrun simctl list devices available` returned multiple available devices, including `iPhone 17`
- simulator SDK build passed
- simulator `build-for-testing` passed
- the app installed successfully onto `iPhone 17`
- the app launched successfully with bundle id `camp.task-manager`
- `simctl launch` returned process id `71725`

What this does confirm:

- the earlier "no simulator runtime installed" machine limitation is no longer true in this checkout environment
- the current app is launchable on a live iPhone simulator, not just buildable against the SDK

What this does not confirm:

- no manual tap-through of quick add, task editing, swipe actions, planner layout, or permission-state copy
- no manual narrow-width planner interaction pass
- no device-level validation beyond this simulator smoke
