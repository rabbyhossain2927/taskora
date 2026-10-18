import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Fill these from Firebase console > Project settings > Your apps > Android app.
/// (Or run `flutterfire configure`, which overwrites this file for you.)
/// See SETUP-GUIDE.md, step 3.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => kIsWeb ? web : android;

  /// TaskOra Web (Firebase console > Project settings > Your apps > Web)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAQocz0soCpbawN3Mx31f3M3VBG1l4Xj6g',
    appId: '1:305454392450:web:96c3dc7f0a3a92ac30009b',
    messagingSenderId: '305454392450',
    projectId: 'taskora-4f3f0',
    authDomain: 'taskora-4f3f0.firebaseapp.com',
    storageBucket: 'taskora-4f3f0.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCTjV4snx_fAjOMj3YZxMqvNpFBqLiqs8s', // "Web API key" / current_key in google-services.json
    appId: '1:305454392450:android:bb071280d853f72d30009b', // looks like 1:1234567890:android:abc123...
    messagingSenderId: '305454392450', // "Project number"
    projectId: 'taskora-4f3f0',
    storageBucket: 'taskora-4f3f0.firebasestorage.app',
  );
}
