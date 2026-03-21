import 'dart:io';
import 'video_capture.dart';
import 'video_capture_mobile.dart';
import 'video_capture_native_ios.dart';

VideoCaptureService createVideoCaptureService() {
  if (Platform.isIOS) return NativeIosVideoCaptureService();
  return MobileVideoCaptureService();
}
