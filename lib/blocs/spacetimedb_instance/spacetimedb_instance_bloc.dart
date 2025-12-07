import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../models/spacetimedb_instance.dart';
import 'spacetimedb_instance_event.dart';
import 'spacetimedb_instance_state.dart';

class SpacetimeDbInstanceBloc extends Bloc<SpacetimeDbInstanceEvent, SpacetimeDbInstanceState> {
  static const String _storageKey = 'spacetimedb_instances';
  final _uuid = const Uuid();

  SpacetimeDbInstanceBloc() : super(SpacetimeDbInstancesLoading()) {
    on<LoadSpacetimeDbInstances>(_onLoadSpacetimeDbInstances);
    on<AddSpacetimeDbInstance>(_onAddSpacetimeDbInstance);
    on<UpdateSpacetimeDbInstance>(_onUpdateSpacetimeDbInstance);
    on<DeleteSpacetimeDbInstance>(_onDeleteSpacetimeDbInstance);
    on<DeleteAllSpacetimeDbInstances>(_onDeleteAllSpacetimeDbInstances);
    on<UpdateSpacetimeDbLastUsed>(_onUpdateSpacetimeDbLastUsed);
  }

  Future<void> _onLoadSpacetimeDbInstances(LoadSpacetimeDbInstances event, Emitter<SpacetimeDbInstanceState> emit) async {
    try {
      emit(SpacetimeDbInstancesLoading());
      final instances = await _loadInstancesFromStorage();
      emit(SpacetimeDbInstancesLoaded(instances));
    } catch (e) {
      emit(SpacetimeDbInstanceError('Failed to load instances: ${e.toString()}'));
    }
  }

  Future<void> _onAddSpacetimeDbInstance(AddSpacetimeDbInstance event, Emitter<SpacetimeDbInstanceState> emit) async {
    try {
      final currentState = state;
      if (currentState is! SpacetimeDbInstancesLoaded) {
        emit(const SpacetimeDbInstanceError('Cannot add instance when instances are not loaded'));
        return;
      }

      // Check if instance with same name already exists
      final existingInstance = currentState.instances.firstWhere(
        (instance) => instance.name.toLowerCase() == event.instance.name.toLowerCase(),
        orElse: () => SpacetimeDbInstance(
          id: '',
          name: '',
          ip: '',
          port: '',
          database: '',
        ),
      );

      if (existingInstance.id.isNotEmpty) {
        emit(SpacetimeDbInstanceError('An instance with the name "${event.instance.name}" already exists'));
        return;
      }

      final newInstance = event.instance.copyWith(
        id: event.instance.id.isEmpty ? _uuid.v4() : event.instance.id,
      );

      final updatedInstances = [...currentState.instances, newInstance];
      await _saveInstancesToStorage(updatedInstances);
      emit(SpacetimeDbInstancesLoaded(updatedInstances));
    } catch (e) {
      emit(SpacetimeDbInstanceError('Failed to add instance: ${e.toString()}'));
    }
  }

  Future<void> _onUpdateSpacetimeDbInstance(UpdateSpacetimeDbInstance event, Emitter<SpacetimeDbInstanceState> emit) async {
    try {
      final currentState = state;
      if (currentState is! SpacetimeDbInstancesLoaded) {
        emit(const SpacetimeDbInstanceError('Cannot update instance when instances are not loaded'));
        return;
      }

      final updatedInstances = currentState.instances.map((instance) {
        if (instance.id == event.instance.id) {
          return event.instance;
        }
        return instance;
      }).toList();

      await _saveInstancesToStorage(updatedInstances);
      emit(SpacetimeDbInstancesLoaded(updatedInstances));
    } catch (e) {
      emit(SpacetimeDbInstanceError('Failed to update instance: ${e.toString()}'));
    }
  }

  Future<void> _onDeleteSpacetimeDbInstance(DeleteSpacetimeDbInstance event, Emitter<SpacetimeDbInstanceState> emit) async {
    try {
      final currentState = state;
      if (currentState is! SpacetimeDbInstancesLoaded) {
        emit(const SpacetimeDbInstanceError('Cannot delete instance when instances are not loaded'));
        return;
      }

      // Show deleting state
      emit(SpacetimeDbInstanceDeleting(
        instances: currentState.instances,
        deletingInstanceId: event.id,
      ));

      // Simulate deletion delay for UX
      await Future.delayed(const Duration(milliseconds: 500));

      final updatedInstances = currentState.instances
          .where((instance) => instance.id != event.id)
          .toList();

      await _saveInstancesToStorage(updatedInstances);
      emit(SpacetimeDbInstancesLoaded(updatedInstances));
    } catch (e) {
      emit(SpacetimeDbInstanceError('Failed to delete instance: ${e.toString()}'));
    }
  }

  Future<void> _onDeleteAllSpacetimeDbInstances(DeleteAllSpacetimeDbInstances event, Emitter<SpacetimeDbInstanceState> emit) async {
    try {
      await _saveInstancesToStorage([]);
      emit(const SpacetimeDbInstancesLoaded([]));
    } catch (e) {
      emit(SpacetimeDbInstanceError('Failed to delete all instances: ${e.toString()}'));
    }
  }

  Future<void> _onUpdateSpacetimeDbLastUsed(UpdateSpacetimeDbLastUsed event, Emitter<SpacetimeDbInstanceState> emit) async {
    try {
      final currentState = state;
      if (currentState is! SpacetimeDbInstancesLoaded) return;

      final updatedInstances = currentState.instances.map((instance) {
        if (instance.id == event.id) {
          return instance.copyWith(lastUsed: DateTime.now());
        }
        return instance;
      }).toList();

      await _saveInstancesToStorage(updatedInstances);
      emit(SpacetimeDbInstancesLoaded(updatedInstances));
    } catch (e) {
      // Silently fail for lastUsed updates to not disrupt user flow
      print('Failed to update last used: ${e.toString()}');
    }
  }

  Future<List<SpacetimeDbInstance>> _loadInstancesFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final instancesJson = prefs.getString(_storageKey);

      if (instancesJson == null || instancesJson.isEmpty) {
        return [];
      }

      final List<dynamic> instancesList = json.decode(instancesJson);
      return instancesList
          .map((json) => SpacetimeDbInstance.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load instances from storage: ${e.toString()}');
    }
  }

  Future<void> _saveInstancesToStorage(List<SpacetimeDbInstance> instances) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final instancesJson = json.encode(instances.map((instance) => instance.toJson()).toList());
      await prefs.setString(_storageKey, instancesJson);
    } catch (e) {
      throw Exception('Failed to save instances to storage: ${e.toString()}');
    }
  }
}
