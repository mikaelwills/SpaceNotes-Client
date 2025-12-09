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

  /// Call the append_to_note reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> appendToNote({
    required String path,
    required String content,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(path);
    encoder.writeString(content);

    return await _reducerCaller.call('append_to_note', encoder.toBytes());
  }

  /// Call the clear_all reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> clearAll() async {
    final encoder = BsatnEncoder();

    return await _reducerCaller.call('clear_all', encoder.toBytes());
  }

  /// Call the create_folder reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> createFolder({
    required String path,
    required String name,
    required int depth,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(path);
    encoder.writeString(name);
    encoder.writeU32(depth);

    return await _reducerCaller.call('create_folder', encoder.toBytes());
  }

  /// Call the create_note reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
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

    return await _reducerCaller.call('create_note', encoder.toBytes());
  }

  /// Call the delete_folder reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> deleteFolder({
    required String path,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(path);

    return await _reducerCaller.call('delete_folder', encoder.toBytes());
  }

  /// Call the delete_note reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> deleteNote({
    required String id,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(id);

    return await _reducerCaller.call('delete_note', encoder.toBytes());
  }

  /// Call the find_replace_in_note reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> findReplaceInNote({
    required String path,
    required String oldText,
    required String newText,
    required bool replaceAll,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(path);
    encoder.writeString(oldText);
    encoder.writeString(newText);
    encoder.writeBool(replaceAll);

    return await _reducerCaller.call('find_replace_in_note', encoder.toBytes());
  }

  /// Call the get_recent_notes reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> getRecentNotes({
    required int limit,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeU32(limit);

    return await _reducerCaller.call('get_recent_notes', encoder.toBytes());
  }

  /// Call the identity_connected reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> identityConnected() async {
    final encoder = BsatnEncoder();

    return await _reducerCaller.call('identity_connected', encoder.toBytes());
  }

  /// Call the identity_disconnected reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> identityDisconnected() async {
    final encoder = BsatnEncoder();

    return await _reducerCaller.call('identity_disconnected', encoder.toBytes());
  }

  /// Call the init reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> init() async {
    final encoder = BsatnEncoder();

    return await _reducerCaller.call('init', encoder.toBytes());
  }

  /// Call the move_folder reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> moveFolder({
    required String oldPath,
    required String newPath,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(oldPath);
    encoder.writeString(newPath);

    return await _reducerCaller.call('move_folder', encoder.toBytes());
  }

  /// Call the move_note reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> moveNote({
    required String oldPath,
    required String newPath,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(oldPath);
    encoder.writeString(newPath);

    return await _reducerCaller.call('move_note', encoder.toBytes());
  }

  /// Call the prepend_to_note reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> prependToNote({
    required String path,
    required String content,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(path);
    encoder.writeString(content);

    return await _reducerCaller.call('prepend_to_note', encoder.toBytes());
  }

  /// Call the rename_note reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> renameNote({
    required String id,
    required String newPath,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(id);
    encoder.writeString(newPath);

    return await _reducerCaller.call('rename_note', encoder.toBytes());
  }

  /// Call the update_note_content reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> updateNoteContent({
    required String id,
    required String content,
    required String frontmatter,
    required Int64 size,
    required Int64 modifiedTime,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(id);
    encoder.writeString(content);
    encoder.writeString(frontmatter);
    encoder.writeU64(size);
    encoder.writeU64(modifiedTime);

    return await _reducerCaller.call('update_note_content', encoder.toBytes());
  }

  /// Call the update_note_path reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> updateNotePath({
    required String id,
    required String newPath,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(id);
    encoder.writeString(newPath);

    return await _reducerCaller.call('update_note_path', encoder.toBytes());
  }

  /// Call the upsert_folder reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
  ///
  /// Throws [ReducerException] if the reducer fails or runs out of energy.
  /// Throws [TimeoutException] if the reducer doesn't complete within the timeout.
  Future<TransactionResult> upsertFolder({
    required String path,
    required String name,
    required int depth,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(path);
    encoder.writeString(name);
    encoder.writeU32(depth);

    return await _reducerCaller.call('upsert_folder', encoder.toBytes());
  }

  /// Call the upsert_note reducer
  ///
  /// Returns [TransactionResult] with execution metadata:
  /// - `result.isSuccess` - Check if reducer committed
  /// - `result.energyConsumed` - Energy used (null for lightweight responses)
  /// - `result.executionDuration` - How long it took (null for lightweight responses)
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

    return await _reducerCaller.call('upsert_note', encoder.toBytes());
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

  StreamSubscription<void> onIdentityConnected(void Function(EventContext ctx) callback) {
    return _reducerEmitter.on('identity_connected').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! IdentityConnectedArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx);
    });
  }

  StreamSubscription<void> onIdentityDisconnected(void Function(EventContext ctx) callback) {
    return _reducerEmitter.on('identity_disconnected').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! IdentityDisconnectedArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx);
    });
  }

  StreamSubscription<void> onInit(void Function(EventContext ctx) callback) {
    return _reducerEmitter.on('init').listen((EventContext ctx) {
      // Pattern match to extract ReducerEvent
      final event = ctx.event;
      if (event is! ReducerEvent) return;

      // Type guard - ensures args is correct type
      final args = event.reducerArgs;
      if (args is! InitArgs) return;

      // Extract fields from strongly-typed object - NO CASTING
      callback(ctx);
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
