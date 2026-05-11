# PeekMark

<img src="Assets/favicon.svg" width="64" alt="PeekMark logo">

PeekMark is a lightweight native macOS Markdown preview app.

It has two entry points:

- Finder Quick Look: select a Markdown file and press Space.
- Standalone reader: open or drop a Markdown file into PeekMark.

## Build

Requirements:

- macOS 15+
- Xcode
- XcodeGen

```sh
xcodegen --project .
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project PeekMark.xcodeproj \
  -scheme PeekMark \
  -configuration Debug \
  -derivedDataPath .build/DerivedData \
  build
```

Or use the Codex Run action / local script:

```sh
./script/build_and_run.sh verify
```

## Install Locally

```sh
./script/install.sh
```

After install, select `sample.md` in Finder and press Space.

System-level install/reset actions made during development are tracked in `docs/system-changes.md`.

To remove the local install:

```sh
./script/uninstall.sh
```

To verify the installed app bundle and Quick Look extension:

```sh
./script/verify_install.sh
```

To create a local debug zip:

```sh
./script/package_release.sh
```

## Verify

```sh
./Tests/quicklook_metadata_check.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project PeekMark.xcodeproj \
  -scheme PeekMark \
  -configuration Debug \
  -derivedDataPath .build/DerivedData \
  test
```

Note: `xcodebuild test` can re-sign Debug artifacts with test-runner temporary entitlements. For installation, run a fresh `xcodebuild build` after tests and install that build product.
