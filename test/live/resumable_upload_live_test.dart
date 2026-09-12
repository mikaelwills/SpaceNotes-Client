@Tags(['live'])
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/services/resumable_upload.dart';

/// Drives the real client against the deployed daemon.
///
/// The unit tests use a fake server, which proves the client is self-consistent
/// but not that it agrees with the daemon. Excluded from the default run
/// because it needs the NAS: `flutter test --tags live`.
void main() {
  const host = String.fromEnvironment('SPACENOTES_HOST',
      defaultValue: '100.84.184.121');
  const base = 'http://$host:5051';

  test('a chunked upload lands byte-identical on the live daemon', () async {
    final dio = Dio();
    final client = ResumableUploadClient(dio, base);

    final scratch = await Directory.systemTemp.createTemp('live-upload');
    addTearDown(() => scratch.delete(recursive: true));

    final file = File('${scratch.path}/take.wav');
    const size = 12 * 1024 * 1024;
    await file.writeAsBytes(List.generate(size, (i) => (i * 31) % 251));

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final remotePath = '.live-check/resumable $stamp.wav';

    final session = await client.open(remotePath, size);
    var offset = session.offset;
    var chunks = 0;

    while (offset < size) {
      final length =
          offset + kUploadChunkBytes > size ? size - offset : kUploadChunkBytes;
      final bytes = await readChunk(file, offset, length);
      offset = await client.sendChunk(session.id, offset, bytes);
      chunks++;

      if (chunks == 1) {
        expect(
          await client.confirmedOffset(session.id),
          offset,
          reason: 'the daemon must agree with the client about progress',
        );
      }
    }

    expect(offset, size);
    expect(chunks, greaterThan(1), reason: 'a 12MB file must be chunked');

    final encoded = remotePath.split('/').map(Uri.encodeComponent).join('/');
    final download = await dio.get<List<int>>(
      '$base/files/$encoded',
      options: Options(responseType: ResponseType.bytes),
    );

    expect(download.data, await file.readAsBytes());
  }, timeout: const Timeout(Duration(minutes: 3)));
}
