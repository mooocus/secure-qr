
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

import 'app_state.dart';

import 'screens/account_locked_screen.dart';
import 'screens/backend_unreachable_screen.dart';
import 'screens/login_screen.dart';
import 'screens/pass_screen.dart';
import 'screens/verify_failed_screen.dart';
import 'screens/verify_screen.dart';

import 'services/firebase_backend_api.dart';

import 'ui/tokens.dart';

// --------------------------------------------------
// APPLICATION ENTRY POINT
// --------------------------------------------------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase before authentication
  // or database operations are performed.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Start the Flutter application.
  runApp(
    ChangeNotifierProvider<AppState>(
      create: (_) => AppState(
        // Real Firebase registration and login.
        api: FirebaseBackendApi(),
      )..init(),
      child: const SecureAccessApp(),
    ),
  );
}

// --------------------------------------------------
// MAIN APPLICATION
// --------------------------------------------------

class SecureAccessApp extends StatelessWidget {
  const SecureAccessApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SecureAccess',
      debugShowCheckedModeBanner: false,

      // Preserve existing design theme.
      theme: buildAppTheme(),

      // AppGate decides which screen to show.
      home: const AppGate(),
    );
  }
}

// --------------------------------------------------
// APPLICATION NAVIGATION
// --------------------------------------------------

/// Handles navigation between the existing
/// Figma-designed application screens.
///
/// Flutter does not need to generate JWTs.
/// The trusted FastAPI backend generates
/// signed QR credentials after biometric unlock.
class AppGate extends StatelessWidget {
  const AppGate({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final stage = context.watch<AppState>().stage;

    return switch (stage) {

      // App startup
      AppStage.loading =>
        const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),

      // Screen 04: Login
      AppStage.signedOut =>
        const LoginScreen(),

      // Screen 02: Biometric verification
      AppStage.verify =>
        const VerifyScreen(),

      // Screen 06: Failed biometric attempt
      AppStage.verifyFailed =>
        const VerifyFailedScreen(),

      // Screen 10: Account locked
      AppStage.accountLocked =>
        const AccountLockedScreen(),

      // Screen 07: Backend unavailable
      AppStage.backendUnreachable =>
        const BackendUnreachableScreen(),

      // Screens 03 and 09:
      // Dynamic signed QR and expired QR
      AppStage.pass =>
        const PassScreen(),
    };
  }
}
