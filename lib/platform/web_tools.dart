// Browser-only helpers. On phones these do nothing (see web_tools_stub.dart).
export 'web_tools_stub.dart' if (dart.library.js_interop) 'web_tools_web.dart';
