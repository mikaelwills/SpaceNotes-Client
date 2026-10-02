import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/file_types/file_type_registry.dart';

void main() {
  test('extension routing', () {
    expect(FileTypeRegistry.forExtension('md').extension, 'md');
    expect(FileTypeRegistry.forExtension('gpg').extension, 'gpg');
    expect(FileTypeRegistry.forExtension('asc').extension, '');
    expect(FileTypeRegistry.forFileName('.gpg-id').extension, '');
    expect(FileTypeRegistry.forFileName('a/b.gpg').extension, 'gpg');
  });
  test('gpg is locked down', () {
    final h = FileTypeRegistry.forExtension('gpg');
    expect(h.isDeletable, false);
    expect(h.isMovable, false);
    expect(h.hasContextActions, false);
    expect(h.isRenameable, false);
    expect(h.isEditable, false);
    expect(h.isCreatable, false);
    expect(h.hasTextRepresentation, false);
  });
  test('csv is a downloadable binary like pdf', () {
    final h = FileTypeRegistry.forExtension('csv');
    expect(h.extension, 'csv');
    expect(h.isOffloadable, true);
    expect(h.isEditable, false);
    expect(h.isCreatable, false);
    expect(h.hasContextActions, true);
    expect(FileTypeRegistry.forFileName('data/export.CSV').extension, 'csv');
  });
  test('markdown still has context actions', () {
    expect(FileTypeRegistry.forExtension('md').hasContextActions, true);
  });
  test('password store paths are protected', () {
    expect(FileTypeRegistry.isProtectedPath('.password-store'), true);
    expect(FileTypeRegistry.isProtectedPath('.password-store/github.com'), true);
    expect(
        FileTypeRegistry.isProtectedPath('.password-store/a/b.gpg'), true);
    expect(FileTypeRegistry.isProtectedPath('All Notes'), false);
    expect(FileTypeRegistry.isProtectedPath('.password-store-other'), false);
  });
  test('rename preserves extension', () {
    expect(FileTypeRegistry.forExtension('gpg').applyExtension('x'), 'x.gpg');
    expect(FileTypeRegistry.forExtension('md').applyExtension('x.md'), 'x.md');
  });
  test('uploadable mirrors the daemon allowlist', () {
    for (final name in [
      'a.md', 'b.PDF', 'c.heic', 'd.wav', 'e.json', 'f.txt', 'g.csv',
    ]) {
      expect(FileTypeRegistry.isUploadable(name), true, reason: name);
    }
    for (final name in ['x.exe', 'x.docx', 'x', 'x.', '.DS_Store']) {
      expect(FileTypeRegistry.isUploadable(name), false, reason: name);
    }
    expect(FileTypeRegistry.isHiddenName('.DS_Store'), true);
    expect(FileTypeRegistry.isHiddenName('a.md'), false);
  });
  test('only markdown is creatable', () {
    expect(FileTypeRegistry.creatableTypes.map((h) => h.extension), ['md']);
    expect(FileTypeRegistry.defaultNewFileName(), endsWith('.md'));
  });
}
