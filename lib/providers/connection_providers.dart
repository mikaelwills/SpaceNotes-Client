import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notes_providers.dart';

final spacetimeConnectedProvider = Provider<bool>((ref) {
  final client = ref.watch(spacetimeClientProvider);
  return client != null;
});

/// Live "is the socket actually connected" signal, driven by the SDK's
/// connection-state stream. Unlike [spacetimeConnectedProvider] (client
/// exists) this reflects the real transport state, so it goes false in a
/// tunnel / offline.
final spacetimeConnectionLiveProvider = StreamProvider<bool>((ref) {
  final client = ref.watch(spacetimeClientProvider);
  if (client == null) return Stream.value(false);
  return client.connection.onStateChanged
      .map((s) => s.isConnected)
      .distinct();
});
