import 'package:equatable/equatable.dart';
import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart' as stdb;
import '../../models/spacetimedb_instance.dart';

abstract class SpacetimeDbConnectionState extends Equatable {
  const SpacetimeDbConnectionState();

  @override
  List<Object?> get props => [];
}

class SpacetimeDbConnectionLoading extends SpacetimeDbConnectionState {}

class SpacetimeDbConnectionLoaded extends SpacetimeDbConnectionState {
  final SpacetimeDbInstance? activeInstance;
  final stdb.ConnectionStatus connectionStatus;
  final stdb.ConnectionQuality? connectionQuality;

  const SpacetimeDbConnectionLoaded({
    required this.activeInstance,
    this.connectionStatus = stdb.ConnectionStatus.disconnected,
    this.connectionQuality,
  });

  @override
  List<Object?> get props => [activeInstance, connectionStatus, connectionQuality];

  SpacetimeDbConnectionLoaded copyWith({
    SpacetimeDbInstance? activeInstance,
    stdb.ConnectionStatus? connectionStatus,
    stdb.ConnectionQuality? connectionQuality,
  }) {
    return SpacetimeDbConnectionLoaded(
      activeInstance: activeInstance ?? this.activeInstance,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      connectionQuality: connectionQuality ?? this.connectionQuality,
    );
  }

  bool get hasActiveConnection =>
      activeInstance != null &&
      connectionStatus == stdb.ConnectionStatus.connected;

  bool get isConnected => connectionStatus == stdb.ConnectionStatus.connected;
  bool get isConnecting => connectionStatus == stdb.ConnectionStatus.connecting;
  bool get isReconnecting => connectionStatus == stdb.ConnectionStatus.reconnecting;
  bool get isDisconnected => connectionStatus == stdb.ConnectionStatus.disconnected;
  bool get isFatalError => connectionStatus == stdb.ConnectionStatus.fatalError;

  // Connection quality helpers
  double get healthScore => connectionQuality?.healthScore ?? 0.0;
  String get qualityDescription => connectionQuality?.qualityDescription ?? 'Unknown';
  int get reconnectAttempts => connectionQuality?.reconnectAttempts ?? 0;
  Duration? get averageLatency => connectionQuality?.averageLatency;
  String? get lastError => connectionQuality?.lastError;
}

class SpacetimeDbConnectionError extends SpacetimeDbConnectionState {
  final String message;

  const SpacetimeDbConnectionError(this.message);

  @override
  List<Object> get props => [message];
}
