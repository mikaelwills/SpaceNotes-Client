import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../generated/client.dart';
import 'notes_providers.dart';

/// Which lane the current screen actually depends on, so the connection
/// indicator reports the socket that screen's data arrives on rather than a
/// fixed one. Screens showing agent chat, contacts or calls read the chat
/// lane; everything else reads the notes lane.
enum ConnectionLane { notes, chat }

final activeConnectionLaneProvider =
    StateProvider<ConnectionLane>((ref) => ConnectionLane.notes);

ConnectionLane connectionLaneForLocation(String location) {
  const chatPrefixes = [
    '/notes/agents',
    '/notes/chat',
    '/notes/users',
    '/call',
    '/incoming-call',
  ];
  for (final prefix in chatPrefixes) {
    if (location == prefix || location.startsWith('$prefix/')) {
      return ConnectionLane.chat;
    }
  }
  return ConnectionLane.notes;
}

/// The client for whichever lane the current screen depends on.
final activeLaneClientProvider = Provider<SpacetimeDbClient?>((ref) {
  final lane = ref.watch(activeConnectionLaneProvider);
  return lane == ConnectionLane.chat
      ? ref.watch(chatClientProvider)
      : ref.watch(notesClientProvider);
});

final spacetimeConnectedProvider = Provider<bool>((ref) {
  final client = ref.watch(chatClientProvider);
  return client != null;
});

/// Live "is the socket actually connected" signal, driven by the SDK's
/// connection-state stream. Unlike [spacetimeConnectedProvider] (client
/// exists) this reflects the real transport state, so it goes false in a
/// tunnel / offline.
final spacetimeConnectionLiveProvider = StreamProvider<bool>((ref) {
  final client = ref.watch(chatClientProvider);
  if (client == null) return Stream.value(false);
  return client.connection.onStateChanged
      .map((s) => s.isConnected)
      .distinct();
});
