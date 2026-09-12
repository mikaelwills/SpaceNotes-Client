@Tags(['live'])
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/services/resumable_upload.dart';

/// The behaviour Mikael actually asked for: start an upload, lose the process,
/// come back and continue from where it stopped rather than from zero.
///
/// A killed app is simulated by throwing away every client object mid-transfer
/// and rebuilding from nothing but the session id — which is exactly what a
/// relaunch has after reading its database.
///
/// `flutter test --tags live`
void main() {
  const host = String.fromEnvironment('SPACENOTES_HOST',
      defaultValue: '100.84.184.121');
  const base = 'http://$host:5051';

  test('an upload resumes from the server offset after the process dies',
      () async {
    final scratch = await Directory.systemTemp.createTemp('resume-kill');
    addTearDown(() => scratch.delete(recursive: true));

    final file = File('${scratch.path}/take.wav');
    const size = 16 * 1024 * 1024;
    await file.writeAsBytes(List.generate(size, (i) => (i * 17) % 251));

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final remotePath = '.live-check/killed $stamp.wav';

    // --- first "app launch": send two chunks, then vanish.
    String sessionId;
    int offsetBeforeDeath;
    {
      final dio = Dio();
      final client = ResumableUploadClient(dio, base);
      final session = await client.open(remotePath, size);
      sessionId = session.id;

      var offset = 0;
      for (var i = 0; i < 2; i++) {
        final bytes = await readChunk(file, offset, kUploadChunkBytes);
        offset = await client.sendChunk(session.id, offset, bytes);
      }
      offsetBeforeDeath = offset;
      dio.close(force: true);
    }

    expect(offsetBeforeDeath, 2 * kUploadChunkBytes);
    expect(offsetBeforeDeath, lessThan(size), reason: 'must be mid-transfer');

    // --- second "app launch": everything rebuilt, only the id survived.
    final dio = Dio();
    final client = ResumableUploadClient(dio, base);

    final resumedAt = await client.confirmedOffset(sessionId);
    expect(
      resumedAt,
      offsetBeforeDeath,
      reason: 'the server must remember what the dead process sent',
    );

    var offset = resumedAt;
    var chunksAfterResume = 0;
    while (offset < size) {
      final length =
          offset + kUploadChunkBytes > size ? size - offset : kUploadChunkBytes;
      final bytes = await readChunk(file, offset, length);
      offset = await client.sendChunk(sessionId, offset, bytes);
      chunksAfterResume++;
    }

    expect(offset, size);
    expect(chunksAfterResume, 2,
        reason: 'only the remaining half should be re-sent');

    final encoded = remotePath.split('/').map(Uri.encodeComponent).join('/');
    final download = await dio.get<List<int>>(
      '$base/files/$encoded',
      options: Options(responseType: ResponseType.bytes),
    );

    expect(
      download.data,
      await file.readAsBytes(),
      reason: 'a resumed upload must be byte-identical, not merely complete',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
