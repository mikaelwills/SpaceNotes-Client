import '../generated/space_file.dart';
import 'audio_file_handler.dart';
import 'credential_file_handler.dart';
import 'csv_file_handler.dart';
import 'file_type_handler.dart';
import 'image_file_handler.dart';
import 'markdown_file_handler.dart';
import 'pdf_file_handler.dart';
import 'unknown_file_handler.dart';
import 'video_file_handler.dart';

class FileTypeRegistry {
  const FileTypeRegistry._();

  static const _handlers = <String, FileTypeHandler>{
    'md': MarkdownFileHandler(),
    'gpg': CredentialFileHandler(),
    'jpg': ImageFileHandler('jpg'),
    'jpeg': ImageFileHandler('jpeg'),
    'png': ImageFileHandler('png'),
    'gif': ImageFileHandler('gif'),
    'webp': ImageFileHandler('webp'),
    'heic': ImageFileHandler('heic'),
    'mp3': AudioFileHandler('mp3'),
    'wav': AudioFileHandler('wav'),
    'm4a': AudioFileHandler('m4a'),
    'aac': AudioFileHandler('aac'),
    'flac': AudioFileHandler('flac'),
    'ogg': AudioFileHandler('ogg'),
    'mp4': VideoFileHandler('mp4'),
    'mov': VideoFileHandler('mov'),
    'm4v': VideoFileHandler('m4v'),
    'webm': VideoFileHandler('webm'),
    'pdf': PdfFileHandler(),
    'csv': CsvFileHandler(),
  };

  static const _fallback = UnknownFileHandler();

  static FileTypeHandler forExtension(String extension) =>
      _handlers[extension.toLowerCase()] ?? _fallback;

  static FileTypeHandler forFile(SpaceFile file) => forExtension(file.extension);

  static FileTypeHandler forFileName(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return _fallback;
    return forExtension(name.substring(dot + 1));
  }

  static const uploadableExtensions = <String>{
    'md', 'yaml', 'yml', 'json', 'toml', 'txt',
    'gpg',
    'mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg',
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic',
    'mp4', 'mov', 'm4v', 'webm',
    'pdf', 'csv',
  };

  static bool isHiddenName(String name) => name.startsWith('.');

  static bool isUploadable(String name) {
    if (isHiddenName(name)) return false;
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return false;
    return uploadableExtensions.contains(name.substring(dot + 1).toLowerCase());
  }

  static const credentialStoreRoot = '.password-store';

  static bool isProtectedPath(String path) =>
      path == credentialStoreRoot || path.startsWith('$credentialStoreRoot/');

  static List<FileTypeHandler> get creatableTypes =>
      _handlers.values.where((h) => h.isCreatable).toList();

  static FileTypeHandler get defaultCreatableType => creatableTypes.first;

  static String defaultNewFileName() =>
      defaultCreatableType.newFileTemplate!.defaultName();
}
