import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart' as stdb;
import '../../models/spacetimedb_instance.dart';
import '../../repositories/spacetimedb_notes_repository.dart';
import 'spacetimedb_connection_state.dart';

class SpacetimeDbConnectionCubit extends Cubit<SpacetimeDbConnectionState> {
  static const String _activeInstanceIdKey = 'active_spacetimedb_instance_id';
  static const String _activeHostKey = 'active_spacetimedb_host';
  static const String _activeDatabaseKey = 'active_spacetimedb_database';
  static const String _activeAuthTokenKey = 'active_spacetimedb_auth_token';

  final SpacetimeDbNotesRepository _repository;
  StreamSubscription<stdb.ConnectionStatus>? _connectionStatusSubscription;
  StreamSubscription<stdb.ConnectionQuality>? _connectionQualitySubscription;

  SpacetimeDbConnectionCubit(this._repository)
      : super(const SpacetimeDbConnectionLoaded(
          activeInstance: null,
          connectionStatus: stdb.ConnectionStatus.disconnected,
        ));

  @override
  Future<void> close() {
    _connectionStatusSubscription?.cancel();
    _connectionQualitySubscription?.cancel();
    return super.close();
  }

  /// Load saved connection from SharedPreferences (optional - called on demand)
  Future<void> loadSavedConnection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final instanceId = prefs.getString(_activeInstanceIdKey);
      final host = prefs.getString(_activeHostKey);
      final database = prefs.getString(_activeDatabaseKey);
      final authToken = prefs.getString(_activeAuthTokenKey);

      if (instanceId != null && host != null && database != null) {
        // Create instance from saved data
        // Split host into ip:port
        final hostParts = host.split(':');
        final ip = hostParts[0];
        final port = hostParts.length > 1 ? hostParts[1] : '3000';

        final instance = SpacetimeDbInstance(
          id: instanceId,
          name: database, // Use database name as display name
          ip: ip,
          port: port,
          database: database,
          authToken: authToken,
        );

        final currentState = state;
        if (currentState is SpacetimeDbConnectionLoaded) {
          emit(currentState.copyWith(activeInstance: instance));
        }
      }
    } catch (e) {
      emit(SpacetimeDbConnectionError(
          'Failed to load saved connection: ${e.toString()}'));
    }
  }

  /// Connect to a SpacetimeDB instance
  Future<void> connectToInstance(SpacetimeDbInstance instance) async {
    try {
      print('SpacetimeDbConnectionCubit.connectToInstance() called');
      print('  instance: ${instance.name}');
      print('  host: ${instance.host}');
      print('  database: ${instance.database}');

      final currentState = state;
      if (currentState is! SpacetimeDbConnectionLoaded) {
        emit(const SpacetimeDbConnectionError(
            'Cannot connect when connection is not loaded'));
        return;
      }

      // Update state to connecting
      emit(currentState.copyWith(
        activeInstance: instance,
        connectionStatus: stdb.ConnectionStatus.connecting,
      ));

      // Update repository configuration
      print('  Updating repository configuration...');
      _repository.updateConfiguration(
        host: instance.host,
        database: instance.database,
        // authStorage will be created automatically by repository
      );

      // Connect via repository (this will be triggered by ReinitializeNotes event)
      // We don't connect here - the notes bloc will handle that
      print('  Configuration updated, waiting for notes bloc to connect...');

      // Subscribe to connection status and quality changes from repository's client
      _connectionStatusSubscription?.cancel();
      _connectionQualitySubscription?.cancel();
      _startMonitoringConnection();

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeInstanceIdKey, instance.id);
      await prefs.setString(_activeHostKey, instance.host);
      await prefs.setString(_activeDatabaseKey, instance.database);
      if (instance.authToken != null) {
        await prefs.setString(_activeAuthTokenKey, instance.authToken!);
      } else {
        await prefs.remove(_activeAuthTokenKey);
      }

      // Update last used timestamp
      final updatedInstance = instance.copyWith(lastUsed: DateTime.now());

      final latestState = state;
      if (latestState is SpacetimeDbConnectionLoaded) {
        emit(latestState.copyWith(
          activeInstance: updatedInstance,
          connectionStatus: stdb.ConnectionStatus.connecting,
        ));
      }

      print('  ✅ Connection configuration saved');
    } catch (e) {
      print('  ❌ Error in connectToInstance: $e');
      emit(SpacetimeDbConnectionError(
          'Failed to connect to instance: ${e.toString()}'));
    }
  }

  /// Disconnect from current instance
  Future<void> disconnect() async {
    try {
      print('SpacetimeDbConnectionCubit.disconnect() called');

      // Cancel connection monitoring subscriptions
      await _connectionStatusSubscription?.cancel();
      await _connectionQualitySubscription?.cancel();
      _connectionStatusSubscription = null;
      _connectionQualitySubscription = null;

      // Disconnect repository
      _repository.resetConnection();

      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activeInstanceIdKey);
      await prefs.remove(_activeHostKey);
      await prefs.remove(_activeDatabaseKey);
      await prefs.remove(_activeAuthTokenKey);

      emit(const SpacetimeDbConnectionLoaded(
        activeInstance: null,
        connectionStatus: stdb.ConnectionStatus.disconnected,
      ));

      print('  ✅ Disconnected successfully');
    } catch (e) {
      print('  ❌ Error disconnecting: $e');
      emit(SpacetimeDbConnectionError('Failed to disconnect: ${e.toString()}'));
    }
  }

  /// Update active instance details (when instance is modified)
  Future<void> updateActiveInstance(SpacetimeDbInstance instance) async {
    try {
      print('SpacetimeDbConnectionCubit.updateActiveInstance() called');

      final currentState = state;
      if (currentState is! SpacetimeDbConnectionLoaded) return;

      // Only update if this is the currently active instance
      if (currentState.activeInstance?.id != instance.id) return;

      // Update repository configuration
      _repository.updateConfiguration(
        host: instance.host,
        database: instance.database,
        // authStorage will be created automatically by repository
      );

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeHostKey, instance.host);
      await prefs.setString(_activeDatabaseKey, instance.database);
      if (instance.authToken != null) {
        await prefs.setString(_activeAuthTokenKey, instance.authToken!);
      } else {
        await prefs.remove(_activeAuthTokenKey);
      }

      emit(currentState.copyWith(activeInstance: instance));

      print('  ✅ Active instance updated');
    } catch (e) {
      print('  ❌ Error updating active instance: $e');
      emit(SpacetimeDbConnectionError(
          'Failed to update active instance: ${e.toString()}'));
    }
  }

  /// Check if given instance is currently active
  bool isInstanceActive(SpacetimeDbInstance instance) {
    final currentState = state;
    if (currentState is SpacetimeDbConnectionLoaded) {
      return currentState.activeInstance?.id == instance.id;
    }
    return false;
  }

  /// Get current host
  String get host {
    final currentState = state;
    if (currentState is SpacetimeDbConnectionLoaded) {
      return currentState.activeInstance?.host ?? '';
    }
    return '';
  }

  /// Get current database name
  String get database {
    final currentState = state;
    if (currentState is SpacetimeDbConnectionLoaded) {
      return currentState.activeInstance?.database ?? '';
    }
    return '';
  }

  /// Get current auth token
  String? get authToken {
    final currentState = state;
    if (currentState is SpacetimeDbConnectionLoaded) {
      return currentState.activeInstance?.authToken;
    }
    return null;
  }

  /// Get current active instance
  SpacetimeDbInstance? get activeInstance {
    final currentState = state;
    if (currentState is SpacetimeDbConnectionLoaded) {
      return currentState.activeInstance;
    }
    return null;
  }

  /// Check if there's an active connection
  bool get hasActiveConnection {
    final currentState = state;
    if (currentState is SpacetimeDbConnectionLoaded) {
      return currentState.hasActiveConnection;
    }
    return false;
  }

  /// Check if connected
  bool get isConnected {
    final currentState = state;
    if (currentState is SpacetimeDbConnectionLoaded) {
      return currentState.isConnected;
    }
    return false;
  }

  /// Get connection status
  stdb.ConnectionStatus get connectionStatus {
    final currentState = state;
    if (currentState is SpacetimeDbConnectionLoaded) {
      return currentState.connectionStatus;
    }
    return stdb.ConnectionStatus.disconnected;
  }

  /// Get the repository
  SpacetimeDbNotesRepository get repository => _repository;

  /// Start monitoring connection status and quality
  void _startMonitoringConnection() {
    final client = _repository.client;
    if (client == null) return;

    // Monitor connection status changes
    _connectionStatusSubscription = client.connection.connectionStatus.listen(
      (status) {
        final currentState = state;
        if (currentState is SpacetimeDbConnectionLoaded) {
          emit(currentState.copyWith(connectionStatus: status));
        }
      },
    );

    // Monitor connection quality metrics
    _connectionQualitySubscription = client.connection.connectionQuality.listen(
      (quality) {
        final currentState = state;
        if (currentState is SpacetimeDbConnectionLoaded) {
          emit(currentState.copyWith(connectionQuality: quality));
        }
      },
    );
  }
}
