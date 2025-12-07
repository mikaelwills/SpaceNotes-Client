import 'package:equatable/equatable.dart';
import '../../models/spacetimedb_instance.dart';

abstract class SpacetimeDbInstanceEvent extends Equatable {
  const SpacetimeDbInstanceEvent();

  @override
  List<Object> get props => [];
}

class LoadSpacetimeDbInstances extends SpacetimeDbInstanceEvent {}

class AddSpacetimeDbInstance extends SpacetimeDbInstanceEvent {
  final SpacetimeDbInstance instance;

  const AddSpacetimeDbInstance(this.instance);

  @override
  List<Object> get props => [instance];
}

class UpdateSpacetimeDbInstance extends SpacetimeDbInstanceEvent {
  final SpacetimeDbInstance instance;

  const UpdateSpacetimeDbInstance(this.instance);

  @override
  List<Object> get props => [instance];
}

class DeleteSpacetimeDbInstance extends SpacetimeDbInstanceEvent {
  final String id;

  const DeleteSpacetimeDbInstance(this.id);

  @override
  List<Object> get props => [id];
}

class DeleteAllSpacetimeDbInstances extends SpacetimeDbInstanceEvent {}

class UpdateSpacetimeDbLastUsed extends SpacetimeDbInstanceEvent {
  final String id;

  const UpdateSpacetimeDbLastUsed(this.id);

  @override
  List<Object> get props => [id];
}
