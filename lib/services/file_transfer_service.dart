import 'dart:io';
import 'package:dio/dio.dart';
import '../repositories/spacetimedb_notes_repository.dart';
import 'debug_logger.dart';

class FileAlreadyExistsException implements Exception {
  FileAlreadyExistsException(this.fileName);
  final String fileName;

  @override
  String toString() => 'FileAlreadyExistsException: $fileName already exists';
}

class FileDownloadException implements Exception {
  FileDownloadException(this.message);
  final String message;

  @override
  String toString() => message;

  static FileDownloadException fromDio(DioException e, String url) {
    final status = e.response?.statusCode;
    if (status != null) {
      final reason = e.response?.statusMessage ?? '';
      return FileDownloadException(
          'Server returned HTTP $status $reason for GET $url'.trim());
    }
    return FileDownloadException(
        'Download failed (${e.type.name}) for GET $url: ${e.message ?? e.error}');
  }
}

class FileTransferService {
  FileTransferService(this._repository);

  final SpacetimeDbNotesRepository _repository;
  final Dio _dio = Dio();

  Future<bool> nameExists(String folderPath, String fileName) async {
    final existing = await listNames(folderPath);
    return existing.contains(fileName);
  }

  Future<Set<String>> listNames(String folderPath) async {
    final client = _repository.notesClient;
    if (client == null) return {};
    final prefix = folderPath.isEmpty ? '' : '$folderPath/';
    return client.spaceFile.rows.value
        .where((f) => f.folderPath == prefix)
        .map((f) => f.path.split('/').last)
        .toSet();
  }

  Future<void> uploadFile(
    String folderPath,
    File file, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final originalName = file.uri.pathSegments.last;
    final size = await file.length();
    debugLogger.info(
      'UPLOAD',
      'Starting upload',
      'file=$originalName folder=$folderPath size=$size',
    );

    if (await nameExists(folderPath, originalName)) {
      debugLogger.info('UPLOAD', 'Skipped, already exists', originalName);
      throw FileAlreadyExistsException(originalName);
    }

    final remotePath =
        folderPath.isEmpty ? originalName : '$folderPath/$originalName';

    try {
      final url = _remoteUrl(remotePath);
      debugLogger.info('UPLOAD', 'PUT request', 'url=$url');
      final response = await _dio.put(
        url,
        data: file.openRead(),
        options: Options(
          headers: {Headers.contentLengthHeader: size},
        ),
        onSendProgress: onProgress,
      );

      debugLogger.info('UPLOAD', 'Upload complete', 'path=$remotePath status=${response.statusCode}');
    } on DioException catch (e) {
      debugLogger.error(
        'UPLOAD',
        'Upload failed: $originalName',
        'status=${e.response?.statusCode} type=${e.type} message=${e.message}',
      );
      rethrow;
    } catch (e) {
      debugLogger.error('UPLOAD', 'Upload failed (non-Dio): $originalName', e.toString());
      rethrow;
    }
  }

  Future<void> downloadFile(
    String remotePath,
    String localPath, {
    int expectedSize = 0,
    void Function(int received, int total)? onProgress,
  }) async {
    final localFile = File(localPath);
    final existingLength = await localFile.exists() ? await localFile.length() : 0;
    final startByte =
        (existingLength > 0 && expectedSize > 0 && existingLength < expectedSize)
            ? existingLength
            : 0;
    final url = _remoteUrl(remotePath);
    debugLogger.info(
      'DOWNLOAD',
      'Starting download',
      'path=$remotePath url=$url resumeFrom=$startByte',
    );

    try {
      final response = await _dio.get<ResponseBody>(
        url,
        options: Options(
          headers: startByte > 0 ? {'Range': 'bytes=$startByte-'} : null,
          responseType: ResponseType.stream,
        ),
      );
      debugLogger.info(
        'DOWNLOAD',
        'Response headers received',
        'status=${response.statusCode} contentLength=${response.headers.value(Headers.contentLengthHeader)}',
      );

      final sink = localFile.openWrite(
        mode: startByte > 0 ? FileMode.append : FileMode.write,
      );
      var received = startByte;
      final total = int.tryParse(
            response.headers.value(Headers.contentLengthHeader) ?? '',
          ) ??
          0;

      await for (final chunk in response.data!.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, startByte + total);
      }
      await sink.close();

      debugLogger.info('DOWNLOAD', 'Download complete', 'path=$remotePath bytes=$received');
    } on DioException catch (e) {
      debugLogger.error(
        'DOWNLOAD',
        'Download failed: $remotePath',
        'url=$url status=${e.response?.statusCode} type=${e.type} message=${e.message}',
      );
      throw FileDownloadException.fromDio(e, url);
    } catch (e) {
      debugLogger.error('DOWNLOAD', 'Download failed (non-Dio): $remotePath', 'url=$url error=$e');
      rethrow;
    }
  }

  Future<List<int>> fetchThumbnail(String id) async {
    final url = '$_thumbnailsBaseUrl/${Uri.encodeComponent(id)}.jpg';
    debugLogger.debug('THUMB', 'GET request', 'url=$url');
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      debugLogger.debug(
        'THUMB',
        'GET response',
        'url=$url status=${response.statusCode} bytes=${response.data?.length}',
      );
      return response.data!;
    } on DioException catch (e) {
      debugLogger.error(
        'THUMB',
        'GET failed',
        'url=$url status=${e.response?.statusCode} type=${e.type} message=${e.message}',
      );
      rethrow;
    }
  }

  String get _bareHost {
    final host = _repository.host;
    if (host == null || host.isEmpty) {
      throw StateError('Not configured: no host set');
    }
    return host.split(':').first;
  }

  String get _filesBaseUrl => 'http://$_bareHost:5051/files';

  String get _thumbnailsBaseUrl => 'http://$_bareHost:5051/thumbnails';

  /// Percent-encodes each path segment individually, preserving the `/`
  /// separators — `Uri.encodeComponent` on the whole string would encode
  /// the slashes too.
  String _remoteUrl(String remotePath) {
    final encoded = remotePath.split('/').map(Uri.encodeComponent).join('/');
    return '$_filesBaseUrl/$encoded';
  }
}
