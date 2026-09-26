import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spacenotes_client/generated/space_file.dart';
import 'package:spacenotes_client/providers/download_queue_provider.dart';
import 'package:spacenotes_client/providers/file_transfer_providers.dart';
import 'package:spacenotes_client/services/local_download_store.dart';
import 'package:spacenotes_client/widgets/folder_download_button.dart';

SpaceFile _file(String path) => SpaceFile(
      id: path,
      path: path,
      name: path.split('/').last,
      folderPath: 'Masters/',
      depth: 1,
      extension: path.split('.').last,
      size: Int64(100),
      createdTime: Int64(0),
      modifiedTime: Int64(0),
      dbUpdatedAt: Int64(0),
      hasThumbnail: false,
    );

class _NullStore implements DownloadQueueStore {
  @override
  Future<void> enqueueDownloads(List<QueuedDownload> items) async {}
  @override
  Future<List<QueuedDownload>> queuedDownloads() async => [];
  @override
  Future<void> dequeueDownload(String path) async {}
  @override
  Future<void> clearDownloadQueue() async {}
}

void main() {
  late List<String> downloaded;

  Future<void> pump(
    WidgetTester tester, {
    required List<SpaceFile> files,
    required Set<String> complete,
  }) {
    downloaded = [];
    return tester.pumpWidget(ProviderScope(
      overrides: [
        downloadStateProvider.overrideWith((ref, path) async =>
            complete.contains(path)
                ? DownloadState.complete
                : DownloadState.notDownloaded),
        downloadQueueProvider.overrideWith((ref) => DownloadQueueNotifier(
              download: (path, size, onProgress) async => downloaded.add(path),
              cancelActive: (_) async {},
              isComplete: (path, size) async => complete.contains(path),
              store: _NullStore(),
              onSettled: (_) {},
            )),
      ],
      child: MaterialApp(
        home: Scaffold(body: FolderDownloadButton(files: files)),
      ),
    ));
  }

  testWidgets('greyed out when every downloadable file is on the device', (tester) async {
    await pump(
      tester,
      files: [_file('Masters/a.wav'), _file('Masters/notes.md')],
      complete: {'Masters/a.wav'},
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('folder-download')));
    await tester.pumpAndSettle();
    expect(downloaded, isEmpty);
  });

  testWidgets('tapping queues only the files missing from the device', (tester) async {
    await pump(
      tester,
      files: [
        _file('Masters/a.wav'),
        _file('Masters/b.wav'),
        _file('Masters/notes.md'),
      ],
      complete: {'Masters/a.wav'},
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('folder-download')));
    await tester.pumpAndSettle();
    expect(downloaded, ['Masters/b.wav']);
  });
}
