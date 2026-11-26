import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Project smart-farming-app-49954. The web API key is public by design and
/// restricted to six Firebase APIs.
///
/// Android: app com.aissmsioit.b18.smartfarming is registered in the Firebase console.
/// Its appId is below. The API key is the project's web key (restricted to Firebase APIs).
///
class FirebaseConfig {
  static const databaseURL = 'https://smart-farming-app-49954-default-rtdb.asia-southeast1.firebasedatabase.app';

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyAxRyRRtE_yOjZwiE1h_g_R7CIfpfrz1gg',
    authDomain: 'smart-farming-app-49954.firebaseapp.com',
    databaseURL: databaseURL,
    projectId: 'smart-farming-app-49954',
    storageBucket: 'smart-farming-app-49954.firebasestorage.app',
    messagingSenderId: '359391759402',
    appId: '1:359391759402:web:f350519c40068711f50753',
  );

  /// Fill in after registering the Android app (the appId contains ":android:").
  static const androidAppId = '1:359391759402:android:b777994e1cb3cc98f50753';
  static const androidApiKey = 'AIzaSyAxRyRRtE_yOjZwiE1h_g_R7CIfpfrz1gg';

  static FirebaseOptions? get current {
    if (kIsWeb) return web;
    if (defaultTargetPlatform == TargetPlatform.android && androidAppId.isNotEmpty) {
      return FirebaseOptions(
        apiKey: androidApiKey,
        appId: androidAppId,
        messagingSenderId: web.messagingSenderId,
        projectId: web.projectId,
        databaseURL: databaseURL,
        storageBucket: web.storageBucket,
      );
    }
    return null;
  }
}
