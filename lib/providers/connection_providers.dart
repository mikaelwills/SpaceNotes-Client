import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notes_providers.dart';

final spacetimeConnectedProvider = Provider<bool>((ref) {
  final client = ref.watch(spacetimeClientProvider);
  return client != null;
});
