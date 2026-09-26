import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/services/vault_link.dart';

void main() {
  group('parseVaultLink', () {
    test('a file link yields its id', () {
      final link = parseVaultLink('spacenotes://file/9dd08811-ed24-4677-a0d3-2461722178b8');
      expect(link, isA<FileLink>());
      expect((link as FileLink).id, '9dd08811-ed24-4677-a0d3-2461722178b8');
    });

    test('a folder link yields its decoded path', () {
      final link = parseVaultLink('spacenotes://folder/Software%20Development/SpaceNotes');
      expect(link, isA<FolderLink>());
      expect((link as FolderLink).path, 'Software Development/SpaceNotes');
    });

    test('a trailing slash on a folder link is ignored', () {
      final link = parseVaultLink('spacenotes://folder/Masters/');
      expect((link as FolderLink).path, 'Masters');
    });

    test('https and http links are web links', () {
      expect(parseVaultLink('https://pub.dev/packages/dio'), isA<WebLink>());
      expect(parseVaultLink('http://100.84.184.121:5051'), isA<WebLink>());
    });

    test('anything else is unrecognised', () {
      expect(parseVaultLink('spacenotes://file/'), isA<UnknownLink>());
      expect(parseVaultLink('spacenotes://file/a/b'), isA<UnknownLink>());
      expect(parseVaultLink('spacenotes://note/abc'), isA<UnknownLink>());
      expect(parseVaultLink('mailto:someone@example.com'), isA<UnknownLink>());
      expect(parseVaultLink('not a link'), isA<UnknownLink>());
    });
  });
}
