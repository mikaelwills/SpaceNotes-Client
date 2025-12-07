# SpaceNotes Client

A Flutter client for **SpaceNotes** - a real-time notes application powered by [SpacetimeDB](https://spacetimedb.com).

## Features

- **Real-time Sync**: Notes sync instantly across all connected devices via SpacetimeDB
- **Folder Organization**: Hierarchical folder structure for organizing notes
- **Markdown Support**: Write and render notes in Markdown
- **Cross-Platform**: iOS, Android, macOS, Windows, and Linux
- **AI Chat Integration**: Built-in OpenCode chat interface for AI assistance
- **Offline-First**: Local caching with automatic sync when reconnected

## Prerequisites

- **Flutter SDK**: 3.5.4+
- **SpacetimeDB Server**: Running instance with the SpaceNotes module
- **SpacetimeDB Dart SDK**: Local path dependency (see pubspec.yaml)

## Installation

```bash
git clone https://github.com/mikaelwills/SpaceNotes-Client.git
cd SpaceNotes-Client
flutter pub get
flutter run
```

## Configuration

Configure your SpacetimeDB server connection in the app settings:
- Server IP address
- Port (default: 3003)
- Database name: `spacenotes`

## Architecture

- **BLoC + Riverpod**: State management
- **SpacetimeDB**: Real-time database backend
- **Go Router**: Navigation

### Project Structure

```
lib/
├── blocs/           # BLoC state management
├── generated/       # SpacetimeDB generated bindings
├── models/          # Data models
├── providers/       # Riverpod providers
├── repositories/    # Data access layer
├── screens/         # UI screens
├── services/        # Network services
└── widgets/         # Reusable components
```

## Related Projects

- [SpaceNotes Module](https://github.com/mikaelwills/spacenotes) - SpacetimeDB Rust module
- [SpacetimeDB Dart SDK](https://github.com/clockworklabs/spacetimedb) - Dart client SDK

## License

MIT
