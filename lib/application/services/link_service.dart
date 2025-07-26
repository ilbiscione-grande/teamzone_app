import 'dart:async';
import 'package:app_links/app_links.dart';

class LinkService {
  StreamSubscription<Uri>? _sub;

  /// Initierar lyssning på både cold-start och hot-links
  void init(void Function(Uri uri) onLinkReceived) {
    final appLinks = AppLinks(); // singleton

    _sub = appLinks.uriLinkStream.listen(
      (uri) {
        onLinkReceived(uri);
      },
      onError: (err, stack) {
        // Hantera fel här, t.ex. logga dem
        print('Deep link error: $err');
      },
    ); // uriLinkStream skickar initial link + alla efterföljande länkar :contentReference[oaicite:0]{index=0}
  }

  void dispose() {
    _sub?.cancel();
  }
}
