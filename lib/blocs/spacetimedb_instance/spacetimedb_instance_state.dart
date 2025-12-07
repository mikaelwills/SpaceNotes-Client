import 'package:equatable/equatable.dart';
import '../../models/spacetimedb_instance.dart';

abstract class SpacetimeDbInstanceState extends Equatable {
  const SpacetimeDbInstanceState();

  @override
  List<Object> get props => [];
}

class SpacetimeDbInstancesLoading extends SpacetimeDbInstanceState {}

class SpacetimeDbInstancesLoaded extends SpacetimeDbInstanceState {
  final List<SpacetimeDbInstance> instances;

  const SpacetimeDbInstancesLoaded(this.instances);

  @override
  List<Object> get props => [instances];

  SpacetimeDbInstancesLoaded copyWith({
    List<SpacetimeDbInstance>? instances,
  }) {
    return SpacetimeDbInstancesLoaded(
      instances ?? this.instances,
    );
  }
}

class SpacetimeDbInstanceError extends SpacetimeDbInstanceState {
  final String message;

  const SpacetimeDbInstanceError(this.message);

  @override
  List<Object> get props => [message];
}

class SpacetimeDbInstanceDeleting extends SpacetimeDbInstancesLoaded {
  final String deletingInstanceId;

  const SpacetimeDbInstanceDeleting({
    required List<SpacetimeDbInstance> instances,
    required this.deletingInstanceId,
  }) : super(instances);

  @override
  List<Object> get props => [instances, deletingInstanceId];
}
