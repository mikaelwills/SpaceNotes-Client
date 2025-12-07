import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../blocs/connection/connection_bloc.dart';
import '../blocs/connection/connection_state.dart' as conn;
import 'notes_providers.dart';

final connectionBlocProvider = Provider<ConnectionBloc>((ref) {
  throw UnimplementedError('connectionBlocProvider must be overridden');
});

final openCodeConnectionProvider = StreamProvider<bool>((ref) {
  final bloc = ref.watch(connectionBlocProvider);

  Stream<bool> stateStream() async* {
    yield bloc.state is conn.Connected;
    await for (final state in bloc.stream) {
      yield state is conn.Connected;
    }
  }

  return stateStream().distinct().asBroadcastStream();
});

final openCodeConnectionStateProvider = StreamProvider<conn.ConnectionState>((ref) {
  final bloc = ref.watch(connectionBlocProvider);

  Stream<conn.ConnectionState> stateStream() async* {
    yield bloc.state;
    await for (final state in bloc.stream) {
      yield state;
    }
  }

  return stateStream().asBroadcastStream();
});

final spacetimeConnectedProvider = Provider<bool>((ref) {
  final client = ref.watch(spacetimeClientProvider);
  return client.hasValue && client.valueOrNull != null;
});

final isFullyConnectedProvider = Provider<bool>((ref) {
  final openCode = ref.watch(openCodeConnectionProvider).valueOrNull ?? false;
  final spacetime = ref.watch(spacetimeConnectedProvider);
  return openCode && spacetime;
});
