import 'dart:io';

import 'package:dio/dio.dart';

import 'debug_logger.dart';

/// Files at or below this go up in a single PUT. Chunking a file that finishes
/// in a couple of seconds only adds round trips; above it a dropped connection
/// costs real time, which is what resuming is for.
const int kResumableThresholdBytes = 8 * 1024 * 1024;

/// Sent per request. Small enough that losing one is cheap, large enough that
/// a 40MB file is ten requests rather than hundreds.
const int kUploadChunkBytes = 32 * 1024 * 1024;

/// A server-side upload session. The id is what makes a transfer resumable:
/// it survives the connection that created it.
class UploadSession {
  const UploadSession({required this.id, required this.offset});

  final String id;

  /// Bytes the server has confirmed durable.
  final int offset;
}

/// Client for the daemon's resumable upload protocol.
///
/// `POST /uploads` opens a session, `HEAD /uploads/{id}` reports what survived,
/// `PATCH /uploads/{id}` appends from a stated offset. The server rejects a
/// PATCH whose offset disagrees with its own and returns the real one, so the
/// two can never silently diverge.
class ResumableUploadClient {
  ResumableUploadClient(this._dio, this._baseUrl);

  final Dio _dio;

  /// Origin only, e.g. `http://host:5051` — the protocol lives at `/uploads`,
  /// not under `/files`.
  final String _baseUrl;

  Future<UploadSession> open(String remotePath, int size) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_baseUrl/uploads',
      data: {'path': remotePath, 'size': size},
      options: Options(contentType: Headers.jsonContentType),
    );

    final id = response.data?['id'];
    if (id is! String || id.isEmpty) {
      throw StateError('Upload session response carried no id');
    }

    debugLogger.info('UPLOAD', 'Session opened', 'id=$id path=$remotePath');
    return UploadSession(id: id, offset: 0);
  }

  /// Asks how much of [id] survived. Used after a failure, before resending.
  Future<int> confirmedOffset(String id) async {
    final response = await _dio.head<void>('$_baseUrl/uploads/$id');
    final raw = response.headers.value('upload-offset');
    final offset = int.tryParse(raw ?? '');
    if (offset == null) {
      throw StateError('Upload $id reported no offset');
    }
    return offset;
  }

  /// Appends one chunk at [offset]. Returns the server's new offset, which is
  /// the only authority on how much has landed.
  Future<int> sendChunk(String id, int offset, List<int> bytes) async {
    final response = await _dio.patch<void>(
      '$_baseUrl/uploads/$id',
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {
          'Upload-Offset': offset.toString(),
          Headers.contentLengthHeader: bytes.length,
        },
        validateStatus: (status) => status == 204 || status == 201,
      ),
    );

    final raw = response.headers.value('upload-offset');
    final next = int.tryParse(raw ?? '');
    if (next == null) {
      throw StateError('Chunk response carried no offset');
    }
    return next;
  }

  Future<void> abandon(String id) async {
    try {
      await _dio.delete<void>('$_baseUrl/uploads/$id');
    } catch (e) {
      debugLogger.warning('UPLOAD', 'Could not abandon session $id', e.toString());
    }
  }
}

/// Reads [file] from [offset], yielding at most [kUploadChunkBytes] per slice.
Future<List<int>> readChunk(File file, int offset, int length) async {
  final handle = await file.open();
  try {
    await handle.setPosition(offset);
    return await handle.read(length);
  } finally {
    await handle.close();
  }
}
