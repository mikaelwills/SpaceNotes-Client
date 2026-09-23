import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cancelling a token ends a trickling body stream promptly', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.contentLength = 1000;
      for (var i = 0; i < 100; i++) {
        request.response.add(List.filled(10, 1));
        await request.response.flush();
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      await request.response.close();
    });

    final token = CancelToken();
    final response = await Dio().get<ResponseBody>(
      'http://127.0.0.1:${server.port}/',
      options: Options(responseType: ResponseType.stream),
      cancelToken: token,
    );

    var received = 0;
    final started = DateTime.now();
    Timer(const Duration(milliseconds: 500), () => token.cancel('superseded'));

    Object? error;
    try {
      await for (final chunk in response.data!.stream) {
        received += chunk.length;
      }
    } catch (e) {
      error = e;
    }

    final elapsed = DateTime.now().difference(started);
    await server.close(force: true);

    expect(error, isNotNull);
    expect(received, lessThan(1000));
    expect(elapsed, lessThan(const Duration(seconds: 2)));
  });
}
