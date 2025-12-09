import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class PlatformUtils {
  static const double desktopBreakpoint = 900.0;

  static bool get isDesktopPlatform {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  static bool get isMobilePlatform {
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  static bool isDesktopLayout(BuildContext context) {
    if (!isDesktopPlatform) return false;
    final width = MediaQuery.sizeOf(context).width;
    return width >= desktopBreakpoint;
  }

  static bool isMobileLayout(BuildContext context) {
    return !isDesktopLayout(context);
  }
}

class AdaptiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context) mobileBuilder;
  final Widget Function(BuildContext context) desktopBuilder;

  const AdaptiveBuilder({
    super.key,
    required this.mobileBuilder,
    required this.desktopBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isDesktopLayout(context)) {
      return desktopBuilder(context);
    }
    return mobileBuilder(context);
  }
}
