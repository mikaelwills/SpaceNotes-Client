// GENERATED CODE - DO NOT MODIFY BY HAND

import 'dart:async';
import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart';
import 'reducer_args.dart';

class Reducers {
  Reducers(
    this._reducerCaller,
    this._reducerEmitter,
  );

  final ReducerCaller _reducerCaller;

  final ReducerEmitter _reducerEmitter;

  Future<TransactionResult> acceptCall({
    required Int64 sessionId,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeU64(sessionId);
    return await _reducerCaller.call(acceptCallDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  Future<TransactionResult> appendToNote({
    required String path,
    required String content,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(path);
    encoder.writeString(content);
    return await _reducerCaller.call(appendToNoteDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  Future<TransactionResult> clearAll({
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    return await _reducerCaller.call(clearAllDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

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
    return await _reducerCaller.call(createFolderDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

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
    return await _reducerCaller.call(createNoteDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  Future<TransactionResult> deleteFolder({
    required String path,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(path);
    return await _reducerCaller.call(deleteFolderDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  Future<TransactionResult> deleteNote({
    required String id,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(id);
    return await _reducerCaller.call(deleteNoteDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  Future<TransactionResult> endCall({
    required Int64 sessionId,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeU64(sessionId);
    return await _reducerCaller.call(endCallDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

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
    return await _reducerCaller.call(
        findReplaceInNoteDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  Future<TransactionResult> getRecentNotes({
    required int limit,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeU32(limit);
    return await _reducerCaller.call(getRecentNotesDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  Future<TransactionResult> moveFolder({
    required String oldPath,
    required String newPath,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(oldPath);
    encoder.writeString(newPath);
    return await _reducerCaller.call(moveFolderDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  Future<TransactionResult> moveNote({
    required String oldPath,
    required String newPath,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(oldPath);
    encoder.writeString(newPath);
    return await _reducerCaller.call(moveNoteDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  Future<TransactionResult> prependToNote({
    required String path,
    required String content,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(path);
    encoder.writeString(content);
    return await _reducerCaller.call(prependToNoteDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  Future<TransactionResult> renameNote({
    required String id,
    required String newPath,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(id);
    encoder.writeString(newPath);
    return await _reducerCaller.call(renameNoteDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  Future<TransactionResult> requestCall({
    required Identity callee,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeIdentity(callee);
    return await _reducerCaller.call(requestCallDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

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
    return await _reducerCaller.call(sendAudioFrameDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  Future<TransactionResult> sendVideoFrame({
    required Int64 sessionId,
    required int seq,
    required int codec,
    required bool isKeyframe,
    required List<int> data,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeU64(sessionId);
    encoder.writeU32(seq);
    encoder.writeU8(codec);
    encoder.writeBool(isKeyframe);
    encoder.writeByteArray(data);
    return await _reducerCaller.call(sendVideoFrameDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  Future<TransactionResult> setDisplayName({
    required String name,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(name);
    return await _reducerCaller.call(setDisplayNameDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

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
    return await _reducerCaller.call(
        updateNoteContentDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  Future<TransactionResult> updateNotePath({
    required String id,
    required String newPath,
    List<OptimisticChange>? optimisticChanges,
    bool isEventTable = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(id);
    encoder.writeString(newPath);
    return await _reducerCaller.call(updateNotePathDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

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
    return await _reducerCaller.call(upsertFolderDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

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
    return await _reducerCaller.call(upsertNoteDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, isEventTable: isEventTable);
  }

  StreamSubscription<void> onAcceptCall(
      void Function(EventContext ctx, Int64 sessionId) callback) {
    return _reducerEmitter.on(acceptCallDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! AcceptCallArgs) return;
      callback(ctx, args.sessionId);
    });
  }

  StreamSubscription<void> onAppendToNote(
      void Function(EventContext ctx, String path, String content) callback) {
    return _reducerEmitter.on(appendToNoteDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! AppendToNoteArgs) return;
      callback(ctx, args.path, args.content);
    });
  }

  StreamSubscription<void> onClearAll(
      void Function(EventContext ctx) callback) {
    return _reducerEmitter.on(clearAllDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! ClearAllArgs) return;
      callback(ctx);
    });
  }

  StreamSubscription<void> onCreateFolder(
      void Function(EventContext ctx, String path, String name, int depth)
          callback) {
    return _reducerEmitter.on(createFolderDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! CreateFolderArgs) return;
      callback(ctx, args.path, args.name, args.depth);
    });
  }

  StreamSubscription<void> onCreateNote(
      void Function(
              EventContext ctx,
              String id,
              String path,
              String name,
              String content,
              String folderPath,
              int depth,
              String frontmatter,
              Int64 size,
              Int64 createdTime,
              Int64 modifiedTime)
          callback) {
    return _reducerEmitter.on(createNoteDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! CreateNoteArgs) return;
      callback(
          ctx,
          args.id,
          args.path,
          args.name,
          args.content,
          args.folderPath,
          args.depth,
          args.frontmatter,
          args.size,
          args.createdTime,
          args.modifiedTime);
    });
  }

  StreamSubscription<void> onDeleteFolder(
      void Function(EventContext ctx, String path) callback) {
    return _reducerEmitter.on(deleteFolderDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! DeleteFolderArgs) return;
      callback(ctx, args.path);
    });
  }

  StreamSubscription<void> onDeleteNote(
      void Function(EventContext ctx, String id) callback) {
    return _reducerEmitter.on(deleteNoteDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! DeleteNoteArgs) return;
      callback(ctx, args.id);
    });
  }

  StreamSubscription<void> onEndCall(
      void Function(EventContext ctx, Int64 sessionId) callback) {
    return _reducerEmitter.on(endCallDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! EndCallArgs) return;
      callback(ctx, args.sessionId);
    });
  }

  StreamSubscription<void> onFindReplaceInNote(
      void Function(EventContext ctx, String path, String oldText,
              String newText, bool replaceAll)
          callback) {
    return _reducerEmitter.on(findReplaceInNoteDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! FindReplaceInNoteArgs) return;
      callback(ctx, args.path, args.oldText, args.newText, args.replaceAll);
    });
  }

  StreamSubscription<void> onGetRecentNotes(
      void Function(EventContext ctx, int limit) callback) {
    return _reducerEmitter.on(getRecentNotesDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! GetRecentNotesArgs) return;
      callback(ctx, args.limit);
    });
  }

  StreamSubscription<void> onMoveFolder(
      void Function(EventContext ctx, String oldPath, String newPath)
          callback) {
    return _reducerEmitter.on(moveFolderDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! MoveFolderArgs) return;
      callback(ctx, args.oldPath, args.newPath);
    });
  }

  StreamSubscription<void> onMoveNote(
      void Function(EventContext ctx, String oldPath, String newPath)
          callback) {
    return _reducerEmitter.on(moveNoteDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! MoveNoteArgs) return;
      callback(ctx, args.oldPath, args.newPath);
    });
  }

  StreamSubscription<void> onPrependToNote(
      void Function(EventContext ctx, String path, String content) callback) {
    return _reducerEmitter.on(prependToNoteDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! PrependToNoteArgs) return;
      callback(ctx, args.path, args.content);
    });
  }

  StreamSubscription<void> onRenameNote(
      void Function(EventContext ctx, String id, String newPath) callback) {
    return _reducerEmitter.on(renameNoteDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! RenameNoteArgs) return;
      callback(ctx, args.id, args.newPath);
    });
  }

  StreamSubscription<void> onRequestCall(
      void Function(EventContext ctx, Identity callee) callback) {
    return _reducerEmitter.on(requestCallDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! RequestCallArgs) return;
      callback(ctx, args.callee);
    });
  }

  StreamSubscription<void> onSendAudioFrame(
      void Function(EventContext ctx, Int64 sessionId, int seq, List<int> pcm)
          callback) {
    return _reducerEmitter.on(sendAudioFrameDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! SendAudioFrameArgs) return;
      callback(ctx, args.sessionId, args.seq, args.pcm);
    });
  }

  StreamSubscription<void> onSendVideoFrame(
      void Function(EventContext ctx, Int64 sessionId, int seq, int codec,
              bool isKeyframe, List<int> data)
          callback) {
    return _reducerEmitter.on(sendVideoFrameDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! SendVideoFrameArgs) return;
      callback(ctx, args.sessionId, args.seq, args.codec, args.isKeyframe,
          args.data);
    });
  }

  StreamSubscription<void> onSetDisplayName(
      void Function(EventContext ctx, String name) callback) {
    return _reducerEmitter.on(setDisplayNameDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! SetDisplayNameArgs) return;
      callback(ctx, args.name);
    });
  }

  StreamSubscription<void> onUpdateNoteContent(
      void Function(EventContext ctx, String id, String content,
              String frontmatter, Int64 size, Int64 modifiedTime)
          callback) {
    return _reducerEmitter.on(updateNoteContentDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! UpdateNoteContentArgs) return;
      callback(ctx, args.id, args.content, args.frontmatter, args.size,
          args.modifiedTime);
    });
  }

  StreamSubscription<void> onUpdateNotePath(
      void Function(EventContext ctx, String id, String newPath) callback) {
    return _reducerEmitter.on(updateNotePathDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! UpdateNotePathArgs) return;
      callback(ctx, args.id, args.newPath);
    });
  }

  StreamSubscription<void> onUpsertFolder(
      void Function(EventContext ctx, String path, String name, int depth)
          callback) {
    return _reducerEmitter.on(upsertFolderDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! UpsertFolderArgs) return;
      callback(ctx, args.path, args.name, args.depth);
    });
  }

  StreamSubscription<void> onUpsertNote(
      void Function(
              EventContext ctx,
              String id,
              String path,
              String name,
              String content,
              String folderPath,
              int depth,
              String frontmatter,
              Int64 size,
              Int64 createdTime,
              Int64 modifiedTime)
          callback) {
    return _reducerEmitter.on(upsertNoteDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! UpsertNoteArgs) return;
      callback(
          ctx,
          args.id,
          args.path,
          args.name,
          args.content,
          args.folderPath,
          args.depth,
          args.frontmatter,
          args.size,
          args.createdTime,
          args.modifiedTime);
    });
  }
}
