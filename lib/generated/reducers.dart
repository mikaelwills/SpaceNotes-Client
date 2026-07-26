// GENERATED CODE - DO NOT MODIFY BY HAND

import 'dart:async';
import 'package:spacetimedb_sdk/codegen.dart';
import 'reducer_args.dart';

class Reducers {
  Reducers(
    this._reducerCaller,
    this._reducerEmitter,
  );

  final ReducerCaller _reducerCaller;

  final ReducerEmitter _reducerEmitter;

  /// Calls the `accept_call` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> acceptCall({
    required Int64 callId,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeU64(callId);
    return await _reducerCaller.call(acceptCallDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `append_to_file` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> appendToFile({
    required String path,
    required String content,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(path);
    encoder.writeString(content);
    return await _reducerCaller.call(appendToFileDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `clear_all` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> clearAll({
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    return await _reducerCaller.call(clearAllDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `clear_all_agents` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> clearAllAgents({
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    return await _reducerCaller.call(clearAllAgentsDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `create_file` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> createFile({
    required String id,
    required String path,
    required String name,
    required String content,
    required String folderPath,
    required int depth,
    required String extension,
    required Int64 size,
    required Int64 createdTime,
    required Int64 modifiedTime,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(id);
    encoder.writeString(path);
    encoder.writeString(name);
    encoder.writeString(content);
    encoder.writeString(folderPath);
    encoder.writeU32(depth);
    encoder.writeString(extension);
    encoder.writeU64(size);
    encoder.writeU64(createdTime);
    encoder.writeU64(modifiedTime);
    return await _reducerCaller.call(createFileDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `create_folder` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> createFolder({
    required String path,
    required String name,
    required int depth,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(path);
    encoder.writeString(name);
    encoder.writeU32(depth);
    return await _reducerCaller.call(createFolderDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `delete_agent` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> deleteAgent({
    required String agentId,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(agentId);
    return await _reducerCaller.call(deleteAgentDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `delete_file` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> deleteFile({
    required String id,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(id);
    return await _reducerCaller.call(deleteFileDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `delete_folder` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> deleteFolder({
    required String path,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(path);
    return await _reducerCaller.call(deleteFolderDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `edit_message` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> editMessage({
    required String id,
    required String text,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(id);
    encoder.writeString(text);
    return await _reducerCaller.call(editMessageDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `end_agent` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> endAgent({
    required String agentId,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(agentId);
    return await _reducerCaller.call(endAgentDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `end_call` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> endCall({
    required Int64 callId,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeU64(callId);
    return await _reducerCaller.call(endCallDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `find_replace_in_file` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> findReplaceInFile({
    required String path,
    required String oldText,
    required String newText,
    required bool replaceAll,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(path);
    encoder.writeString(oldText);
    encoder.writeString(newText);
    encoder.writeBool(replaceAll);
    return await _reducerCaller.call(
        findReplaceInFileDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `get_recent_files` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> getRecentFiles({
    required int limit,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeU32(limit);
    return await _reducerCaller.call(getRecentFilesDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `heartbeat` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> heartbeat({
    required String agentId,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(agentId);
    return await _reducerCaller.call(heartbeatDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `move_file` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> moveFile({
    required String oldPath,
    required String newPath,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(oldPath);
    encoder.writeString(newPath);
    return await _reducerCaller.call(moveFileDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `move_folder` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> moveFolder({
    required String oldPath,
    required String newPath,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(oldPath);
    encoder.writeString(newPath);
    return await _reducerCaller.call(moveFolderDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `prepend_to_file` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> prependToFile({
    required String path,
    required String content,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(path);
    encoder.writeString(content);
    return await _reducerCaller.call(prependToFileDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `push_context_usage` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> pushContextUsage({
    required String agentId,
    required Int64 used,
    required Int64 window,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(agentId);
    encoder.writeU64(used);
    encoder.writeU64(window);
    return await _reducerCaller.call(
        pushContextUsageDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `push_image` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> pushImage({
    required String id,
    required String agentId,
    required String caption,
    required List<int> bytes,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(id);
    encoder.writeString(agentId);
    encoder.writeString(caption);
    encoder.writeByteArray(bytes);
    return await _reducerCaller.call(pushImageDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `push_message` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> pushMessage({
    required String id,
    required String agentId,
    required String role,
    required String text,
    required String source,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(id);
    encoder.writeString(agentId);
    encoder.writeString(role);
    encoder.writeString(text);
    encoder.writeString(source);
    return await _reducerCaller.call(pushMessageDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `push_status` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> pushStatus({
    required String agentId,
    required String state,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(agentId);
    encoder.writeString(state);
    return await _reducerCaller.call(pushStatusDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `push_tool_event` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> pushToolEvent({
    required String id,
    required String agentId,
    required String tool,
    required String detail,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(id);
    encoder.writeString(agentId);
    encoder.writeString(tool);
    encoder.writeString(detail);
    return await _reducerCaller.call(pushToolEventDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `register_agent` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> registerAgent({
    required String id,
    required String baseName,
    required String host,
    required String clientId,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(id);
    encoder.writeString(baseName);
    encoder.writeString(host);
    encoder.writeString(clientId);
    return await _reducerCaller.call(registerAgentDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `rename_file` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> renameFile({
    required String id,
    required String newPath,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(id);
    encoder.writeString(newPath);
    return await _reducerCaller.call(renameFileDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `request_call` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> requestCall({
    required Identity callee,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeIdentity(callee);
    return await _reducerCaller.call(requestCallDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `request_permission` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> requestPermission({
    required String id,
    required String agentId,
    required String tool,
    required String input,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(id);
    encoder.writeString(agentId);
    encoder.writeString(tool);
    encoder.writeString(input);
    return await _reducerCaller.call(
        requestPermissionDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `request_question` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> requestQuestion({
    required String id,
    required String agentId,
    required String question,
    required String header,
    required String options,
    required bool multiSelect,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(id);
    encoder.writeString(agentId);
    encoder.writeString(question);
    encoder.writeString(header);
    encoder.writeString(options);
    encoder.writeBool(multiSelect);
    return await _reducerCaller.call(requestQuestionDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `resolve_permission` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> resolvePermission({
    required String id,
    required String status,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(id);
    encoder.writeString(status);
    return await _reducerCaller.call(
        resolvePermissionDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `respond_to_question` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> respondToQuestion({
    required String id,
    required String response,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(id);
    encoder.writeString(response);
    return await _reducerCaller.call(
        respondToQuestionDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `send_audio_frame` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> sendAudioFrame({
    required Int64 callId,
    required int seq,
    required List<int> pcm,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeU64(callId);
    encoder.writeU32(seq);
    encoder.writeByteArray(pcm);
    return await _reducerCaller.call(sendAudioFrameDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `send_video_frame` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> sendVideoFrame({
    required Int64 callId,
    required int seq,
    required int codec,
    required bool isKeyframe,
    required List<int> data,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeU64(callId);
    encoder.writeU32(seq);
    encoder.writeU8(codec);
    encoder.writeBool(isKeyframe);
    encoder.writeByteArray(data);
    return await _reducerCaller.call(sendVideoFrameDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `set_display_name` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> setDisplayName({
    required String name,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(name);
    return await _reducerCaller.call(setDisplayNameDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `sweep_old_messages` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> sweepOldMessages({
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    return await _reducerCaller.call(
        sweepOldMessagesDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `update_file_content` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> updateFileContent({
    required String id,
    required String content,
    required Int64 size,
    required Int64 modifiedTime,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(id);
    encoder.writeString(content);
    encoder.writeU64(size);
    encoder.writeU64(modifiedTime);
    return await _reducerCaller.call(
        updateFileContentDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `update_file_path` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> updateFilePath({
    required String id,
    required String newPath,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(id);
    encoder.writeString(newPath);
    return await _reducerCaller.call(updateFilePathDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `upsert_file` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> upsertFile({
    required String id,
    required String path,
    required String name,
    required String content,
    required String folderPath,
    required int depth,
    required String extension,
    required Int64 size,
    required Int64 createdTime,
    required Int64 modifiedTime,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(id);
    encoder.writeString(path);
    encoder.writeString(name);
    encoder.writeString(content);
    encoder.writeString(folderPath);
    encoder.writeU32(depth);
    encoder.writeString(extension);
    encoder.writeU64(size);
    encoder.writeU64(createdTime);
    encoder.writeU64(modifiedTime);
    return await _reducerCaller.call(upsertFileDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  /// Calls the `upsert_folder` reducer.
  ///
  /// Returns a [TransactionResult] on success. Throws
  /// [SpacetimeDbReducerException] if the reducer returns `Failed` or
  /// `InternalError`. The returned status is one of `Committed`,
  /// `Pending` (queued to offline storage), or `Dropped` (skipped via
  /// `dropIfOffline: true` while offline).
  Future<TransactionResult> upsertFolder({
    required String path,
    required String name,
    required int depth,
    List<OptimisticChange>? optimisticChanges,
    bool dropIfOffline = false,
  }) async {
    final encoder = BsatnEncoder();
    encoder.writeString(path);
    encoder.writeString(name);
    encoder.writeU32(depth);
    return await _reducerCaller.call(upsertFolderDef.name, encoder.toBytes(),
        optimisticChanges: optimisticChanges, dropIfOffline: dropIfOffline);
  }

  StreamSubscription<void> onAcceptCall(
      void Function(EventContext ctx, Int64 callId) callback) {
    return _reducerEmitter.on(acceptCallDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! AcceptCallArgs) return;
      callback(ctx, args.callId);
    });
  }

  StreamSubscription<void> onAppendToFile(
      void Function(EventContext ctx, String path, String content) callback) {
    return _reducerEmitter.on(appendToFileDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! AppendToFileArgs) return;
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

  StreamSubscription<void> onClearAllAgents(
      void Function(EventContext ctx) callback) {
    return _reducerEmitter.on(clearAllAgentsDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! ClearAllAgentsArgs) return;
      callback(ctx);
    });
  }

  StreamSubscription<void> onCreateFile(
      void Function(
              EventContext ctx,
              String id,
              String path,
              String name,
              String content,
              String folderPath,
              int depth,
              String extension,
              Int64 size,
              Int64 createdTime,
              Int64 modifiedTime)
          callback) {
    return _reducerEmitter.on(createFileDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! CreateFileArgs) return;
      callback(
          ctx,
          args.id,
          args.path,
          args.name,
          args.content,
          args.folderPath,
          args.depth,
          args.extension,
          args.size,
          args.createdTime,
          args.modifiedTime);
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

  StreamSubscription<void> onDeleteAgent(
      void Function(EventContext ctx, String agentId) callback) {
    return _reducerEmitter.on(deleteAgentDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! DeleteAgentArgs) return;
      callback(ctx, args.agentId);
    });
  }

  StreamSubscription<void> onDeleteFile(
      void Function(EventContext ctx, String id) callback) {
    return _reducerEmitter.on(deleteFileDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! DeleteFileArgs) return;
      callback(ctx, args.id);
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

  StreamSubscription<void> onEditMessage(
      void Function(EventContext ctx, String id, String text) callback) {
    return _reducerEmitter.on(editMessageDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! EditMessageArgs) return;
      callback(ctx, args.id, args.text);
    });
  }

  StreamSubscription<void> onEndAgent(
      void Function(EventContext ctx, String agentId) callback) {
    return _reducerEmitter.on(endAgentDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! EndAgentArgs) return;
      callback(ctx, args.agentId);
    });
  }

  StreamSubscription<void> onEndCall(
      void Function(EventContext ctx, Int64 callId) callback) {
    return _reducerEmitter.on(endCallDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! EndCallArgs) return;
      callback(ctx, args.callId);
    });
  }

  StreamSubscription<void> onFindReplaceInFile(
      void Function(EventContext ctx, String path, String oldText,
              String newText, bool replaceAll)
          callback) {
    return _reducerEmitter.on(findReplaceInFileDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! FindReplaceInFileArgs) return;
      callback(ctx, args.path, args.oldText, args.newText, args.replaceAll);
    });
  }

  StreamSubscription<void> onGetRecentFiles(
      void Function(EventContext ctx, int limit) callback) {
    return _reducerEmitter.on(getRecentFilesDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! GetRecentFilesArgs) return;
      callback(ctx, args.limit);
    });
  }

  StreamSubscription<void> onHeartbeat(
      void Function(EventContext ctx, String agentId) callback) {
    return _reducerEmitter.on(heartbeatDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! HeartbeatArgs) return;
      callback(ctx, args.agentId);
    });
  }

  StreamSubscription<void> onMoveFile(
      void Function(EventContext ctx, String oldPath, String newPath)
          callback) {
    return _reducerEmitter.on(moveFileDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! MoveFileArgs) return;
      callback(ctx, args.oldPath, args.newPath);
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

  StreamSubscription<void> onPrependToFile(
      void Function(EventContext ctx, String path, String content) callback) {
    return _reducerEmitter.on(prependToFileDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! PrependToFileArgs) return;
      callback(ctx, args.path, args.content);
    });
  }

  StreamSubscription<void> onPushContextUsage(
      void Function(EventContext ctx, String agentId, Int64 used, Int64 window)
          callback) {
    return _reducerEmitter.on(pushContextUsageDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! PushContextUsageArgs) return;
      callback(ctx, args.agentId, args.used, args.window);
    });
  }

  StreamSubscription<void> onPushImage(
      void Function(EventContext ctx, String id, String agentId, String caption,
              List<int> bytes)
          callback) {
    return _reducerEmitter.on(pushImageDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! PushImageArgs) return;
      callback(ctx, args.id, args.agentId, args.caption, args.bytes);
    });
  }

  StreamSubscription<void> onPushMessage(
      void Function(EventContext ctx, String id, String agentId, String role,
              String text, String source)
          callback) {
    return _reducerEmitter.on(pushMessageDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! PushMessageArgs) return;
      callback(ctx, args.id, args.agentId, args.role, args.text, args.source);
    });
  }

  StreamSubscription<void> onPushStatus(
      void Function(EventContext ctx, String agentId, String state) callback) {
    return _reducerEmitter.on(pushStatusDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! PushStatusArgs) return;
      callback(ctx, args.agentId, args.state);
    });
  }

  StreamSubscription<void> onPushToolEvent(
      void Function(EventContext ctx, String id, String agentId, String tool,
              String detail)
          callback) {
    return _reducerEmitter.on(pushToolEventDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! PushToolEventArgs) return;
      callback(ctx, args.id, args.agentId, args.tool, args.detail);
    });
  }

  StreamSubscription<void> onRegisterAgent(
      void Function(EventContext ctx, String id, String baseName, String host,
              String clientId)
          callback) {
    return _reducerEmitter.on(registerAgentDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! RegisterAgentArgs) return;
      callback(ctx, args.id, args.baseName, args.host, args.clientId);
    });
  }

  StreamSubscription<void> onRenameFile(
      void Function(EventContext ctx, String id, String newPath) callback) {
    return _reducerEmitter.on(renameFileDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! RenameFileArgs) return;
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

  StreamSubscription<void> onRequestPermission(
      void Function(EventContext ctx, String id, String agentId, String tool,
              String input)
          callback) {
    return _reducerEmitter.on(requestPermissionDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! RequestPermissionArgs) return;
      callback(ctx, args.id, args.agentId, args.tool, args.input);
    });
  }

  StreamSubscription<void> onRequestQuestion(
      void Function(EventContext ctx, String id, String agentId,
              String question, String header, String options, bool multiSelect)
          callback) {
    return _reducerEmitter.on(requestQuestionDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! RequestQuestionArgs) return;
      callback(ctx, args.id, args.agentId, args.question, args.header,
          args.options, args.multiSelect);
    });
  }

  StreamSubscription<void> onResolvePermission(
      void Function(EventContext ctx, String id, String status) callback) {
    return _reducerEmitter.on(resolvePermissionDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! ResolvePermissionArgs) return;
      callback(ctx, args.id, args.status);
    });
  }

  StreamSubscription<void> onRespondToQuestion(
      void Function(EventContext ctx, String id, String response) callback) {
    return _reducerEmitter.on(respondToQuestionDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! RespondToQuestionArgs) return;
      callback(ctx, args.id, args.response);
    });
  }

  StreamSubscription<void> onSendAudioFrame(
      void Function(EventContext ctx, Int64 callId, int seq, List<int> pcm)
          callback) {
    return _reducerEmitter.on(sendAudioFrameDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! SendAudioFrameArgs) return;
      callback(ctx, args.callId, args.seq, args.pcm);
    });
  }

  StreamSubscription<void> onSendVideoFrame(
      void Function(EventContext ctx, Int64 callId, int seq, int codec,
              bool isKeyframe, List<int> data)
          callback) {
    return _reducerEmitter.on(sendVideoFrameDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! SendVideoFrameArgs) return;
      callback(
          ctx, args.callId, args.seq, args.codec, args.isKeyframe, args.data);
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

  StreamSubscription<void> onSweepOldMessages(
      void Function(EventContext ctx) callback) {
    return _reducerEmitter.on(sweepOldMessagesDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! SweepOldMessagesArgs) return;
      callback(ctx);
    });
  }

  StreamSubscription<void> onUpdateFileContent(
      void Function(EventContext ctx, String id, String content, Int64 size,
              Int64 modifiedTime)
          callback) {
    return _reducerEmitter.on(updateFileContentDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! UpdateFileContentArgs) return;
      callback(ctx, args.id, args.content, args.size, args.modifiedTime);
    });
  }

  StreamSubscription<void> onUpdateFilePath(
      void Function(EventContext ctx, String id, String newPath) callback) {
    return _reducerEmitter.on(updateFilePathDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! UpdateFilePathArgs) return;
      callback(ctx, args.id, args.newPath);
    });
  }

  StreamSubscription<void> onUpsertFile(
      void Function(
              EventContext ctx,
              String id,
              String path,
              String name,
              String content,
              String folderPath,
              int depth,
              String extension,
              Int64 size,
              Int64 createdTime,
              Int64 modifiedTime)
          callback) {
    return _reducerEmitter.on(upsertFileDef).listen((EventContext ctx) {
      final event = ctx.event;
      if (event is! ReducerEvent) return;
      final args = event.reducerArgs;
      if (args is! UpsertFileArgs) return;
      callback(
          ctx,
          args.id,
          args.path,
          args.name,
          args.content,
          args.folderPath,
          args.depth,
          args.extension,
          args.size,
          args.createdTime,
          args.modifiedTime);
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
}
