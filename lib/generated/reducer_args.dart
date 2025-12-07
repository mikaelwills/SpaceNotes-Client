// GENERATED REDUCER ARGUMENT CLASSES AND DECODERS - DO NOT MODIFY BY HAND

import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart';

/// Arguments for the clear_all reducer
class ClearAllArgs {
  ClearAllArgs();
}

/// Decoder for clear_all reducer arguments
class ClearAllArgsDecoder implements ReducerArgDecoder<ClearAllArgs> {
  @override
  ClearAllArgs? decode(BsatnDecoder decoder) {
    try {

      return ClearAllArgs(
      );
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

/// Arguments for the create_folder reducer
class CreateFolderArgs {
  final String path;
  final String name;
  final int depth;
  CreateFolderArgs({required this.path, required this.name, required this.depth, });
}

/// Decoder for create_folder reducer arguments
class CreateFolderArgsDecoder implements ReducerArgDecoder<CreateFolderArgs> {
  @override
  CreateFolderArgs? decode(BsatnDecoder decoder) {
    try {
      final path = decoder.readString();
      final name = decoder.readString();
      final depth = decoder.readU32();

      return CreateFolderArgs(
        path: path,
        name: name,
        depth: depth,
      );
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

/// Arguments for the create_note reducer
class CreateNoteArgs {
  final String id;
  final String path;
  final String name;
  final String content;
  final String folderPath;
  final int depth;
  final String frontmatter;
  final int size;
  final int createdTime;
  final int modifiedTime;
  CreateNoteArgs({required this.id, required this.path, required this.name, required this.content, required this.folderPath, required this.depth, required this.frontmatter, required this.size, required this.createdTime, required this.modifiedTime, });
}

/// Decoder for create_note reducer arguments
class CreateNoteArgsDecoder implements ReducerArgDecoder<CreateNoteArgs> {
  @override
  CreateNoteArgs? decode(BsatnDecoder decoder) {
    try {
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
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

/// Arguments for the delete_folder reducer
class DeleteFolderArgs {
  final String path;
  DeleteFolderArgs({required this.path, });
}

/// Decoder for delete_folder reducer arguments
class DeleteFolderArgsDecoder implements ReducerArgDecoder<DeleteFolderArgs> {
  @override
  DeleteFolderArgs? decode(BsatnDecoder decoder) {
    try {
      final path = decoder.readString();

      return DeleteFolderArgs(
        path: path,
      );
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

/// Arguments for the delete_note reducer
class DeleteNoteArgs {
  final String id;
  DeleteNoteArgs({required this.id, });
}

/// Decoder for delete_note reducer arguments
class DeleteNoteArgsDecoder implements ReducerArgDecoder<DeleteNoteArgs> {
  @override
  DeleteNoteArgs? decode(BsatnDecoder decoder) {
    try {
      final id = decoder.readString();

      return DeleteNoteArgs(
        id: id,
      );
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

/// Arguments for the get_recent_notes reducer
class GetRecentNotesArgs {
  final int limit;
  GetRecentNotesArgs({required this.limit, });
}

/// Decoder for get_recent_notes reducer arguments
class GetRecentNotesArgsDecoder implements ReducerArgDecoder<GetRecentNotesArgs> {
  @override
  GetRecentNotesArgs? decode(BsatnDecoder decoder) {
    try {
      final limit = decoder.readU32();

      return GetRecentNotesArgs(
        limit: limit,
      );
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

/// Arguments for the identity_connected reducer
class IdentityConnectedArgs {
  IdentityConnectedArgs();
}

/// Decoder for identity_connected reducer arguments
class IdentityConnectedArgsDecoder implements ReducerArgDecoder<IdentityConnectedArgs> {
  @override
  IdentityConnectedArgs? decode(BsatnDecoder decoder) {
    try {

      return IdentityConnectedArgs(
      );
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

/// Arguments for the identity_disconnected reducer
class IdentityDisconnectedArgs {
  IdentityDisconnectedArgs();
}

/// Decoder for identity_disconnected reducer arguments
class IdentityDisconnectedArgsDecoder implements ReducerArgDecoder<IdentityDisconnectedArgs> {
  @override
  IdentityDisconnectedArgs? decode(BsatnDecoder decoder) {
    try {

      return IdentityDisconnectedArgs(
      );
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

/// Arguments for the init reducer
class InitArgs {
  InitArgs();
}

/// Decoder for init reducer arguments
class InitArgsDecoder implements ReducerArgDecoder<InitArgs> {
  @override
  InitArgs? decode(BsatnDecoder decoder) {
    try {

      return InitArgs(
      );
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

/// Arguments for the move_folder reducer
class MoveFolderArgs {
  final String oldPath;
  final String newPath;
  MoveFolderArgs({required this.oldPath, required this.newPath, });
}

/// Decoder for move_folder reducer arguments
class MoveFolderArgsDecoder implements ReducerArgDecoder<MoveFolderArgs> {
  @override
  MoveFolderArgs? decode(BsatnDecoder decoder) {
    try {
      final oldPath = decoder.readString();
      final newPath = decoder.readString();

      return MoveFolderArgs(
        oldPath: oldPath,
        newPath: newPath,
      );
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

/// Arguments for the move_note reducer
class MoveNoteArgs {
  final String oldPath;
  final String newPath;
  MoveNoteArgs({required this.oldPath, required this.newPath, });
}

/// Decoder for move_note reducer arguments
class MoveNoteArgsDecoder implements ReducerArgDecoder<MoveNoteArgs> {
  @override
  MoveNoteArgs? decode(BsatnDecoder decoder) {
    try {
      final oldPath = decoder.readString();
      final newPath = decoder.readString();

      return MoveNoteArgs(
        oldPath: oldPath,
        newPath: newPath,
      );
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

/// Arguments for the rename_note reducer
class RenameNoteArgs {
  final String id;
  final String newPath;
  RenameNoteArgs({required this.id, required this.newPath, });
}

/// Decoder for rename_note reducer arguments
class RenameNoteArgsDecoder implements ReducerArgDecoder<RenameNoteArgs> {
  @override
  RenameNoteArgs? decode(BsatnDecoder decoder) {
    try {
      final id = decoder.readString();
      final newPath = decoder.readString();

      return RenameNoteArgs(
        id: id,
        newPath: newPath,
      );
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

/// Arguments for the update_note_content reducer
class UpdateNoteContentArgs {
  final String id;
  final String content;
  final String frontmatter;
  final int size;
  final int modifiedTime;
  UpdateNoteContentArgs({required this.id, required this.content, required this.frontmatter, required this.size, required this.modifiedTime, });
}

/// Decoder for update_note_content reducer arguments
class UpdateNoteContentArgsDecoder implements ReducerArgDecoder<UpdateNoteContentArgs> {
  @override
  UpdateNoteContentArgs? decode(BsatnDecoder decoder) {
    try {
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
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

/// Arguments for the update_note_path reducer
class UpdateNotePathArgs {
  final String id;
  final String newPath;
  UpdateNotePathArgs({required this.id, required this.newPath, });
}

/// Decoder for update_note_path reducer arguments
class UpdateNotePathArgsDecoder implements ReducerArgDecoder<UpdateNotePathArgs> {
  @override
  UpdateNotePathArgs? decode(BsatnDecoder decoder) {
    try {
      final id = decoder.readString();
      final newPath = decoder.readString();

      return UpdateNotePathArgs(
        id: id,
        newPath: newPath,
      );
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

/// Arguments for the upsert_folder reducer
class UpsertFolderArgs {
  final String path;
  final String name;
  final int depth;
  UpsertFolderArgs({required this.path, required this.name, required this.depth, });
}

/// Decoder for upsert_folder reducer arguments
class UpsertFolderArgsDecoder implements ReducerArgDecoder<UpsertFolderArgs> {
  @override
  UpsertFolderArgs? decode(BsatnDecoder decoder) {
    try {
      final path = decoder.readString();
      final name = decoder.readString();
      final depth = decoder.readU32();

      return UpsertFolderArgs(
        path: path,
        name: name,
        depth: depth,
      );
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

/// Arguments for the upsert_note reducer
class UpsertNoteArgs {
  final String id;
  final String path;
  final String name;
  final String content;
  final String folderPath;
  final int depth;
  final String frontmatter;
  final int size;
  final int createdTime;
  final int modifiedTime;
  UpsertNoteArgs({required this.id, required this.path, required this.name, required this.content, required this.folderPath, required this.depth, required this.frontmatter, required this.size, required this.createdTime, required this.modifiedTime, });
}

/// Decoder for upsert_note reducer arguments
class UpsertNoteArgsDecoder implements ReducerArgDecoder<UpsertNoteArgs> {
  @override
  UpsertNoteArgs? decode(BsatnDecoder decoder) {
    try {
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
    } catch (e) {
      return null; // Deserialization failed
    }
  }
}

