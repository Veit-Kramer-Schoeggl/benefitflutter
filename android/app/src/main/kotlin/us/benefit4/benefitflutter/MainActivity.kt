package us.benefit4.benefitflutter

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth:
// the biometric prompt needs a FragmentActivity host (smoke finding F6).
class MainActivity : FlutterFragmentActivity()
