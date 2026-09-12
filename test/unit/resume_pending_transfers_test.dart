import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/services/local_download_store.dart';
import 'package:spacenotes_client/services/resume_pending_transfers.dart';

void main() {
  group('PendingTransfers', () {
    test('is empty only when both lists are', () {
      const none = PendingTransfers(uploads: [], downloads: []);
      expect(none.isEmpty, isTrue);
      expect(none.total, 0);

      const withDownload = PendingTransfers(uploads: [], downloads: ['a.wav']);
      expect(withDownload.isEmpty, isFalse);
      expect(withDownload.total, 1);

      const withUpload = PendingTransfers(
        uploads: [
          ResumableUploadRow(
            remotePath: 'Music/a.wav',
            sessionId: 'abc',
            sourcePath: '/tmp/a.wav',
            size: 100,
            sent: 10,
          ),
        ],
        downloads: [],
      );
      expect(withUpload.isEmpty, isFalse);
      expect(withUpload.total, 1);
    });
  });

  group('ResumableUploadRow', () {
    test('fileName is the last path segment', () {
      const nested = ResumableUploadRow(
        remotePath: 'Music/Takes/final mix.wav',
        sessionId: 'abc',
        sourcePath: '/tmp/x',
        size: 1,
        sent: 0,
      );
      expect(nested.fileName, 'final mix.wav');

      const root = ResumableUploadRow(
        remotePath: 'loose.wav',
        sessionId: 'abc',
        sourcePath: '/tmp/x',
        size: 1,
        sent: 0,
      );
      expect(root.fileName, 'loose.wav');
    });
  });
}
