import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Saves bytes as a file download in the browser.
void downloadBytes(List<int> bytes, String name, String mime) {
  final blob = web.Blob([Uint8List.fromList(bytes).toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final a = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = name;
  web.document.body?.appendChild(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
}

/// Runs [f] when the tab is hidden or closed, so nothing typed is lost.
void onPageHide(void Function() f) {
  web.document.addEventListener(
    'visibilitychange',
    ((web.Event _) {
      if (web.document.visibilityState == 'hidden') f();
    }).toJS,
  );
  web.window.addEventListener('pagehide', ((web.Event _) => f()).toJS);
}
