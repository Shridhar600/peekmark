# 🔍 PeekMark

<p align="center">
  <img src="Assets/favicon.svg" width="96" alt="PeekMark logo">
  <br>
  <b>A premium, native macOS Markdown reader and Finder Quick Look previewer.</b>
  <br><br>
  <img src="https://img.shields.io/badge/platform-macOS%2015.0%2B-blue" alt="macOS 15.0+">
  <img src="https://img.shields.io/badge/Swift-6.0-orange" alt="Swift 6.0">
  <img src="https://img.shields.io/badge/Xcode-16.0%2B-blue" alt="Xcode 16.0+">
  <img src="https://img.shields.io/badge/Sandbox-Enabled-green" alt="App Sandbox Enabled">
</p>

---

PeekMark is a high-performance, native macOS utility designed to bring a premium document-reading experience to Markdown files. Operating both as a standalone reader application and a system-wide Finder Quick Look extension, PeekMark bridges the gap between raw text and beautiful, print-grade document layouts.

It renders GitHub Flavored Markdown (GFM) with rich inline features (LaTeX math, interactive Mermaid.js diagrams, footnotes, code word-wrap, and secure copy overlays) while fully conforming to Apple's sandbox security guidelines.

---

## 📸 Screenshots & Visual Asset Slots

Please capture and place the following screenshots under `docs/screenshots/` to complete the documentation layout:

| 🖥️ Main Reader App (Dark Mode) | 📄 Finder Quick Look Extension (Light Mode) |
|:---:|:---:|
| ![Main App Dark Mode](docs/screenshots/main_app_dark.png)<br>*Rich markdown rendering with metadata HUD* | ![Quick Look Light Mode](docs/screenshots/quicklook_light.png)<br>*Instant preview by pressing Space in Finder* |

| ⚙️ Typography & Smooth Resizing | 💻 Code Action Overlays |
|:---:|:---:|
| ![Typography Controls](docs/screenshots/typography_popover.png)<br>*Adjust font face, size, and line spacing without losing your place* | ![Code Actions](docs/screenshots/code_actions.png)<br>*Word wrap toggles and copy-to-clipboard on hover* |

---

## ✨ Core Features

*   **Dual Entry Points**:
    *   **Finder Quick Look Extension**: Highlight any `.md` file in Finder and hit `Space` to see a fully rendered page instantly.
    *   **Standalone macOS App**: Drag-and-drop files or launch the main window to enjoy a distraction-free, dedicated reading layout.
*   **True System Theme Sync**: Automatically synchronizes and respects the system appearance (Light / Dark mode) across both the app and the Quick Look preview pane.
*   **Dynamic Typography Panel**: Custom-tailor your reading view by choosing font families (System, Monospaced, Serif, Rounded), font sizes, and line spacing.
*   **Resilient Viewport Sizing**: Font size adjustments use inline CSS custom properties. You can increase or decrease text sizes dynamically on a slider **without reloading the page or losing your current scroll position**.
*   **Interactive Code Overlays**: Every code block features custom action overlays on hover, including **Word Wrap Toggle** and a secure native **Copy to Clipboard** button.
*   **Automatic Heading Anchors**: Autogenerates slugified IDs on headings (`h1`–`h6`), allowing you to navigate internal table-of-contents links seamlessly within the document.
*   **Secure Document Sandbox**: Seamlessly reads files outside the application sandbox container using macOS security-scoped URL bookmarking.

---

## 🛠️ Markdown Support & Extensions

PeekMark renders standard CommonMark and all popular GitHub Flavored Markdown (GFM) extensions:

*   **GFM Task Lists**: Beautifully formatted task checkbox layouts aligned cleanly alongside descriptions (resolving standard double-bullet issues).
*   **GFM Footnotes**: Footnote references (`[^1]`) automatically render as superscript links that jump straight to a dedicated footnote container appended at the bottom of the page.
*   **LaTeX Math Typesetting**: Clean rendering of both inline (`$...$`) and block (`$$...$$`) math equations using KaTeX.
*   **Mermaid Diagrams**: Renders inline flowchart, sequence, and Gantt charts dynamically, matching text and line colors automatically to the light/dark themes.
*   **Safe HTML & Assets**: Sanitized rendering that permits local files (`file:///`) and data URIs, ensuring images and embedded assets load successfully without compromising security.

---

## ⚙️ Build, Installation & Uninstallation

PeekMark is configured via [XcodeGen](https://github.com/yonaskolb/XcodeGen) to allow project definition files (`project.yml`) to generate Xcode projects dynamically.

### 1. Generating the Project
Ensure you have XcodeGen installed (`brew install xcodegen`). Then, run:

```bash
xcodegen --project .
```

### 2. Building via command line
You can compile PeekMark directly from the terminal:

```bash
xcodebuild -project PeekMark.xcodeproj \
  -scheme PeekMark \
  -configuration Debug \
  -derivedDataPath .build/DerivedData \
  build
```
> [!NOTE]
> If you encounter compilation errors indicating deployment target mismatch (e.g. `LSMinimumSystemVersion` of `15.0` is less than `MACOSX_DEPLOYMENT_TARGET` of `26.0`), this is an Xcode compatibility override. The app continues to build and run successfully on macOS 15+.

### 3. Local Installation & Refresh
To copy the compiled `.app` to `/Applications` and register the Quick Look extension with macOS `launchd` and Finder:

```bash
./script/install.sh
```

If the Quick Look preview does not trigger immediately after installation:
1. Open **System Settings** ➔ **Extensions** ➔ **Quick Look** and check **PeekMarkQuickLookExtension**.
2. Alternatively, force a Finder restart:
   ```bash
   killall Finder
   ```
3. Or manually reset the macOS Quick Look daemon caches:
   ```bash
   qlmanage -r
   qlmanage -r cache
   ```

### 4. Running helper scripts
To build, run, and attach logs or LLDB directly:
```bash
# Run the application in the background
./script/build_and_run.sh run

# Verify compilation and that the app process launches successfully
./script/build_and_run.sh verify

# Watch log output filtering for PeekMark process logs
./script/build_and_run.sh logs

# Launch the binary inside the terminal LLDB debugger
./script/build_and_run.sh debug
```

### 5. Uninstallation
To cleanly wipe out all build directories, registered Launch Services database entries, and delete the app from `/Applications`:

```bash
./script/uninstall.sh
```

---

## 📚 External Libraries & Citations

PeekMark leverages open-source packages to maintain speed, lightness, and clean document layouts:

*   **[swift-markdown](https://github.com/swiftlang/swift-markdown)** (Apple): A Swift package for parsing and analyzing Markdown documents according to the CommonMark and GitHub Flavored Markdown specifications.
*   **[KaTeX](https://katex.org)** (Khan Academy): A fast math typesetting library for the web. Used to render LaTeX equations instantly inside the WKWebView without complex native rendering code.
*   **[Mermaid.js](https://mermaid.js.org)**: A JavaScript-based diagramming and charting tool that renders markdown-defined flowcharts, sequence diagrams, and Gantt charts dynamically.
*   **[Highlight.js](https://highlightjs.org)**: A syntax highlighter for code blocks with automatic language detection, supporting the app's dark/light themes.
