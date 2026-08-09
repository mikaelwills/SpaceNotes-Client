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
    expect(h.isRenameable, false);
    expect(h.isEditable, false);
    expect(h.isCreatable, false);
    expect(h.hasTextRepresentation, false);
  });
  test('rename preserves extension', () {
    expect(FileTypeRegistry.forExtension('gpg').applyExtension('x'), 'x.gpg');
    expect(FileTypeRegistry.forExtension('md').applyExtension('x.md'), 'x.md');
  });
  test('only markdown is creatable', () {
    expect(FileTypeRegistry.creatableTypes.map((h) => h.extension), ['md']);
    expect(FileTypeRegistry.defaultNewFileName(), endsWith('.md'));
  });
}
