// GENERATED REDUCER ARGUMENT CLASSES AND DECODERS - DO NOT MODIFY BY HAND

import 'package:spacetimedb_sdk/codegen.dart';

class AcceptCallArgs {
  AcceptCallArgs({required this.sessionId});

  final Int64 sessionId;
}

class AcceptCallArgsDecoder implements ReducerArgDecoder<AcceptCallArgs> {
  const AcceptCallArgsDecoder();

  @override
  AcceptCallArgs decode(BsatnDecoder decoder) {
    final sessionId = decoder.readU64();
    return AcceptCallArgs(sessionId: sessionId);
  }
}

class AppendToNoteArgs {
  AppendToNoteArgs({required this.path, required this.content});

  final String path;

  final String content;
}

class AppendToNoteArgsDecoder implements ReducerArgDecoder<AppendToNoteArgs> {
  const AppendToNoteArgsDecoder();

  @override
  AppendToNoteArgs decode(BsatnDecoder decoder) {
    final path = decoder.readString();
    final content = decoder.readString();
    return AppendToNoteArgs(path: path, content: content);
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

class ClearAllSessionsArgs {
  ClearAllSessionsArgs();
}

class ClearAllSessionsArgsDecoder
    implements ReducerArgDecoder<ClearAllSessionsArgs> {
  const ClearAllSessionsArgsDecoder();

  @override
  ClearAllSessionsArgs decode(BsatnDecoder decoder) {
    return ClearAllSessionsArgs();
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
    return CreateFolderArgs(path: path, name: name, depth: depth);
  }
}

class CreateNoteArgs {
  CreateNoteArgs({
    required this.id,
    required this.path,
    required this.name,
    required this.content,
    required this.folderPath,
    required this.depth,
    required this.frontmatter,
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

  final String frontmatter;

  final Int64 size;

  final Int64 createdTime;

  final Int64 modifiedTime;
}

class CreateNoteArgsDecoder implements ReducerArgDecoder<CreateNoteArgs> {
  const CreateNoteArgsDecoder();

  @override
  CreateNoteArgs decode(BsatnDecoder decoder) {
    final id = decoder.readString();
    final path = decoder.readString();
    final name = decoder.readString();
    final content = decoder.readString();
    final folderPath = decoder.readString();
    final depth = decoder.readU32();
    final frontmatter = decoder.readString();
    final size = decoder.readU64();
    final createdTime = decoder.readU64();
    final modifiedTime = decoder.readU64();
    return CreateNoteArgs(
      id: id,
      path: path,
      name: name,
      content: content,
      folderPath: folderPath,
      depth: depth,
      frontmatter: frontmatter,
      size: size,
      createdTime: createdTime,
      modifiedTime: modifiedTime,
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
    return DeleteFolderArgs(path: path);
  }
}

class DeleteNoteArgs {
  DeleteNoteArgs({required this.id});

  final String id;
}

class DeleteNoteArgsDecoder implements ReducerArgDecoder<DeleteNoteArgs> {
  const DeleteNoteArgsDecoder();

  @override
  DeleteNoteArgs decode(BsatnDecoder decoder) {
    final id = decoder.readString();
    return DeleteNoteArgs(id: id);
  }
}

class DeleteSessionArgs {
  DeleteSessionArgs({required this.sessionId});

  final String sessionId;
}

class DeleteSessionArgsDecoder implements ReducerArgDecoder<DeleteSessionArgs> {
  const DeleteSessionArgsDecoder();

  @override
  DeleteSessionArgs decode(BsatnDecoder decoder) {
    final sessionId = decoder.readString();
    return DeleteSessionArgs(sessionId: sessionId);
  }
}

class EditMessageArgs {
  EditMessageArgs({required this.id, required this.text});

  final String id;

  final String text;
}

class EditMessageArgsDecoder implements ReducerArgDecoder<EditMessageArgs> {
  const EditMessageArgsDecoder();

  @override
  EditMessageArgs decode(BsatnDecoder decoder) {
    final id = decoder.readString();
    final text = decoder.readString();
    return EditMessageArgs(id: id, text: text);
  }
}

class EndCallArgs {
  EndCallArgs({required this.sessionId});

  final Int64 sessionId;
}

class EndCallArgsDecoder implements ReducerArgDecoder<EndCallArgs> {
  const EndCallArgsDecoder();

  @override
  EndCallArgs decode(BsatnDecoder decoder) {
    final sessionId = decoder.readU64();
    return EndCallArgs(sessionId: sessionId);
  }
}

class EndSessionArgs {
  EndSessionArgs({required this.sessionId});

  final String sessionId;
}

class EndSessionArgsDecoder implements ReducerArgDecoder<EndSessionArgs> {
  const EndSessionArgsDecoder();

  @override
  EndSessionArgs decode(BsatnDecoder decoder) {
    final sessionId = decoder.readString();
    return EndSessionArgs(sessionId: sessionId);
  }
}

class FindReplaceInNoteArgs {
  FindReplaceInNoteArgs({
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

class FindReplaceInNoteArgsDecoder
    implements ReducerArgDecoder<FindReplaceInNoteArgs> {
  const FindReplaceInNoteArgsDecoder();

  @override
  FindReplaceInNoteArgs decode(BsatnDecoder decoder) {
    final path = decoder.readString();
    final oldText = decoder.readString();
    final newText = decoder.readString();
    final replaceAll = decoder.readBool();
    return FindReplaceInNoteArgs(
      path: path,
      oldText: oldText,
      newText: newText,
      replaceAll: replaceAll,
    );
  }
}

class GetRecentNotesArgs {
  GetRecentNotesArgs({required this.limit});

  final int limit;
}

class GetRecentNotesArgsDecoder
    implements ReducerArgDecoder<GetRecentNotesArgs> {
  const GetRecentNotesArgsDecoder();

  @override
  GetRecentNotesArgs decode(BsatnDecoder decoder) {
    final limit = decoder.readU32();
    return GetRecentNotesArgs(limit: limit);
  }
}

class HeartbeatArgs {
  HeartbeatArgs({required this.sessionId});

  final String sessionId;
}

class HeartbeatArgsDecoder implements ReducerArgDecoder<HeartbeatArgs> {
  const HeartbeatArgsDecoder();

  @override
  HeartbeatArgs decode(BsatnDecoder decoder) {
    final sessionId = decoder.readString();
    return HeartbeatArgs(sessionId: sessionId);
  }
}

class MoveFolderArgs {
  MoveFolderArgs({required this.oldPath, required this.newPath});

  final String oldPath;

  final String newPath;
}

class MoveFolderArgsDecoder implements ReducerArgDecoder<MoveFolderArgs> {
  const MoveFolderArgsDecoder();

  @override
  MoveFolderArgs decode(BsatnDecoder decoder) {
    final oldPath = decoder.readString();
    final newPath = decoder.readString();
    return MoveFolderArgs(oldPath: oldPath, newPath: newPath);
  }
}

class MoveNoteArgs {
  MoveNoteArgs({required this.oldPath, required this.newPath});

  final String oldPath;

  final String newPath;
}

class MoveNoteArgsDecoder implements ReducerArgDecoder<MoveNoteArgs> {
  const MoveNoteArgsDecoder();

  @override
  MoveNoteArgs decode(BsatnDecoder decoder) {
    final oldPath = decoder.readString();
    final newPath = decoder.readString();
    return MoveNoteArgs(oldPath: oldPath, newPath: newPath);
  }
}

class PrependToNoteArgs {
  PrependToNoteArgs({required this.path, required this.content});

  final String path;

  final String content;
}

class PrependToNoteArgsDecoder implements ReducerArgDecoder<PrependToNoteArgs> {
  const PrependToNoteArgsDecoder();

  @override
  PrependToNoteArgs decode(BsatnDecoder decoder) {
    final path = decoder.readString();
    final content = decoder.readString();
    return PrependToNoteArgs(path: path, content: content);
  }
}

class PushContextUsageArgs {
  PushContextUsageArgs({
    required this.sessionId,
    required this.used,
    required this.window,
  });

  final String sessionId;

  final Int64 used;

  final Int64 window;
}

class PushContextUsageArgsDecoder
    implements ReducerArgDecoder<PushContextUsageArgs> {
  const PushContextUsageArgsDecoder();

  @override
  PushContextUsageArgs decode(BsatnDecoder decoder) {
    final sessionId = decoder.readString();
    final used = decoder.readU64();
    final window = decoder.readU64();
    return PushContextUsageArgs(
      sessionId: sessionId,
      used: used,
      window: window,
    );
  }
}

class PushImageArgs {
  PushImageArgs({
    required this.id,
    required this.sessionId,
    required this.caption,
    required this.bytes,
  });

  final String id;

  final String sessionId;

  final String caption;

  final List<int> bytes;
}

class PushImageArgsDecoder implements ReducerArgDecoder<PushImageArgs> {
  const PushImageArgsDecoder();

  @override
  PushImageArgs decode(BsatnDecoder decoder) {
    final id = decoder.readString();
    final sessionId = decoder.readString();
    final caption = decoder.readString();
    final bytes = decoder.readByteArray();
    return PushImageArgs(
      id: id,
      sessionId: sessionId,
      caption: caption,
      bytes: bytes,
    );
  }
}

class PushMessageArgs {
  PushMessageArgs({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.text,
    required this.source,
  });

  final String id;

  final String sessionId;

  final String role;

  final String text;

  final String source;
}

class PushMessageArgsDecoder implements ReducerArgDecoder<PushMessageArgs> {
  const PushMessageArgsDecoder();

  @override
  PushMessageArgs decode(BsatnDecoder decoder) {
    final id = decoder.readString();
    final sessionId = decoder.readString();
    final role = decoder.readString();
    final text = decoder.readString();
    final source = decoder.readString();
    return PushMessageArgs(
      id: id,
      sessionId: sessionId,
      role: role,
      text: text,
      source: source,
    );
  }
}

class PushStatusArgs {
  PushStatusArgs({required this.sessionId, required this.state});

  final String sessionId;

  final String state;
}

class PushStatusArgsDecoder implements ReducerArgDecoder<PushStatusArgs> {
  const PushStatusArgsDecoder();

  @override
  PushStatusArgs decode(BsatnDecoder decoder) {
    final sessionId = decoder.readString();
    final state = decoder.readString();
    return PushStatusArgs(sessionId: sessionId, state: state);
  }
}

class PushToolEventArgs {
  PushToolEventArgs({
    required this.id,
    required this.sessionId,
    required this.tool,
    required this.detail,
  });

  final String id;

  final String sessionId;

  final String tool;

  final String detail;
}

class PushToolEventArgsDecoder implements ReducerArgDecoder<PushToolEventArgs> {
  const PushToolEventArgsDecoder();

  @override
  PushToolEventArgs decode(BsatnDecoder decoder) {
    final id = decoder.readString();
    final sessionId = decoder.readString();
    final tool = decoder.readString();
    final detail = decoder.readString();
    return PushToolEventArgs(
      id: id,
      sessionId: sessionId,
      tool: tool,
      detail: detail,
    );
  }
}

class RegisterSessionArgs {
  RegisterSessionArgs({
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

class RegisterSessionArgsDecoder
    implements ReducerArgDecoder<RegisterSessionArgs> {
  const RegisterSessionArgsDecoder();

  @override
  RegisterSessionArgs decode(BsatnDecoder decoder) {
    final id = decoder.readString();
    final baseName = decoder.readString();
    final host = decoder.readString();
    final clientId = decoder.readString();
    return RegisterSessionArgs(
      id: id,
      baseName: baseName,
      host: host,
      clientId: clientId,
    );
  }
}

class RenameNoteArgs {
  RenameNoteArgs({required this.id, required this.newPath});

  final String id;

  final String newPath;
}

class RenameNoteArgsDecoder implements ReducerArgDecoder<RenameNoteArgs> {
  const RenameNoteArgsDecoder();

  @override
  RenameNoteArgs decode(BsatnDecoder decoder) {
    final id = decoder.readString();
    final newPath = decoder.readString();
    return RenameNoteArgs(id: id, newPath: newPath);
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
    return RequestCallArgs(callee: callee);
  }
}

class RequestPermissionArgs {
  RequestPermissionArgs({
    required this.id,
    required this.sessionId,
    required this.tool,
    required this.input,
  });

  final String id;

  final String sessionId;

  final String tool;

  final String input;
}

class RequestPermissionArgsDecoder
    implements ReducerArgDecoder<RequestPermissionArgs> {
  const RequestPermissionArgsDecoder();

  @override
  RequestPermissionArgs decode(BsatnDecoder decoder) {
    final id = decoder.readString();
    final sessionId = decoder.readString();
    final tool = decoder.readString();
    final input = decoder.readString();
    return RequestPermissionArgs(
      id: id,
      sessionId: sessionId,
      tool: tool,
      input: input,
    );
  }
}

class RequestQuestionArgs {
  RequestQuestionArgs({
    required this.id,
    required this.sessionId,
    required this.question,
    required this.header,
    required this.options,
    required this.multiSelect,
  });

  final String id;

  final String sessionId;

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
    final sessionId = decoder.readString();
    final question = decoder.readString();
    final header = decoder.readString();
    final options = decoder.readString();
    final multiSelect = decoder.readBool();
    return RequestQuestionArgs(
      id: id,
      sessionId: sessionId,
      question: question,
      header: header,
      options: options,
      multiSelect: multiSelect,
    );
  }
}

class ResolvePermissionArgs {
  ResolvePermissionArgs({required this.id, required this.status});

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
    return ResolvePermissionArgs(id: id, status: status);
  }
}

class RespondToQuestionArgs {
  RespondToQuestionArgs({required this.id, required this.response});

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
    return RespondToQuestionArgs(id: id, response: response);
  }
}

class SendAudioFrameArgs {
  SendAudioFrameArgs({
    required this.sessionId,
    required this.seq,
    required this.pcm,
  });

  final Int64 sessionId;

  final int seq;

  final List<int> pcm;
}

class SendAudioFrameArgsDecoder
    implements ReducerArgDecoder<SendAudioFrameArgs> {
  const SendAudioFrameArgsDecoder();

  @override
  SendAudioFrameArgs decode(BsatnDecoder decoder) {
    final sessionId = decoder.readU64();
    final seq = decoder.readU32();
    final pcm = decoder.readByteArray();
    return SendAudioFrameArgs(sessionId: sessionId, seq: seq, pcm: pcm);
  }
}

class SendVideoFrameArgs {
  SendVideoFrameArgs({
    required this.sessionId,
    required this.seq,
    required this.codec,
    required this.isKeyframe,
    required this.data,
  });

  final Int64 sessionId;

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
    final sessionId = decoder.readU64();
    final seq = decoder.readU32();
    final codec = decoder.readU8();
    final isKeyframe = decoder.readBool();
    final data = decoder.readByteArray();
    return SendVideoFrameArgs(
      sessionId: sessionId,
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
    return SetDisplayNameArgs(name: name);
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

class UpdateNoteContentArgs {
  UpdateNoteContentArgs({
    required this.id,
    required this.content,
    required this.frontmatter,
    required this.size,
    required this.modifiedTime,
  });

  final String id;

  final String content;

  final String frontmatter;

  final Int64 size;

  final Int64 modifiedTime;
}

class UpdateNoteContentArgsDecoder
    implements ReducerArgDecoder<UpdateNoteContentArgs> {
  const UpdateNoteContentArgsDecoder();

  @override
  UpdateNoteContentArgs decode(BsatnDecoder decoder) {
    final id = decoder.readString();
    final content = decoder.readString();
    final frontmatter = decoder.readString();
    final size = decoder.readU64();
    final modifiedTime = decoder.readU64();
    return UpdateNoteContentArgs(
      id: id,
      content: content,
      frontmatter: frontmatter,
      size: size,
      modifiedTime: modifiedTime,
    );
  }
}

class UpdateNotePathArgs {
  UpdateNotePathArgs({required this.id, required this.newPath});

  final String id;

  final String newPath;
}

class UpdateNotePathArgsDecoder
    implements ReducerArgDecoder<UpdateNotePathArgs> {
  const UpdateNotePathArgsDecoder();

  @override
  UpdateNotePathArgs decode(BsatnDecoder decoder) {
    final id = decoder.readString();
    final newPath = decoder.readString();
    return UpdateNotePathArgs(id: id, newPath: newPath);
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
    return UpsertFolderArgs(path: path, name: name, depth: depth);
  }
}

class UpsertNoteArgs {
  UpsertNoteArgs({
    required this.id,
    required this.path,
    required this.name,
    required this.content,
    required this.folderPath,
    required this.depth,
    required this.frontmatter,
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

  final String frontmatter;

  final Int64 size;

  final Int64 createdTime;

  final Int64 modifiedTime;
}

class UpsertNoteArgsDecoder implements ReducerArgDecoder<UpsertNoteArgs> {
  const UpsertNoteArgsDecoder();

  @override
  UpsertNoteArgs decode(BsatnDecoder decoder) {
    final id = decoder.readString();
    final path = decoder.readString();
    final name = decoder.readString();
    final content = decoder.readString();
    final folderPath = decoder.readString();
    final depth = decoder.readU32();
    final frontmatter = decoder.readString();
    final size = decoder.readU64();
    final createdTime = decoder.readU64();
    final modifiedTime = decoder.readU64();
    return UpsertNoteArgs(
      id: id,
      path: path,
      name: name,
      content: content,
      folderPath: folderPath,
      depth: depth,
      frontmatter: frontmatter,
      size: size,
      createdTime: createdTime,
      modifiedTime: modifiedTime,
    );
  }
}

const acceptCallDef = ReducerDef<AcceptCallArgs>(
  'accept_call',
  AcceptCallArgsDecoder(),
);
const appendToNoteDef = ReducerDef<AppendToNoteArgs>(
  'append_to_note',
  AppendToNoteArgsDecoder(),
);
const clearAllDef = ReducerDef<ClearAllArgs>(
  'clear_all',
  ClearAllArgsDecoder(),
);
const clearAllSessionsDef = ReducerDef<ClearAllSessionsArgs>(
  'clear_all_sessions',
  ClearAllSessionsArgsDecoder(),
);
const createFolderDef = ReducerDef<CreateFolderArgs>(
  'create_folder',
  CreateFolderArgsDecoder(),
);
const createNoteDef = ReducerDef<CreateNoteArgs>(
  'create_note',
  CreateNoteArgsDecoder(),
);
const deleteFolderDef = ReducerDef<DeleteFolderArgs>(
  'delete_folder',
  DeleteFolderArgsDecoder(),
);
const deleteNoteDef = ReducerDef<DeleteNoteArgs>(
  'delete_note',
  DeleteNoteArgsDecoder(),
);
const deleteSessionDef = ReducerDef<DeleteSessionArgs>(
  'delete_session',
  DeleteSessionArgsDecoder(),
);
const editMessageDef = ReducerDef<EditMessageArgs>(
  'edit_message',
  EditMessageArgsDecoder(),
);
const endCallDef = ReducerDef<EndCallArgs>('end_call', EndCallArgsDecoder());
const endSessionDef = ReducerDef<EndSessionArgs>(
  'end_session',
  EndSessionArgsDecoder(),
);
const findReplaceInNoteDef = ReducerDef<FindReplaceInNoteArgs>(
  'find_replace_in_note',
  FindReplaceInNoteArgsDecoder(),
);
const getRecentNotesDef = ReducerDef<GetRecentNotesArgs>(
  'get_recent_notes',
  GetRecentNotesArgsDecoder(),
);
const heartbeatDef = ReducerDef<HeartbeatArgs>(
  'heartbeat',
  HeartbeatArgsDecoder(),
);
const moveFolderDef = ReducerDef<MoveFolderArgs>(
  'move_folder',
  MoveFolderArgsDecoder(),
);
const moveNoteDef = ReducerDef<MoveNoteArgs>(
  'move_note',
  MoveNoteArgsDecoder(),
);
const prependToNoteDef = ReducerDef<PrependToNoteArgs>(
  'prepend_to_note',
  PrependToNoteArgsDecoder(),
);
const pushContextUsageDef = ReducerDef<PushContextUsageArgs>(
  'push_context_usage',
  PushContextUsageArgsDecoder(),
);
const pushImageDef = ReducerDef<PushImageArgs>(
  'push_image',
  PushImageArgsDecoder(),
);
const pushMessageDef = ReducerDef<PushMessageArgs>(
  'push_message',
  PushMessageArgsDecoder(),
);
const pushStatusDef = ReducerDef<PushStatusArgs>(
  'push_status',
  PushStatusArgsDecoder(),
);
const pushToolEventDef = ReducerDef<PushToolEventArgs>(
  'push_tool_event',
  PushToolEventArgsDecoder(),
);
const registerSessionDef = ReducerDef<RegisterSessionArgs>(
  'register_session',
  RegisterSessionArgsDecoder(),
);
const renameNoteDef = ReducerDef<RenameNoteArgs>(
  'rename_note',
  RenameNoteArgsDecoder(),
);
const requestCallDef = ReducerDef<RequestCallArgs>(
  'request_call',
  RequestCallArgsDecoder(),
);
const requestPermissionDef = ReducerDef<RequestPermissionArgs>(
  'request_permission',
  RequestPermissionArgsDecoder(),
);
const requestQuestionDef = ReducerDef<RequestQuestionArgs>(
  'request_question',
  RequestQuestionArgsDecoder(),
);
const resolvePermissionDef = ReducerDef<ResolvePermissionArgs>(
  'resolve_permission',
  ResolvePermissionArgsDecoder(),
);
const respondToQuestionDef = ReducerDef<RespondToQuestionArgs>(
  'respond_to_question',
  RespondToQuestionArgsDecoder(),
);
const sendAudioFrameDef = ReducerDef<SendAudioFrameArgs>(
  'send_audio_frame',
  SendAudioFrameArgsDecoder(),
);
const sendVideoFrameDef = ReducerDef<SendVideoFrameArgs>(
  'send_video_frame',
  SendVideoFrameArgsDecoder(),
);
const setDisplayNameDef = ReducerDef<SetDisplayNameArgs>(
  'set_display_name',
  SetDisplayNameArgsDecoder(),
);
const sweepOldMessagesDef = ReducerDef<SweepOldMessagesArgs>(
  'sweep_old_messages',
  SweepOldMessagesArgsDecoder(),
);
const updateNoteContentDef = ReducerDef<UpdateNoteContentArgs>(
  'update_note_content',
  UpdateNoteContentArgsDecoder(),
);
const updateNotePathDef = ReducerDef<UpdateNotePathArgs>(
  'update_note_path',
  UpdateNotePathArgsDecoder(),
);
const upsertFolderDef = ReducerDef<UpsertFolderArgs>(
  'upsert_folder',
  UpsertFolderArgsDecoder(),
);
const upsertNoteDef = ReducerDef<UpsertNoteArgs>(
  'upsert_note',
  UpsertNoteArgsDecoder(),
);
