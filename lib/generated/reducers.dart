// GENERATED CODE - DO NOT MODIFY BY HAND

import 'dart:async';
import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart';
import 'reducer_args.dart';

/// Generated reducer methods with async/await support
///
/// All methods return Future<TransactionResult> containing:
/// - status: Committed/Failed/OutOfEnergy
/// - timestamp: When the reducer executed
/// - energyConsumed: Energy used (null for TransactionUpdateLight)
/// - executionDuration: How long it took (null for TransactionUpdateLight)
class Reducers {
  final ReducerCaller _reducerCaller;
  final ReducerEmitter _reducerEmitter;

  Reducers(this._reducerCaller, this._reducerEmitter);

  /// Call the accept_call reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> acceptCall({
    required Int64 sessionId,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeU64(sessionId);

    return await _reducerCaller.call('accept_call', encoder.toBytes(), optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  /// Call the append_to_note reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> appendToNote({
    required String path,
    required String content,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(path);
    encoder.writeString(content);

    return await _reducerCaller.call('append_to_note', encoder.toBytes(), optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  /// Call the clear_all reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> clearAll({List<OptimisticChange>? optimisticChanges, bool isEventTable = false}) async {
    final encoder = BsatnEncoder();

    return await _reducerCaller.call('clear_all', encoder.toBytes(), optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  /// Call the create_folder reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> createFolder({
    required String path,
    required String name,
    required int depth,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(path);
    encoder.writeString(name);
    encoder.writeU32(depth);

    return await _reducerCaller.call('create_folder', encoder.toBytes(), optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  /// Call the create_note reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> createNote({
    required String id,
    required String path,
    required String name,
    required String content,
    required String folderPath,
    required int depth,
    required String frontmatter,
    required Int64 size,
    required Int64 createdTime,
    required Int64 modifiedTime,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(id);
    encoder.writeString(path);
    encoder.writeString(name);
    encoder.writeString(content);
    encoder.writeString(folderPath);
    encoder.writeU32(depth);
    encoder.writeString(frontmatter);
    encoder.writeU64(size);
    encoder.writeU64(createdTime);
    encoder.writeU64(modifiedTime);

    return await _reducerCaller.call('create_note', encoder.toBytes(), optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  /// Call the delete_folder reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> deleteFolder({
    required String path,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(path);

    return await _reducerCaller.call('delete_folder', encoder.toBytes(), optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  /// Call the delete_note reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> deleteNote({
    required String id,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(id);

    return await _reducerCaller.call('delete_note', encoder.toBytes(), optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  /// Call the end_call reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> endCall({
    required Int64 sessionId,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeU64(sessionId);

    return await _reducerCaller.call('end_call', encoder.toBytes(), optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  /// Call the find_replace_in_note reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> findReplaceInNote({
    required String path,
    required String oldText,
    required String newText,
    required bool replaceAll,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(path);
    encoder.writeString(oldText);
    encoder.writeString(newText);
    encoder.writeBool(replaceAll);

    return await _reducerCaller.call('find_replace_in_note', encoder.toBytes(), optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  /// Call the get_recent_notes reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> getRecentNotes({
    required int limit,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeU32(limit);

    return await _reducerCaller.call('get_recent_notes', encoder.toBytes(), optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  /// Call the move_folder reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> moveFolder({
    required String oldPath,
    required String newPath,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(oldPath);
    encoder.writeString(newPath);

    return await _reducerCaller.call('move_folder', encoder.toBytes(), optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  /// Call the move_note reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> moveNote({
    required String oldPath,
    required String newPath,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(oldPath);
    encoder.writeString(newPath);

    return await _reducerCaller.call('move_note', encoder.toBytes(), optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  /// Call the prepend_to_note reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> prependToNote({
    required String path,
    required String content,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(path);
    encoder.writeString(content);

    return await _reducerCaller.call('prepend_to_note', encoder.toBytes(), optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  /// Call the rename_note reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> renameNote({
    required String id,
    required String newPath,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(id);
    encoder.writeString(newPath);

    return await _reducerCaller.call('rename_note', encoder.toBytes(), optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  /// Call the request_call reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> requestCall({
    required Identity callee,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeIdentity(callee);

    return await _reducerCaller.call('request_call', encoder.toBytes(), optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  /// Call the send_audio_frame reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> sendAudioFrame({
    required Int64 sessionId,
    required int seq,
    required List<int> pcm,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeU64(sessionId);
    encoder.writeU32(seq);
    encoder.writeByteArray(pcm);

    return await _reducerCaller.call('send_audio_frame', encoder.toBytes(), optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  /// Call the send_video_frame reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> sendVideoFrame({
    required Int64 sessionId,
    required int seq,
    required List<int> jpeg,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeU64(sessionId);
    encoder.writeU32(seq);
    encoder.writeByteArray(jpeg);

    return await _reducerCaller.call('send_video_frame', encoder.toBytes(), optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  /// Call the set_display_name reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> setDisplayName({
    required String name,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(name);

    return await _reducerCaller.call('set_display_name', encoder.toBytes(), optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  /// Call the update_note_content reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> updateNoteContent({
    required String id,
    required String content,
    required String frontmatter,
    required Int64 size,
    required Int64 modifiedTime,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(id);
    encoder.writeString(content);
    encoder.writeString(frontmatter);
    encoder.writeU64(size);
    encoder.writeU64(modifiedTime);

    return await _reducerCaller.call('update_note_content', encoder.toBytes(), optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  /// Call the update_note_path reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> updateNotePath({
    required String id,
    required String newPath,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(id);
    encoder.writeString(newPath);

    return await _reducerCaller.call('update_note_path', encoder.toBytes(), optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  /// Call the upsert_folder reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> upsertFolder({
    required String path,
    required String name,
    required int depth,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(path);
    encoder.writeString(name);
    encoder.writeU32(depth);

    return await _reducerCaller.call('upsert_folder', encoder.toBytes(), optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  /// Call the upsert_note reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.
  /// Changes are rolled back if the server rejects them.
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> upsertNote({
    required String id,
    required String path,
    required String name,
    required String content,
    required String folderPath,
    required int depth,
    required String frontmatter,
    required Int64 size,
    required Int64 createdTime,
    required Int64 modifiedTime,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(id);
    encoder.writeString(path);
    encoder.writeString(name);
    encoder.writeString(content);
    encoder.writeString(folderPath);
    encoder.writeU32(depth);
    encoder.writeString(frontmatter);
    encoder.writeU64(size);
    encoder.writeU64(createdTime);
    encoder.writeU64(modifiedTime);

    return await _reducerCaller.call('upsert_note', encoder.toBytes(), optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  StreamSubscription<void> onAcceptCall(void Function(EventContext ctx, Int64 sessionId) callback) {
    return _reducerEmitter.on('accept_call').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! AcceptCallArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx, args.sessionId);
    });
  }

  StreamSubscription<void> onAppendToNote(void Function(EventContext ctx, String path, String content) callback) {
    return _reducerEmitter.on('append_to_note').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! AppendToNoteArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx, args.path, args.content);
    });
  }

  StreamSubscription<void> onClearAll(void Function(EventContext ctx) callback) {
    return _reducerEmitter.on('clear_all').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! ClearAllArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx);
    });
  }

  StreamSubscription<void> onCreateFolder(void Function(EventContext ctx, String path, String name, int depth) callback) {
    return _reducerEmitter.on('create_folder').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! CreateFolderArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx, args.path, args.name, args.depth);
    });
  }

  StreamSubscription<void> onCreateNote(void Function(EventContext ctx, String id, String path, String name, String content, String folderPath, int depth, String frontmatter, Int64 size, Int64 createdTime, Int64 modifiedTime) callback) {
    return _reducerEmitter.on('create_note').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! CreateNoteArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx, args.id, args.path, args.name, args.content, args.folderPath, args.depth, args.frontmatter, args.size, args.createdTime, args.modifiedTime);
    });
  }

  StreamSubscription<void> onDeleteFolder(void Function(EventContext ctx, String path) callback) {
    return _reducerEmitter.on('delete_folder').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! DeleteFolderArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx, args.path);
    });
  }

  StreamSubscription<void> onDeleteNote(void Function(EventContext ctx, String id) callback) {
    return _reducerEmitter.on('delete_note').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! DeleteNoteArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx, args.id);
    });
  }

  StreamSubscription<void> onEndCall(void Function(EventContext ctx, Int64 sessionId) callback) {
    return _reducerEmitter.on('end_call').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! EndCallArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx, args.sessionId);
    });
  }

  StreamSubscription<void> onFindReplaceInNote(void Function(EventContext ctx, String path, String oldText, String newText, bool replaceAll) callback) {
    return _reducerEmitter.on('find_replace_in_note').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! FindReplaceInNoteArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx, args.path, args.oldText, args.newText, args.replaceAll);
    });
  }

  StreamSubscription<void> onGetRecentNotes(void Function(EventContext ctx, int limit) callback) {
    return _reducerEmitter.on('get_recent_notes').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! GetRecentNotesArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx, args.limit);
    });
  }

  StreamSubscription<void> onMoveFolder(void Function(EventContext ctx, String oldPath, String newPath) callback) {
    return _reducerEmitter.on('move_folder').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! MoveFolderArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx, args.oldPath, args.newPath);
    });
  }

  StreamSubscription<void> onMoveNote(void Function(EventContext ctx, String oldPath, String newPath) callback) {
    return _reducerEmitter.on('move_note').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! MoveNoteArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx, args.oldPath, args.newPath);
    });
  }

  StreamSubscription<void> onPrependToNote(void Function(EventContext ctx, String path, String content) callback) {
    return _reducerEmitter.on('prepend_to_note').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! PrependToNoteArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx, args.path, args.content);
    });
  }

  StreamSubscription<void> onRenameNote(void Function(EventContext ctx, String id, String newPath) callback) {
    return _reducerEmitter.on('rename_note').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! RenameNoteArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx, args.id, args.newPath);
    });
  }

  StreamSubscription<void> onRequestCall(void Function(EventContext ctx, Identity callee) callback) {
    return _reducerEmitter.on('request_call').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! RequestCallArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx, args.callee);
    });
  }

  StreamSubscription<void> onSendAudioFrame(void Function(EventContext ctx, Int64 sessionId, int seq, List<int> pcm) callback) {
    return _reducerEmitter.on('send_audio_frame').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! SendAudioFrameArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx, args.sessionId, args.seq, args.pcm);
    });
  }

  StreamSubscription<void> onSendVideoFrame(void Function(EventContext ctx, Int64 sessionId, int seq, List<int> jpeg) callback) {
    return _reducerEmitter.on('send_video_frame').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! SendVideoFrameArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx, args.sessionId, args.seq, args.jpeg);
    });
  }

  StreamSubscription<void> onSetDisplayName(void Function(EventContext ctx, String name) callback) {
    return _reducerEmitter.on('set_display_name').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! SetDisplayNameArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx, args.name);
    });
  }

  StreamSubscription<void> onUpdateNoteContent(void Function(EventContext ctx, String id, String content, String frontmatter, Int64 size, Int64 modifiedTime) callback) {
    return _reducerEmitter.on('update_note_content').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! UpdateNoteContentArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx, args.id, args.content, args.frontmatter, args.size, args.modifiedTime);
    });
  }

  StreamSubscription<void> onUpdateNotePath(void Function(EventContext ctx, String id, String newPath) callback) {
    return _reducerEmitter.on('update_note_path').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! UpdateNotePathArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx, args.id, args.newPath);
    });
  }

  StreamSubscription<void> onUpsertFolder(void Function(EventContext ctx, String path, String name, int depth) callback) {
    return _reducerEmitter.on('upsert_folder').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! UpsertFolderArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx, args.path, args.name, args.depth);
    });
  }

  StreamSubscription<void> onUpsertNote(void Function(EventContext ctx, String id, String path, String name, String content, String folderPath, int depth, String frontmatter, Int64 size, Int64 createdTime, Int64 modifiedTime) callback) {
    return _reducerEmitter.on('upsert_note').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! UpsertNoteArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx, args.id, args.path, args.name, args.content, args.folderPath, args.depth, args.frontmatter, args.size, args.createdTime, args.modifiedTime);
    });
  }

}
