import 'video_capture.dart';
import 'video_capture_factory_mobile.dart'
    if (dart.library.html) 'video_capture_factory_web.dart'
    as impl;

VideoCaptureService createVideoCaptureService() => impl.createVideoCaptureService();
