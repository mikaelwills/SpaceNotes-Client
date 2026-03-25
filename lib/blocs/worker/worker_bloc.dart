import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/session_event.dart' as model;
import '../../models/tool_event.dart' as model;
import '../../services/space_channel_service.dart';
import 'worker_event.dart';
import 'worker_state.dart';

class WorkerBloc extends Bloc<WorkerEvent, WorkerState> {
  final SpaceChannelService _spaceChannel;
  StreamSubscription<model.SessionEvent>? _sessionSub;
  StreamSubscription<model.ToolEvent>? _toolSub;

  WorkerBloc(this._spaceChannel) : super(const WorkerState()) {
    on<WorkerConnected>(_onWorkerConnected);
    on<WorkerDisconnected>(_onWorkerDisconnected);
    on<WorkerToolEventReceived>(_onToolEventReceived);

    _sessionSub = _spaceChannel.sessionEvents.listen((event) {
      if (event.isConnected) {
        add(WorkerConnected(
          session: event.session,
          project: event.project ?? '',
          task: event.task ?? '',
          isMaster: event.isMaster ?? false,
        ));
      } else if (event.isDisconnected) {
        add(WorkerDisconnected(event.session));
      }
    });

    _toolSub = _spaceChannel.toolEvents.listen((event) {
      add(WorkerToolEventReceived(
        session: event.session,
        toolName: event.tool,
        inputSummary: event.input.toString(),
      ));
    });
  }

  void _onWorkerConnected(WorkerConnected event, Emitter<WorkerState> emit) {
    final now = DateTime.now();
    final worker = WorkerInfo(
      session: event.session,
      project: event.project,
      task: event.task,
      isMaster: event.isMaster,
      connectedAt: now,
      lastActivity: now,
    );
    emit(state.copyWith(
      workers: {...state.workers, event.session: worker},
    ));
  }

  void _onWorkerDisconnected(WorkerDisconnected event, Emitter<WorkerState> emit) {
    final updated = Map<String, WorkerInfo>.from(state.workers)..remove(event.session);
    emit(state.copyWith(workers: updated));
  }

  void _onToolEventReceived(WorkerToolEventReceived event, Emitter<WorkerState> emit) {
    final worker = state.workers[event.session];
    if (worker == null) return;

    final now = DateTime.now();
    final toolEvent = ToolEvent(
      toolName: event.toolName,
      inputSummary: event.inputSummary,
      timestamp: now,
    );

    final updatedEvents = [...worker.recentToolEvents, toolEvent];
    final trimmed = updatedEvents.length > 10
        ? updatedEvents.sublist(updatedEvents.length - 10)
        : updatedEvents;

    emit(state.copyWith(
      workers: {
        ...state.workers,
        event.session: worker.copyWith(
          lastActivity: now,
          recentToolEvents: trimmed,
        ),
      },
    ));
  }

  @override
  Future<void> close() {
    _sessionSub?.cancel();
    _toolSub?.cancel();
    return super.close();
  }
}
