import 'dart:async';
import '../platform/capabilities.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import '../repositories/spacetimedb_notes_repository.dart';
import 'debug_logger.dart';
import 'local_download_store.dart';
import 'resumable_upload.dart';

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

/// Where a download should restart from, given what is on disk.
///
/// Zero means start over: either nothing is there, the expected size is
/// unknown, or the file is already at/over full length and a Range request
/// would be pointless or invalid.
int resumeOffsetFor(int existingLength, int expectedSize) {
  if (existingLength <= 0) return 0;
  if (expectedSize <= 0) return 0;
  if (existingLength >= expectedSize) return 0;
  return existingLength;
}

class FileTransferService {
  FileTransferService(this._repository);

  final SpacetimeDbNotesRepository _repository;
  /// `receiveTimeout` only covers waiting for response HEADERS — dio hands the
  /// body stream through untimed (verified in dio 5.9.0 io_adapter.dart:162).
  /// A silent drop mid-body is caught by [_idleTimeout] on the stream instead.
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
  ));

  /// Longest gap allowed between chunks before a transfer is considered dead.
  static const _idleTimeout = Duration(seconds: 30);

  /// Consecutive failures on one chunk before the upload gives up.
  static const _maxChunkAttempts = 3;

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

  /// Puts the just-uploaded bytes into the download cache so opening the file
  /// doesn't pull it straight back down. Best-effort: the upload has already
  /// succeeded by this point, so a caching failure must never surface.
  Future<void> _cacheUploadedFile(
    String remotePath,
    File source,
    int size,
  ) async {
    if (!Capabilities.hasFileSystem) return;
    try {
      final store = LocalDownloadStore();
      final localPath = await store.localPathFor(remotePath);
      await source.copy(localPath);
      final cached = await store.markCompleteIfVerified(
        remotePath,
        localPath,
        size,
      );
      debugLogger.info(
        'UPLOAD',
        cached ? 'Cached locally' : 'Local cache verification failed',
        remotePath,
      );
    } catch (e) {
      debugLogger.warning('UPLOAD', 'Could not cache locally', e.toString());
    }
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

    // A fast path only. The server refuses a collision itself, which is what
    // actually enforces it: this check reads the subscribed table, so before
    // hydration it sees an empty vault and waves everything through. Its worth
    // is avoiding a pointless 40MB upload when the answer is already known.
    if (await nameExists(folderPath, originalName)) {
      debugLogger.info('UPLOAD', 'Skipped, already exists', originalName);
      throw FileAlreadyExistsException(originalName);
    }

    final remotePath =
        folderPath.isEmpty ? originalName : '$folderPath/$originalName';

    try {
      if (size > kResumableThresholdBytes) {
        await _uploadResumable(remotePath, file, size, onProgress);
      } else {
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
        debugLogger.info('UPLOAD', 'Upload complete',
            'path=$remotePath status=${response.statusCode}');
      }

      await _cacheUploadedFile(remotePath, file, size);
    } on DioException catch (e) {
      // The server refuses a collision with 409. Surfacing it as the same
      // exception the local check throws means callers handle one case, and
      // an upload started before hydration behaves like any other duplicate
      // instead of silently overwriting.
      if (e.response?.statusCode == 409) {
        debugLogger.info(
          'UPLOAD',
          'Server refused, already exists',
          originalName,
        );
        throw FileAlreadyExistsException(originalName);
      }
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

  /// Uploads in chunks, resuming from whatever the server confirms after a
  /// failure rather than starting again.
  ///
  /// The server's offset is the only authority on progress: a chunk can be
  /// written and the response lost, so asking beats assuming. Retries are
  /// bounded, and a run that makes no progress stops instead of looping.
  Future<void> _uploadResumable(
    String remotePath,
    File file,
    int size,
    void Function(int sent, int total)? onProgress,
  ) async {
    final client = ResumableUploadClient(_dio, _uploadsBaseUrl);
    final store = Capabilities.hasFileSystem ? LocalDownloadStore() : null;

    final resumed = await _resumeSession(store, client, remotePath, file, size);
    final session = resumed ?? await client.open(remotePath, size);

    await store?.rememberUpload(
      remotePath: remotePath,
      sessionId: session.id,
      sourcePath: file.path,
      size: size,
      sent: session.offset,
    );

    var offset = session.offset;
    var attempts = 0;

    while (offset < size) {
      final length =
          offset + kUploadChunkBytes > size ? size - offset : kUploadChunkBytes;

      try {
        final bytes = await readChunk(file, offset, length);
        offset = await client.sendChunk(session.id, offset, bytes);
        onProgress?.call(offset, size);
        await store?.updateUploadProgress(remotePath, offset);
        attempts = 0;
      } catch (e) {
        attempts++;
        if (attempts > _maxChunkAttempts) {
          debugLogger.error('UPLOAD', 'Giving up after $attempts attempts',
              'path=$remotePath offset=$offset');
          rethrow;
        }

        debugLogger.warning('UPLOAD', 'Chunk failed, asking what survived',
            'path=$remotePath attempt=$attempts error=$e');

        final resumed = await client.confirmedOffset(session.id);
        if (resumed <= offset && attempts > 1) {
          debugLogger.error('UPLOAD', 'No progress on retry, stopping',
              'path=$remotePath offset=$offset');
          rethrow;
        }
        offset = resumed;
        onProgress?.call(offset, size);
      }
    }

    await store?.forgetUpload(remotePath);
    debugLogger.info('UPLOAD', 'Resumable upload complete',
        'path=$remotePath bytes=$size');
  }

  /// Picks up a session this device recorded earlier, if the server still has
  /// it and it refers to the same file.
  ///
  /// The server's offset wins over the stored one: a chunk can land while the
  /// response is lost, so the local number can only ever be behind.
  Future<UploadSession?> _resumeSession(
    LocalDownloadStore? store,
    ResumableUploadClient client,
    String remotePath,
    File file,
    int size,
  ) async {
    if (store == null) return null;

    final pending = await store.pendingUploads();
    final match = pending
        .where((row) =>
            row.remotePath == remotePath &&
            row.sourcePath == file.path &&
            row.size == size)
        .firstOrNull;

    if (match == null) return null;

    try {
      final offset = await client.confirmedOffset(match.sessionId);
      debugLogger.info('UPLOAD', 'Resuming previous session',
          'path=$remotePath id=${match.sessionId} offset=$offset');
      return UploadSession(id: match.sessionId, offset: offset);
    } catch (e) {
      debugLogger.info('UPLOAD', 'Stored session is gone, starting over',
          'path=$remotePath error=$e');
      await store.forgetUpload(remotePath);
      return null;
    }
  }

  /// Ensures [remotePath] is on disk and verified, downloading if needed.
  /// Returns the local path.
  ///
  /// The four viewers each had their own copy of this and all four ignored
  /// the verification result, so a size-mismatched file was played anyway.
  /// Verification failure deletes the bad copy and throws.
  Future<String> ensureDownloaded(
    String remotePath,
    int expectedSize, {
    void Function(int received, int total)? onProgress,
  }) async {
    final store = LocalDownloadStore();
    final localPath = await store.localPathFor(remotePath);

    final state = await store.stateFor(remotePath, expectedSize: expectedSize);
    if (state == DownloadState.complete) return localPath;

    await downloadFile(
      remotePath,
      localPath,
      expectedSize: expectedSize,
      onProgress: onProgress,
    );

    final verified = await store.markCompleteIfVerified(
      remotePath,
      localPath,
      expectedSize,
    );
    if (!verified) {
      await store.remove(remotePath);
      throw FileDownloadException(
        'Downloaded file did not match the expected size. Try again.',
      );
    }
    return localPath;
  }

  Future<void> downloadFile(
    String remotePath,
    String localPath, {
    int expectedSize = 0,
    void Function(int received, int total)? onProgress,
  }) async {
    final localFile = File(localPath);
    final existingLength = await localFile.exists() ? await localFile.length() : 0;
    final startByte = resumeOffsetFor(existingLength, expectedSize);
    final url = _remoteUrl(remotePath);
    debugLogger.info(
      'DOWNLOAD',
      'Starting download',
      'path=$remotePath url=$url resumeFrom=$startByte',
    );

    // Report what is already on disk BEFORE the request goes out. Waiting for
    // the first chunk means a resume on bad signal shows 0% until the network
    // answers, hiding progress the device already has.
    if (startByte > 0 && expectedSize > 0) {
      onProgress?.call(startByte, expectedSize);
    }

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

      // Record the partial BEFORE writing, so an app kill mid-stream leaves a
      // tracked row rather than an invisible orphan on disk.
      if (Capabilities.hasFileSystem) {
        await LocalDownloadStore()
            .markPartial(remotePath, localPath, expectedSize);
      }

      final sink = localFile.openWrite(
        mode: startByte > 0 ? FileMode.append : FileMode.write,
      );
      var received = startByte;
      final total = int.tryParse(
            response.headers.value(Headers.contentLengthHeader) ?? '',
          ) ??
          0;

      try {
        await for (final chunk
            in response.data!.stream.timeout(_idleTimeout)) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, startByte + total);
        }
      } finally {
        // Must close on the error path too, or the next attempt opens a
        // second sink on the same file while this one is still flushing.
        await sink.close();
      }

      debugLogger.info('DOWNLOAD', 'Download complete', 'path=$remotePath bytes=$received');
    } on DioException catch (e) {
      debugLogger.error(
        'DOWNLOAD',
        'Download failed: $remotePath',
        'url=$url status=${e.response?.statusCode} type=${e.type} message=${e.message}',
      );
      throw FileDownloadException.fromDio(e, url);
    } on TimeoutException {
      debugLogger.error('DOWNLOAD', 'Stalled: $remotePath', 'url=$url');
      throw FileDownloadException(
        'Download stalled — no data for ${_idleTimeout.inSeconds}s. '
        'Reopen the file to resume.',
      );
    } catch (e) {
      debugLogger.error('DOWNLOAD', 'Download failed (non-Dio): $remotePath', 'url=$url error=$e');
      rethrow;
    }
  }

  /// The streamable HTTP URL for a file, for players that read a network
  /// URL directly (e.g. `VideoPlayerController.networkUrl`) instead of a
  /// local path. The server already supports Range requests on this URL.
  String streamUrl(String remotePath) => _remoteUrl(remotePath);

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

  String get _uploadsBaseUrl => 'http://$_bareHost:5051';

  String get _thumbnailsBaseUrl => 'http://$_bareHost:5051/thumbnails';

  /// Percent-encodes each path segment individually, preserving the `/`
  /// separators — `Uri.encodeComponent` on the whole string would encode
  /// the slashes too.
  String _remoteUrl(String remotePath) {
    final encoded = remotePath.split('/').map(Uri.encodeComponent).join('/');
    return '$_filesBaseUrl/$encoded';
  }
}
