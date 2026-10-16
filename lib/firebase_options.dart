import 'package:firebase_core/firebase_core.dart';

/// Fill these from Firebase console > Project settings > Your apps > Android app.
/// (Or run `flutterfire configure`, which overwrites this file for you.)
/// See SETUP-GUIDE.md, step 3.
class DefaultFirebaseOptions {
  static const FirebaseOptions currentPlatform = FirebaseOptions(
    apiKey: 'AIzaSyCTjV4snx_fAjOMj3YZxMqvNpFBqLiqs8s', // "Web API key" / current_key in google-services.json
    appId: '1:305454392450:android:bb071280d853f72d30009b', // looks like 1:1234567890:android:abc123...
    messagingSenderId: '305454392450', // "Project number"
    projectId: 'taskora-4f3f0',
    storageBucket: 'taskora-4f3f0.firebasestorage.app',
  );
}
