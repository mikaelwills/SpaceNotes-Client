// GENERATED REDUCER ARGUMENT CLASSES AND DECODERS - DO NOT MODIFY BY HAND

import 'package:spacetimedb_sdk/codegen.dart';

class AcceptCallArgs {
  AcceptCallArgs({required this.callId});

  final Int64 callId;
}

class AcceptCallArgsDecoder implements ReducerArgDecoder<AcceptCallArgs> {
  const AcceptCallArgsDecoder();

  @override
  AcceptCallArgs decode(BsatnDecoder decoder) {
    final callId = decoder.readU64();
    return AcceptCallArgs(
      callId: callId,
    );
  }
}

class AppendToFileArgs {
  AppendToFileArgs({
    required this.path,
    required this.content,
  });

  final String path;

  final String content;
}

class AppendToFileArgsDecoder implements ReducerArgDecoder<AppendToFileArgs> {
  const AppendToFileArgsDecoder();

  @override
  AppendToFileArgs decode(BsatnDecoder decoder) {
    final path = decoder.readString();
    final content = decoder.readString();
    return AppendToFileArgs(
      path: path,
      content: content,
    );
  }
}

class ClearAllArgs {
  ClearAllArgs();
}

class ClearAllArgsDecoder implements ReducerArgDecoder<ClearAllArgs> {
  const ClearAllArgsDecoder();

  @override
  ClearAllArgs decode(BsatnDecoder decoder) {
    return ClearAllArgs();
  }
}

class ClearAllAgentsArgs {
  ClearAllAgentsArgs();
}

class ClearAllAgentsArgsDecoder
    implements ReducerArgDecoder<ClearAllAgentsArgs> {
  const ClearAllAgentsArgsDecoder();

  @override
  ClearAllAgentsArgs decode(BsatnDecoder decoder) {
    return ClearAllAgentsArgs();
  }
}

class CreateFileArgs {
  CreateFileArgs({
    required this.id,
    required this.path,
    required this.name,
    required this.content,
    required this.folderPath,
    required this.depth,
    required this.extension,
    required this.size,
    required this.createdTime,
    required this.modifiedTime,
  });

  final String id;

  final String path;

  final String name;

  final String content;

  final String folderPath;

  final int depth;

  final String extension;

  final Int64 size;

  final Int64 createdTime;

  final Int64 modifiedTime;
}

class CreateFileArgsDecoder implements ReducerArgDecoder<CreateFileArgs> {
  const CreateFileArgsDecoder();

  @override
  CreateFileArgs decode(BsatnDecoder decoder) {
    final id = decoder.readString();
    final path = decoder.readString();
    final name = decoder.readString();
    final content = decoder.readString();
    final folderPath = decoder.readString();
    final depth = decoder.readU32();
    final extension = decoder.readString();
    final size = decoder.readU64();
    final createdTime = decoder.readU64();
    final modifiedTime = decoder.readU64();
    return CreateFileArgs(
      id: id,
      path: path,
      name: name,
      content: content,
      folderPath: folderPath,
      depth: depth,
      extension: extension,
      size: size,
      createdTime: createdTime,
      modifiedTime: modifiedTime,
    );
  }
}

class CreateFolderArgs {
  CreateFolderArgs({
    required this.path,
    required this.name,
    required this.depth,
  });

  final String path;

  final String name;

  final int depth;
}

class CreateFolderArgsDecoder implements ReducerArgDecoder<CreateFolderArgs> {
  const CreateFolderArgsDecoder();

  @override
  CreateFolderArgs decode(BsatnDecoder decoder) {
    final path = decoder.readString();
    final name = decoder.readString();
    final depth = decoder.readU32();
    return CreateFolderArgs(
      path: path,
      name: name,
      depth: depth,
    );
  }
}

class DeleteAgentArgs {
  DeleteAgentArgs({required this.agentId});

  final String agentId;
}

class DeleteAgentArgsDecoder implements ReducerArgDecoder<DeleteAgentArgs> {
  const DeleteAgentArgsDecoder();

  @override
  DeleteAgentArgs decode(BsatnDecoder decoder) {
    final agentId = decoder.readString();
    return DeleteAgentArgs(
      agentId: agentId,
    );
  }
}

class DeleteFileArgs {
  DeleteFileArgs({required this.id});

  final String id;
}

class DeleteFileArgsDecoder implements ReducerArgDecoder<DeleteFileArgs> {
  const DeleteFileArgsDecoder();

  @override
  DeleteFileArgs decode(BsatnDecoder decoder) {
    final id = decoder.readString();
    return DeleteFileArgs(
      id: id,
    );
  }
}

class DeleteFolderArgs {
  DeleteFolderArgs({required this.path});

  final String path;
}

class DeleteFolderArgsDecoder implements ReducerArgDecoder<DeleteFolderArgs> {
  const DeleteFolderArgsDecoder();

  @override
  DeleteFolderArgs decode(BsatnDecoder decoder) {
    final path = decoder.readString();
    return DeleteFolderArgs(
      path: path,
    );
  }
}

class EditMessageArgs {
  EditMessageArgs({
    required this.id,
    required this.text,
  });

  final String id;

  final String text;
}

class EditMessageArgsDecoder implements ReducerArgDecoder<EditMessageArgs> {
  const EditMessageArgsDecoder();

  @override
  EditMessageArgs decode(BsatnDecoder decoder) {
    final id = decoder.readString();
    final text = decoder.readString();
    return EditMessageArgs(
      id: id,
      text: text,
    );
  }
}

class EndAgentArgs {
  EndAgentArgs({required this.agentId});

  final String agentId;
}

class EndAgentArgsDecoder implements ReducerArgDecoder<EndAgentArgs> {
  const EndAgentArgsDecoder();

  @override
  EndAgentArgs decode(BsatnDecoder decoder) {
    final agentId = decoder.readString();
    return EndAgentArgs(
      agentId: agentId,
    );
  }
}

class EndCallArgs {
  EndCallArgs({required this.callId});

  final Int64 callId;
}

class EndCallArgsDecoder implements ReducerArgDecoder<EndCallArgs> {
  const EndCallArgsDecoder();

  @override
  EndCallArgs decode(BsatnDecoder decoder) {
    final callId = decoder.readU64();
    return EndCallArgs(
      callId: callId,
    );
  }
}

class FindReplaceInFileArgs {
  FindReplaceInFileArgs({
    required this.path,
    required this.oldText,
    required this.newText,
    required this.replaceAll,
  });

  final String path;

  final String oldText;

  final String newText;

  final bool replaceAll;
}

class FindReplaceInFileArgsDecoder
    implements ReducerArgDecoder<FindReplaceInFileArgs> {
  const FindReplaceInFileArgsDecoder();

  @override
  FindReplaceInFileArgs decode(BsatnDecoder decoder) {
    final path = decoder.readString();
    final oldText = decoder.readString();
    final newText = decoder.readString();
    final replaceAll = decoder.readBool();
    return FindReplaceInFileArgs(
      path: path,
      oldText: oldText,
      newText: newText,
      replaceAll: replaceAll,
    );
  }
}

class GetRecentFilesArgs {
  GetRecentFilesArgs({required this.limit});

  final int limit;
}

class GetRecentFilesArgsDecoder
    implements ReducerArgDecoder<GetRecentFilesArgs> {
  const GetRecentFilesArgsDecoder();

  @override
  GetRecentFilesArgs decode(BsatnDecoder decoder) {
    final limit = decoder.readU32();
    return GetRecentFilesArgs(
      limit: limit,
    );
  }
}

class HeartbeatArgs {
  HeartbeatArgs({required this.agentId});

  final String agentId;
}

class HeartbeatArgsDecoder implements ReducerArgDecoder<HeartbeatArgs> {
  const HeartbeatArgsDecoder();

  @override
  HeartbeatArgs decode(BsatnDecoder decoder) {
    final agentId = decoder.readString();
    return HeartbeatArgs(
      agentId: agentId,
    );
  }
}

class MoveFileArgs {
  MoveFileArgs({
    required this.oldPath,
    required this.newPath,
  });

  final String oldPath;

  final String newPath;
}

class MoveFileArgsDecoder implements ReducerArgDecoder<MoveFileArgs> {
  const MoveFileArgsDecoder();

  @override
  MoveFileArgs decode(BsatnDecoder decoder) {
    final oldPath = decoder.readString();
    final newPath = decoder.readString();
    return MoveFileArgs(
      oldPath: oldPath,
      newPath: newPath,
    );
  }
}

class MoveFolderArgs {
  MoveFolderArgs({
    required this.oldPath,
    required this.newPath,
  });

  final String oldPath;

  final String newPath;
}

class MoveFolderArgsDecoder implements ReducerArgDecoder<MoveFolderArgs> {
  const MoveFolderArgsDecoder();

  @override
  MoveFolderArgs decode(BsatnDecoder decoder) {
    final oldPath = decoder.readString();
    final newPath = decoder.readString();
    return MoveFolderArgs(
      oldPath: oldPath,
      newPath: newPath,
    );
  }
}

class PrependToFileArgs {
  PrependToFileArgs({
    required this.path,
    required this.content,
  });

  final String path;

  final String content;
}

class PrependToFileArgsDecoder implements ReducerArgDecoder<PrependToFileArgs> {
  const PrependToFileArgsDecoder();

  @override
  PrependToFileArgs decode(BsatnDecoder decoder) {
    final path = decoder.readString();
    final content = decoder.readString();
    return PrependToFileArgs(
      path: path,
      content: content,
    );
  }
}

class PushContextUsageArgs {
  PushContextUsageArgs({
    required this.agentId,
    required this.used,
    required this.window,
  });

  final String agentId;

  final Int64 used;

  final Int64 window;
}

class PushContextUsageArgsDecoder
    implements ReducerArgDecoder<PushContextUsageArgs> {
  const PushContextUsageArgsDecoder();

  @override
  PushContextUsageArgs decode(BsatnDecoder decoder) {
    final agentId = decoder.readString();
    final used = decoder.readU64();
    final window = decoder.readU64();
    return PushContextUsageArgs(
      agentId: agentId,
      used: used,
      window: window,
    );
  }
}

class PushImageArgs {
  PushImageArgs({
    required this.id,
    required this.agentId,
    required this.caption,
    required this.bytes,
  });

  final String id;

  final String agentId;

  final String caption;

  final List<int> bytes;
}

class PushImageArgsDecoder implements ReducerArgDecoder<PushImageArgs> {
  const PushImageArgsDecoder();

  @override
  PushImageArgs decode(BsatnDecoder decoder) {
    final id = decoder.readString();
    final agentId = decoder.readString();
    final caption = decoder.readString();
    final bytes = decoder.readByteArray();
    return PushImageArgs(
      id: id,
      agentId: agentId,
      caption: caption,
      bytes: bytes,
    );
  }
}

class PushMessageArgs {
  PushMessageArgs({
    required this.id,
    required this.agentId,
    required this.role,
    required this.text,
    required this.source,
  });

  final String id;

  final String agentId;

  final String role;

  final String text;

  final String source;
}

class PushMessageArgsDecoder implements ReducerArgDecoder<PushMessageArgs> {
  const PushMessageArgsDecoder();

  @override
  PushMessageArgs decode(BsatnDecoder decoder) {
    final id = decoder.readString();
    final agentId = decoder.readString();
    final role = decoder.readString();
    final text = decoder.readString();
    final source = decoder.readString();
    return PushMessageArgs(
      id: id,
      agentId: agentId,
      role: role,
      text: text,
      source: source,
    );
  }
}

class PushStatusArgs {
  PushStatusArgs({
    required this.agentId,
    required this.state,
  });

  final String agentId;

  final String state;
}

class PushStatusArgsDecoder implements ReducerArgDecoder<PushStatusArgs> {
  const PushStatusArgsDecoder();

  @override
  PushStatusArgs decode(BsatnDecoder decoder) {
    final agentId = decoder.readString();
    final state = decoder.readString();
    return PushStatusArgs(
      agentId: agentId,
      state: state,
    );
  }
}

class PushToolEventArgs {
  PushToolEventArgs({
    required this.id,
    required this.agentId,
    required this.tool,
    required this.detail,
  });

  final String id;

  final String agentId;

  final String tool;

  final String detail;
}

class PushToolEventArgsDecoder implements ReducerArgDecoder<PushToolEventArgs> {
  const PushToolEventArgsDecoder();

  @override
  PushToolEventArgs decode(BsatnDecoder decoder) {
    final id = decoder.readString();
    final agentId = decoder.readString();
    final tool = decoder.readString();
    final detail = decoder.readString();
    return PushToolEventArgs(
      id: id,
      agentId: agentId,
      tool: tool,
      detail: detail,
    );
  }
}

class RegisterAgentArgs {
  RegisterAgentArgs({
    required this.id,
    required this.baseName,
    required this.host,
    required this.clientId,
  });

  final String id;

  final String baseName;

  final String host;

  final String clientId;
}

class RegisterAgentArgsDecoder implements ReducerArgDecoder<RegisterAgentArgs> {
  const RegisterAgentArgsDecoder();

  @override
  RegisterAgentArgs decode(BsatnDecoder decoder) {
    final id = decoder.readString();
    final baseName = decoder.readString();
    final host = decoder.readString();
    final clientId = decoder.readString();
    return RegisterAgentArgs(
      id: id,
      baseName: baseName,
      host: host,
      clientId: clientId,
    );
  }
}

class RenameFileArgs {
  RenameFileArgs({
    required this.id,
    required this.newPath,
  });

  final String id;

  final String newPath;
}

class RenameFileArgsDecoder implements ReducerArgDecoder<RenameFileArgs> {
  const RenameFileArgsDecoder();

  @override
  RenameFileArgs decode(BsatnDecoder decoder) {
    final id = decoder.readString();
    final newPath = decoder.readString();
    return RenameFileArgs(
      id: id,
      newPath: newPath,
    );
  }
}

class RequestCallArgs {
  RequestCallArgs({required this.callee});

  final Identity callee;
}

class RequestCallArgsDecoder implements ReducerArgDecoder<RequestCallArgs> {
  const RequestCallArgsDecoder();

  @override
  RequestCallArgs decode(BsatnDecoder decoder) {
    final callee = decoder.readIdentity();
    return RequestCallArgs(
      callee: callee,
    );
  }
}

class RequestPermissionArgs {
  RequestPermissionArgs({
    required this.id,
    required this.agentId,
    required this.tool,
    required this.input,
  });

  final String id;

  final String agentId;

  final String tool;

  final String input;
}

class RequestPermissionArgsDecoder
    implements ReducerArgDecoder<RequestPermissionArgs> {
  const RequestPermissionArgsDecoder();

  @override
  RequestPermissionArgs decode(BsatnDecoder decoder) {
    final id = decoder.readString();
    final agentId = decoder.readString();
    final tool = decoder.readString();
    final input = decoder.readString();
    return RequestPermissionArgs(
      id: id,
      agentId: agentId,
      tool: tool,
      input: input,
    );
  }
}

class RequestQuestionArgs {
  RequestQuestionArgs({
    required this.id,
    required this.agentId,
    required this.question,
    required this.header,
    required this.options,
    required this.multiSelect,
  });

  final String id;

  final String agentId;

  final String question;

  final String header;

  final String options;

  final bool multiSelect;
}

class RequestQuestionArgsDecoder
    implements ReducerArgDecoder<RequestQuestionArgs> {
  const RequestQuestionArgsDecoder();

  @override
  RequestQuestionArgs decode(BsatnDecoder decoder) {
    final id = decoder.readString();
    final agentId = decoder.readString();
    final question = decoder.readString();
    final header = decoder.readString();
    final options = decoder.readString();
    final multiSelect = decoder.readBool();
    return RequestQuestionArgs(
      id: id,
      agentId: agentId,
      question: question,
      header: header,
      options: options,
      multiSelect: multiSelect,
    );
  }
}

class ResolvePermissionArgs {
  ResolvePermissionArgs({
    required this.id,
    required this.status,
  });

  final String id;

  final String status;
}

class ResolvePermissionArgsDecoder
    implements ReducerArgDecoder<ResolvePermissionArgs> {
  const ResolvePermissionArgsDecoder();

  @override
  ResolvePermissionArgs decode(BsatnDecoder decoder) {
    final id = decoder.readString();
    final status = decoder.readString();
    return ResolvePermissionArgs(
      id: id,
      status: status,
    );
  }
}

class RespondToQuestionArgs {
  RespondToQuestionArgs({
    required this.id,
    required this.response,
  });

  final String id;

  final String response;
}

class RespondToQuestionArgsDecoder
    implements ReducerArgDecoder<RespondToQuestionArgs> {
  const RespondToQuestionArgsDecoder();

  @override
  RespondToQuestionArgs decode(BsatnDecoder decoder) {
    final id = decoder.readString();
    final response = decoder.readString();
    return RespondToQuestionArgs(
      id: id,
      response: response,
    );
  }
}

class SendAudioFrameArgs {
  SendAudioFrameArgs({
    required this.callId,
    required this.seq,
    required this.pcm,
  });

  final Int64 callId;

  final int seq;

  final List<int> pcm;
}

class SendAudioFrameArgsDecoder
    implements ReducerArgDecoder<SendAudioFrameArgs> {
  const SendAudioFrameArgsDecoder();

  @override
  SendAudioFrameArgs decode(BsatnDecoder decoder) {
    final callId = decoder.readU64();
    final seq = decoder.readU32();
    final pcm = decoder.readByteArray();
    return SendAudioFrameArgs(
      callId: callId,
      seq: seq,
      pcm: pcm,
    );
  }
}

class SendVideoFrameArgs {
  SendVideoFrameArgs({
    required this.callId,
    required this.seq,
    required this.codec,
    required this.isKeyframe,
    required this.data,
  });

  final Int64 callId;

  final int seq;

  final int codec;

  final bool isKeyframe;

  final List<int> data;
}

class SendVideoFrameArgsDecoder
    implements ReducerArgDecoder<SendVideoFrameArgs> {
  const SendVideoFrameArgsDecoder();

  @override
  SendVideoFrameArgs decode(BsatnDecoder decoder) {
    final callId = decoder.readU64();
    final seq = decoder.readU32();
    final codec = decoder.readU8();
    final isKeyframe = decoder.readBool();
    final data = decoder.readByteArray();
    return SendVideoFrameArgs(
      callId: callId,
      seq: seq,
      codec: codec,
      isKeyframe: isKeyframe,
      data: data,
    );
  }
}

class SetDisplayNameArgs {
  SetDisplayNameArgs({required this.name});

  final String name;
}

class SetDisplayNameArgsDecoder
    implements ReducerArgDecoder<SetDisplayNameArgs> {
  const SetDisplayNameArgsDecoder();

  @override
  SetDisplayNameArgs decode(BsatnDecoder decoder) {
    final name = decoder.readString();
    return SetDisplayNameArgs(
      name: name,
    );
  }
}

class SweepOldMessagesArgs {
  SweepOldMessagesArgs();
}

class SweepOldMessagesArgsDecoder
    implements ReducerArgDecoder<SweepOldMessagesArgs> {
  const SweepOldMessagesArgsDecoder();

  @override
  SweepOldMessagesArgs decode(BsatnDecoder decoder) {
    return SweepOldMessagesArgs();
  }
}

class UpdateFileContentArgs {
  UpdateFileContentArgs({
    required this.id,
    required this.content,
    required this.size,
    required this.modifiedTime,
  });

  final String id;

  final String content;

  final Int64 size;

  final Int64 modifiedTime;
}

class UpdateFileContentArgsDecoder
    implements ReducerArgDecoder<UpdateFileContentArgs> {
  const UpdateFileContentArgsDecoder();

  @override
  UpdateFileContentArgs decode(BsatnDecoder decoder) {
    final id = decoder.readString();
    final content = decoder.readString();
    final size = decoder.readU64();
    final modifiedTime = decoder.readU64();
    return UpdateFileContentArgs(
      id: id,
      content: content,
      size: size,
      modifiedTime: modifiedTime,
    );
  }
}

class UpdateFilePathArgs {
  UpdateFilePathArgs({
    required this.id,
    required this.newPath,
  });

  final String id;

  final String newPath;
}

class UpdateFilePathArgsDecoder
    implements ReducerArgDecoder<UpdateFilePathArgs> {
  const UpdateFilePathArgsDecoder();

  @override
  UpdateFilePathArgs decode(BsatnDecoder decoder) {
    final id = decoder.readString();
    final newPath = decoder.readString();
    return UpdateFilePathArgs(
      id: id,
      newPath: newPath,
    );
  }
}

class UpsertFileArgs {
  UpsertFileArgs({
    required this.id,
    required this.path,
    required this.name,
    required this.content,
    required this.folderPath,
    required this.depth,
    required this.extension,
    required this.size,
    required this.createdTime,
    required this.modifiedTime,
  });

  final String id;

  final String path;

  final String name;

  final String content;

  final String folderPath;

  final int depth;

  final String extension;

  final Int64 size;

  final Int64 createdTime;

  final Int64 modifiedTime;
}

class UpsertFileArgsDecoder implements ReducerArgDecoder<UpsertFileArgs> {
  const UpsertFileArgsDecoder();

  @override
  UpsertFileArgs decode(BsatnDecoder decoder) {
    final id = decoder.readString();
    final path = decoder.readString();
    final name = decoder.readString();
    final content = decoder.readString();
    final folderPath = decoder.readString();
    final depth = decoder.readU32();
    final extension = decoder.readString();
    final size = decoder.readU64();
    final createdTime = decoder.readU64();
    final modifiedTime = decoder.readU64();
    return UpsertFileArgs(
      id: id,
      path: path,
      name: name,
      content: content,
      folderPath: folderPath,
      depth: depth,
      extension: extension,
      size: size,
      createdTime: createdTime,
      modifiedTime: modifiedTime,
    );
  }
}

class UpsertFolderArgs {
  UpsertFolderArgs({
    required this.path,
    required this.name,
    required this.depth,
  });

  final String path;

  final String name;

  final int depth;
}

class UpsertFolderArgsDecoder implements ReducerArgDecoder<UpsertFolderArgs> {
  const UpsertFolderArgsDecoder();

  @override
  UpsertFolderArgs decode(BsatnDecoder decoder) {
    final path = decoder.readString();
    final name = decoder.readString();
    final depth = decoder.readU32();
    return UpsertFolderArgs(
      path: path,
      name: name,
      depth: depth,
    );
  }
}

const acceptCallDef =
    ReducerDef<AcceptCallArgs>('accept_call', AcceptCallArgsDecoder());
const appendToFileDef =
    ReducerDef<AppendToFileArgs>('append_to_file', AppendToFileArgsDecoder());
const clearAllDef =
    ReducerDef<ClearAllArgs>('clear_all', ClearAllArgsDecoder());
const clearAllAgentsDef = ReducerDef<ClearAllAgentsArgs>(
    'clear_all_agents', ClearAllAgentsArgsDecoder());
const createFileDef =
    ReducerDef<CreateFileArgs>('create_file', CreateFileArgsDecoder());
const createFolderDef =
    ReducerDef<CreateFolderArgs>('create_folder', CreateFolderArgsDecoder());
const deleteAgentDef =
    ReducerDef<DeleteAgentArgs>('delete_agent', DeleteAgentArgsDecoder());
const deleteFileDef =
    ReducerDef<DeleteFileArgs>('delete_file', DeleteFileArgsDecoder());
const deleteFolderDef =
    ReducerDef<DeleteFolderArgs>('delete_folder', DeleteFolderArgsDecoder());
const editMessageDef =
    ReducerDef<EditMessageArgs>('edit_message', EditMessageArgsDecoder());
const endAgentDef =
    ReducerDef<EndAgentArgs>('end_agent', EndAgentArgsDecoder());
const endCallDef = ReducerDef<EndCallArgs>('end_call', EndCallArgsDecoder());
const findReplaceInFileDef = ReducerDef<FindReplaceInFileArgs>(
    'find_replace_in_file', FindReplaceInFileArgsDecoder());
const getRecentFilesDef = ReducerDef<GetRecentFilesArgs>(
    'get_recent_files', GetRecentFilesArgsDecoder());
const heartbeatDef =
    ReducerDef<HeartbeatArgs>('heartbeat', HeartbeatArgsDecoder());
const moveFileDef =
    ReducerDef<MoveFileArgs>('move_file', MoveFileArgsDecoder());
const moveFolderDef =
    ReducerDef<MoveFolderArgs>('move_folder', MoveFolderArgsDecoder());
const prependToFileDef = ReducerDef<PrependToFileArgs>(
    'prepend_to_file', PrependToFileArgsDecoder());
const pushContextUsageDef = ReducerDef<PushContextUsageArgs>(
    'push_context_usage', PushContextUsageArgsDecoder());
const pushImageDef =
    ReducerDef<PushImageArgs>('push_image', PushImageArgsDecoder());
const pushMessageDef =
    ReducerDef<PushMessageArgs>('push_message', PushMessageArgsDecoder());
const pushStatusDef =
    ReducerDef<PushStatusArgs>('push_status', PushStatusArgsDecoder());
const pushToolEventDef = ReducerDef<PushToolEventArgs>(
    'push_tool_event', PushToolEventArgsDecoder());
const registerAgentDef =
    ReducerDef<RegisterAgentArgs>('register_agent', RegisterAgentArgsDecoder());
const renameFileDef =
    ReducerDef<RenameFileArgs>('rename_file', RenameFileArgsDecoder());
const requestCallDef =
    ReducerDef<RequestCallArgs>('request_call', RequestCallArgsDecoder());
const requestPermissionDef = ReducerDef<RequestPermissionArgs>(
    'request_permission', RequestPermissionArgsDecoder());
const requestQuestionDef = ReducerDef<RequestQuestionArgs>(
    'request_question', RequestQuestionArgsDecoder());
const resolvePermissionDef = ReducerDef<ResolvePermissionArgs>(
    'resolve_permission', ResolvePermissionArgsDecoder());
const respondToQuestionDef = ReducerDef<RespondToQuestionArgs>(
    'respond_to_question', RespondToQuestionArgsDecoder());
const sendAudioFrameDef = ReducerDef<SendAudioFrameArgs>(
    'send_audio_frame', SendAudioFrameArgsDecoder());
const sendVideoFrameDef = ReducerDef<SendVideoFrameArgs>(
    'send_video_frame', SendVideoFrameArgsDecoder());
const setDisplayNameDef = ReducerDef<SetDisplayNameArgs>(
    'set_display_name', SetDisplayNameArgsDecoder());
const sweepOldMessagesDef = ReducerDef<SweepOldMessagesArgs>(
    'sweep_old_messages', SweepOldMessagesArgsDecoder());
const updateFileContentDef = ReducerDef<UpdateFileContentArgs>(
    'update_file_content', UpdateFileContentArgsDecoder());
const updateFilePathDef = ReducerDef<UpdateFilePathArgs>(
    'update_file_path', UpdateFilePathArgsDecoder());
const upsertFileDef =
    ReducerDef<UpsertFileArgs>('upsert_file', UpsertFileArgsDecoder());
const upsertFolderDef =
    ReducerDef<UpsertFolderArgs>('upsert_folder', UpsertFolderArgsDecoder());
