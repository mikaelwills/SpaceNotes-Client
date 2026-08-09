import '../generated/space_file.dart';
import 'credential_file_handler.dart';
import 'file_type_handler.dart';
import 'markdown_file_handler.dart';
import 'unknown_file_handler.dart';

class FileTypeRegistry {
  const FileTypeRegistry._();

  static const _handlers = <String, FileTypeHandler>{
    'md': MarkdownFileHandler(),
    'gpg': CredentialFileHandler(),
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

  static List<FileTypeHandler> get creatableTypes =>
      _handlers.values.where((h) => h.isCreatable).toList();

  static FileTypeHandler get defaultCreatableType => creatableTypes.first;

  static String defaultNewFileName() =>
      defaultCreatableType.newFileTemplate!.defaultName();
}
