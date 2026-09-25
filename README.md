# SpaceNotes Client

Flutter client for [SpaceNotes](https://github.com/mikaelwills/spacenotes) — a self-hosted notes, files and password system with real-time sync.

This is the client app for iOS, Android, macOS, Windows, Linux and web. It subscribes to your SpaceNotes server's SpacetimeDB for notes and talks to the server's file endpoints for anything bigger than a note.

For the server, sync daemon, MCP, Docker stack and setup, see the **[main SpaceNotes repo](https://github.com/mikaelwills/spacenotes)**.

![Desktop Notes View](assets/screenshots/desktop-notes.png)

<p align="center">
  <img src="assets/screenshots/mobile-notes.png" width="30%" alt="Mobile Notes View" />
</p>

## Features

**Notes**
- Real-time sync across devices, with an offline cache
- Recents page: Recently Viewed (tracked locally per device) and Recently Updated (what changed in the vault)
- Fuzzy search, folders, favourite folders, masonry grid of file cards
- Markdown editing, and generative-UI "dashboard" notes

**Files**
- Images, audio, video, PDFs and `.gpg` files alongside notes, with server-generated thumbnails
- On-demand downloads cached on the device, resumed with HTTP `Range` after an interruption, auto-reconnecting when a connection slows to a crawl, verified by size and SHA-256
- Resumable uploads: files over 8MB go up in 4MB chunks and continue after the app is backgrounded or killed
- Offload downloaded files to free space; multi-select to move or delete several files at once
- Audio player with a native parametric EQ, scrolling waveform, background/lock-screen playback and a persistent mini player

**Password manager**
- Reads and writes a `pass`-compatible `.password-store/` of GPG-encrypted entries
- Import your GPG private key per device to reveal passwords; create entries with a built-in generator
- Can be switched off per device in Settings

**Layouts**
- Mobile: nav bar for recents, folders and passwords
- Desktop: finder-style sidebar, tabbed notes with back navigation, drag and drop, Shift+Tab to cycle screens

The web build is notes-only: binary downloads, uploads and native audio need a native app.

## Building

```bash
flutter pub get
flutter run
```

The app depends on [`spacetimedb_sdk`](https://github.com/mikaelwills/spacetimedb-dart-sdk).

## License

GPL-3.0 — See the [main SpaceNotes repository](https://github.com/mikaelwills/spacenotes) for full license details.
