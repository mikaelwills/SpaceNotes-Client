@Tags(['live'])
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Downloads already resume by byte offset. This proves the deployed daemon
/// honours that against a real partial file, which is the half the client
/// cannot verify on its own.
///
/// `flutter test --tags live`
void main() {
  const host = String.fromEnvironment('SPACENOTES_HOST',
      defaultValue: '100.84.184.121');
  const base = 'http://$host:5051';

  test('a half-finished download continues from where it stopped', () async {
    final dio = Dio();
    final scratch = await Directory.systemTemp.createTemp('download-resume');
    addTearDown(() => scratch.delete(recursive: true));

    // Put a known file on the server to pull back down.
    const size = 6 * 1024 * 1024;
    final original = List.generate(size, (i) => (i * 23) % 251);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final remotePath = '.live-check/download $stamp.bin';
    final encoded = remotePath.split('/').map(Uri.encodeComponent).join('/');

    await dio.put<void>(
      '$base/files/$encoded',
      data: Stream.fromIterable([original]),
      options: Options(headers: {Headers.contentLengthHeader: size}),
    );

    // Simulate a download killed partway: keep only the first third.
    final partial = File('${scratch.path}/partial.bin');
    final firstPart = original.sublist(0, size ~/ 3);
    await partial.writeAsBytes(firstPart);

    final startByte = await partial.length();
    expect(startByte, size ~/ 3);

    // Resume exactly as the client does.
    final response = await dio.get<List<int>>(
      '$base/files/$encoded',
      options: Options(
        headers: {'Range': 'bytes=$startByte-'},
        responseType: ResponseType.bytes,
      ),
    );

    expect(response.statusCode, 206, reason: 'the server must honour Range');
    expect(
      response.data!.length,
      size - startByte,
      reason: 'only the missing tail should come down',
    );

    await partial.writeAsBytes(response.data!, mode: FileMode.append);

    expect(await partial.length(), size);
    expect(
      await partial.readAsBytes(),
      original,
      reason: 'a resumed download must reassemble byte-identical',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
