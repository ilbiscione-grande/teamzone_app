import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import '../../../main.dart';

class DeepLinkHandler extends StatefulWidget {
  final Widget child;
  const DeepLinkHandler({Key? key, required this.child}) : super(key: key);

  @override
  State<DeepLinkHandler> createState() => _DeepLinkHandlerState();
}

class _DeepLinkHandlerState extends State<DeepLinkHandler> {
  late final StreamSubscription<Uri?> _sub;

  @override
  void initState() {
    super.initState();
    _sub = AppLinks().uriLinkStream.listen(
      _handleUri,
      onError: (err) {
        debugPrint('Deep link error: $err');
      },
    );
  }

  void _handleUri(Uri? uri) {
    if (uri == null) return;
    debugPrint('Got deep link: $uri');

    if (uri.path == '/invite') {
      final code = uri.queryParameters['code'];
      if (code != null) {
        rootNavigatorKey.currentState?.pushNamed(
          '/handle-invite',
          arguments: code,
        );
      }
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
