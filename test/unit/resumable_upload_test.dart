import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/services/resumable_upload.dart';

/// A stand-in for the daemon's upload protocol, with a fault switch.
///
/// Real HTTP over a real socket rather than a mocked Dio: the thing worth
/// testing is whether the client and the protocol agree, and a mock that
/// returns whatever the client asks for cannot show that.
class FakeUploadServer {
  FakeUploadServer(this._server) {
    _server.listen(_handle);
  }

  static Future<FakeUploadServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return FakeUploadServer(server);
  }

  final HttpServer _server;
  final Map<String, List<int>> _parts = {};
  final Map<String, int> _declaredSizes = {};

  /// Chunk indexes that should fail instead of being written.
  final Set<int> failOnChunk = {};

  /// Chunks that were accepted, in order, as (offset, length).
  final List<(int, int)> accepted = [];

  int _chunkCount = 0;

  int get port => _server.port;
  String get baseUrl => 'http://127.0.0.1:$port';

  List<int>? bytesFor(String path) {
    final id = _completed[path];
    return id == null ? null : _finished[id];
  }

  final Map<String, String> _completed = {};
  final Map<String, List<int>> _finished = {};

  Future<void> _handle(HttpRequest request) async {
    final segments = request.uri.pathSegments;

    if (request.method == 'POST' && request.uri.path == '/uploads') {
      final body = await utf8Decode(request);
      final path = RegExp(r'"path"\s*:\s*"([^"]*)"').firstMatch(body)?.group(1);
      final size =
          int.tryParse(RegExp(r'"size"\s*:\s*(\d+)').firstMatch(body)?.group(1) ?? '');

      final id = 'session-${_parts.length}';
      _parts[id] = [];
      _declaredSizes[id] = size ?? 0;
      if (path != null) _completed[path] = id;

      request.response
        ..statusCode = 201
        ..headers.set('upload-offset', '0')
        ..headers.contentType = ContentType.json
        ..write('{"id":"$id"}');
      await request.response.close();
      return;
    }

    if (segments.length == 2 && segments.first == 'uploads') {
      final id = segments[1];
      final part = _parts[id];
      if (part == null) {
        request.response.statusCode = 404;
        await request.response.close();
        return;
      }

      if (request.method == 'HEAD') {
        request.response
          ..statusCode = 200
          ..headers.set('upload-offset', part.length.toString());
        await request.response.close();
        return;
      }

      if (request.method == 'PATCH') {
        final claimed =
            int.tryParse(request.headers.value('upload-offset') ?? '') ?? -1;
        final body = await collect(request);

        final index = _chunkCount++;
        if (failOnChunk.contains(index)) {
          // Drop the connection the way a dead wifi link would, without
          // recording the bytes.
          await request.response.close();
          return;
        }

        if (claimed != part.length) {
          request.response
            ..statusCode = 409
            ..headers.set('upload-offset', part.length.toString());
          await request.response.close();
          return;
        }

        part.addAll(body);
        accepted.add((claimed, body.length));

        final done = part.length >= (_declaredSizes[id] ?? 0);
        if (done) _finished[id] = List.of(part);

        request.response
          ..statusCode = done ? 201 : 204
          ..headers.set('upload-offset', part.length.toString());
        await request.response.close();
        return;
      }
    }

    request.response.statusCode = 404;
    await request.response.close();
  }

  static Future<String> utf8Decode(HttpRequest request) async {
    final bytes = await collect(request);
    return String.fromCharCodes(bytes);
  }

  static Future<List<int>> collect(HttpRequest request) async {
    final bytes = <int>[];
    await for (final chunk in request) {
      bytes.addAll(chunk);
    }
    return bytes;
  }

  Future<void> close() => _server.close(force: true);
}

void main() {
  late FakeUploadServer server;
  late Dio dio;
  late Directory scratch;

  setUp(() async {
    server = await FakeUploadServer.start();
    dio = Dio();
    scratch = await Directory.systemTemp.createTemp('resumable-upload-test');
  });

  tearDown(() async {
    await server.close();
    if (await scratch.exists()) await scratch.delete(recursive: true);
  });

  File fileOf(int size) {
    final file = File('${scratch.path}/payload.bin');
    file.writeAsBytesSync(List.generate(size, (i) => i % 251));
    return file;
  }

  test('a chunked upload sends every byte in order', () async {
    final client = ResumableUploadClient(dio, server.baseUrl);
    final file = fileOf(10 * 1024 * 1024);
    final size = file.lengthSync();

    final session = await client.open('Music/take 1.wav', size);
    var offset = session.offset;

    while (offset < size) {
      final length =
          offset + kUploadChunkBytes > size ? size - offset : kUploadChunkBytes;
      final bytes = await readChunk(file, offset, length);
      offset = await client.sendChunk(session.id, offset, bytes);
    }

    expect(offset, size);
    expect(server.bytesFor('Music/take 1.wav'), file.readAsBytesSync());
  });

  test('the server offset is what a resume continues from', () async {
    final client = ResumableUploadClient(dio, server.baseUrl);
    final file = fileOf(10 * 1024 * 1024);
    final size = file.lengthSync();

    final session = await client.open('a.wav', size);

    final first = await readChunk(file, 0, kUploadChunkBytes);
    final after = await client.sendChunk(session.id, 0, first);

    expect(after, kUploadChunkBytes);
    expect(await client.confirmedOffset(session.id), kUploadChunkBytes);
  });

  test('a failed chunk does not advance the confirmed offset', () async {
    final client = ResumableUploadClient(dio, server.baseUrl);
    final file = fileOf(10 * 1024 * 1024);
    final size = file.lengthSync();

    final session = await client.open('b.wav', size);
    server.failOnChunk.add(0);

    final chunk = await readChunk(file, 0, kUploadChunkBytes);
    await expectLater(
      client.sendChunk(session.id, 0, chunk),
      throwsA(isA<DioException>()),
    );

    expect(
      await client.confirmedOffset(session.id),
      0,
      reason: 'a chunk that never landed must not count as progress',
    );
  });

  test('readChunk reads exactly the slice asked for', () async {
    final file = fileOf(1000);
    final all = file.readAsBytesSync();

    final middle = await readChunk(file, 400, 100);

    expect(middle.length, 100);
    expect(middle, all.sublist(400, 500));
  });

  test('the last chunk is short rather than padded', () async {
    final client = ResumableUploadClient(dio, server.baseUrl);
    const size = kUploadChunkBytes + 1234;
    final file = fileOf(size);

    final session = await client.open('c.wav', size);
    var offset = session.offset;

    while (offset < size) {
      final length =
          offset + kUploadChunkBytes > size ? size - offset : kUploadChunkBytes;
      final bytes = await readChunk(file, offset, length);
      offset = await client.sendChunk(session.id, offset, bytes);
    }

    expect(server.accepted.last.$2, 1234);
    expect(server.bytesFor('c.wav')!.length, size);
  });
}
