import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/chat/chat_state.dart';
import 'notes_providers.dart';

final chatConnectedProvider = StreamProvider<bool>((ref) {
  final chatBloc = GetIt.I<ChatBloc>();

  Stream<bool> stateStream() async* {
    yield chatBloc.state is ChatReady &&
        (chatBloc.state as ChatReady).isConnected;
    await for (final state in chatBloc.stream) {
      if (state is ChatReady) {
        yield state.isConnected;
      }
    }
  }

  return stateStream().distinct().asBroadcastStream();
});

final spacetimeConnectedProvider = Provider<bool>((ref) {
  final client = ref.watch(spacetimeClientProvider);
  return client != null;
});

final isFullyConnectedProvider = Provider<bool>((ref) {
  final chat = ref.watch(chatConnectedProvider).valueOrNull ?? false;
  final spacetime = ref.watch(spacetimeConnectedProvider);
  return chat && spacetime;
});
