# MD Reader

A small, dark-themed macOS reader for Markdown files, with:

- **LaTeX**: `$…$`, `$$…$$`, `\(…\)`, `\[…\]` and ```` ```math ```` blocks (KaTeX)
- **Mermaid**: every diagram type; click a diagram to view it full-window, Esc to close
- **GFM tables**, task lists, footnotes, syntax-highlighted code with a Copy button
- **Outline sidebar** that tracks your position (⌃⌘S to show/hide)
- **Live reload**: the page updates when the file changes on disk and keeps your scroll position
- Relative images and links work; links to other `.md` files open in MD Reader

Everything is bundled, so it works offline.

## Shortcuts

| Key | Action |
| --- | --- |
| ⌘O | Open |
| ⌘F / ⌘G / ⇧⌘G | Find / next / previous |
| ⌘= / ⌘- / ⌘0 | Zoom in / out / reset (remembered) |
| ⌃⌘S | Outline sidebar |
| ⌘R | Reload |
| ⌘E | Open in the default editor |
| ⇧⌘R | Show in Finder |
| ⌘P | Print (uses a light, ink-friendly style) |

## Build

```bash
./build.sh              # builds and installs /Applications/MD Reader.app
./build.sh --no-install
```

Needs only the Command Line Tools (no Xcode). It is set as the default app for `.md`
(to set it again on another Mac:
Finder → select any .md → Get Info → Open with: MD Reader → Change All…).

⌘E opens the file in your editor; choose which one with
`defaults write com.binhphuong-ab.mdreader editorBundleID <bundle id>`.

## Layout of the code

- `Sources/MDReader/`: AppKit app (no SwiftUI). `MarkdownDocument` is a read-only
  NSDocument that polls the file for changes, `ViewerWindowController` owns the
  WKWebView, toolbar, find and zoom, and `SchemeHandler` serves `mdr://app/…` (the
  viewer) and `mdr://file/…` (local images) to the web view.
- `Web/`: `viewer.html/css/js` does the rendering with markdown-it + KaTeX +
  Mermaid + highlight.js. `Web/vendor/` holds pinned copies of those libraries;
  run `tools/vendor.sh` to upgrade them.
- `Examples/feature-test.md`: one file that exercises every feature.
