import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/services/folder_upload.dart';

void main() {
  test('unsupported files are reported, hidden files are dropped silently', () {
    final partition = partitionUploads([
      File('/tmp/a.jpg'),
      File('/tmp/data.csv'),
      File('/tmp/.DS_Store'),
      File('/tmp/notes.md'),
      File('/tmp/setup.exe'),
    ]);
    expect(
      partition.supported.map((f) => f.uri.pathSegments.last),
      ['a.jpg', 'notes.md'],
    );
    expect(partition.unsupported, ['data.csv', 'setup.exe']);
  });

  test('a result with only unsupported files has nothing else to report', () {
    const result = FolderUploadResult(
      skipped: [],
      failed: [],
      unsupported: ['data.csv'],
    );
    expect(result.hasUnsupported, true);
    expect(result.hasSkipped, false);
    expect(result.hasFailed, false);
  });
}
