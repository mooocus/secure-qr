
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app_state.dart';
import '../core/pass_token.dart';
import '../models/user_profile.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';
import 'logout_screen.dart';

/// Secure QR Access Pass
///
/// Displays a short-lived JWT/JWS issued by the backend.
///
/// Security responsibilities:
/// - Never signs or generates JWTs locally.
/// - Uses the backend-provided expiry timestamp.
/// - Hides expired credentials.
/// - Refreshes credentials through AppState.
/// - Clears the pass when the application leaves the foreground.
/// - Respects AppState's biometric unlock session.
///
/// Note:
/// Replay prevention and final access authorization
/// must be enforced by the trusted verification backend.
class PassScreen extends StatefulWidget {
  const PassScreen({super.key});

  @override
  State<PassScreen> createState() => _PassScreenState();
}

class _PassScreenState extends State<PassScreen>
    with WidgetsBindingObserver {

  static const Duration _refreshDelay =
      Duration(milliseconds: 900);

  static const Duration _tickInterval =
      Duration(milliseconds: 250);

  PassToken? _pass;

  Timer? _ticker;

  bool _refreshing = false;
  bool _refreshFailed = false;

  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _ticker = Timer.periodic(
      _tickInterval,
      (_) => _tick(),
    );

    _refresh(initial: true);
  }

  @override
  void dispose() {
    _requestGeneration++;

    _ticker?.cancel();

    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  // --------------------------------------------------
  // APPLICATION LIFECYCLE
  // --------------------------------------------------

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {

      _requestGeneration++;

      _pass = null;
      _refreshFailed = false;

      context.read<AppState>().lockPass();

      if (mounted) {
        setState(() {});
      }
    }
  }

  // --------------------------------------------------
  // TOKEN EXPIRATION
  // --------------------------------------------------

  int get _currentTime => nowSeconds();

  int _remainingSeconds(PassToken pass) {
    final remaining = pass.expiresAt - _currentTime;

    if (remaining <= 0) {
      return 0;
    }

    return remaining;
  }

  bool _isExpired(PassToken pass) {
    return _remainingSeconds(pass) <= 0;
  }

  // --------------------------------------------------
  // PERIODIC TIMER
  // --------------------------------------------------

  void _tick() {
    if (!mounted) return;

    final app = context.read<AppState>();

    // Stop displaying credentials when the
    // biometric unlock session has expired.
    if (!app.isUnlocked) {
      _requestGeneration++;

      if (_pass != null) {
        setState(() {
          _pass = null;
        });
      }

      app.lockPass();
      return;
    }

    final currentPass = _pass;

    if (currentPass == null) {
      return;
    }

    // Request a new credential after expiry.
    if (_isExpired(currentPass)) {
      if (!_refreshing && !_refreshFailed) {
        _refresh();
      }
    } 

    // Update the countdown.
    if (mounted) {
      setState(() {});
    }
  }

  // --------------------------------------------------
  // REQUEST SIGNED QR FROM BACKEND
  // --------------------------------------------------

  Future<void> _refresh({
    bool initial = false,
  }) async {

    if (_refreshing || !mounted) {
      return;
    }

    final requestId = ++_requestGeneration;

    setState(() {
      _refreshing = true;
      _refreshFailed = false;

      // Never display the previous credential
      // while requesting a replacement.
      _pass = null;
    });

    try {
      if (!initial) {
        await Future.delayed(_refreshDelay);
      }

      if (!mounted ||
          requestId != _requestGeneration) {
        return;
      }

      final app = context.read<AppState>();

      if (!app.isUnlocked ||
          app.stage != AppStage.pass) {
        return;
      }

      // IMPORTANT:
      // generatePass() must contact your FastAPI
      // /qr/issue endpoint and return a signed JWT.
      //
      // It must NOT create a fake or locally
      // generated access token.

      
      debugPrint('========== QR DEBUG ==========');
      debugPrint('Requesting signed JWT from FastAPI...');
      debugPrint('Current stage: ${app.stage}');
      debugPrint('User profile exists: ${app.user != null}');
      debugPrint('Session unlocked: ${app.isUnlocked}');

      final newPass = await app.generatePass();

      debugPrint('QR JWT received successfully');
      debugPrint('JWT expires at: ${newPass.expiresAt}');
      debugPrint('================================');


      if (!mounted ||
          requestId != _requestGeneration) {
        return;
      }

      // Don't display already-expired tokens.
      if (newPass.expiresAt <= nowSeconds()) {
        throw StateError(
          'Backend returned an expired QR credential',
        );
      }

      if (!app.isUnlocked ||
          app.stage != AppStage.pass) {
        return;
      }

      setState(() {
        _pass = newPass;
        _refreshFailed = false;
      });

    } catch (e, stackTrace) {
      // Development debugging information.
      // Do not print JWTs, Firebase ID tokens, or private keys.
      debugPrint('========== QR GENERATION ERROR ==========');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error details: $e');
      debugPrintStack(stackTrace: stackTrace);
      debugPrint('=========================================');

      if (!mounted || requestId != _requestGeneration) {
        return;
      }

      setState(() {
        _pass = null;
        _refreshFailed = true;
      });

      if (context.read<AppState>().stage == AppStage.pass) {
        showMessage(
          context,
          'QR generation failed. Check Flutter terminal.',
        );
      }

    } finally {
      if (mounted &&
          requestId == _requestGeneration) {
        setState(() {
          _refreshing = false;
        });
      }
    }
  }

  // --------------------------------------------------
  // USER INFORMATION
  // --------------------------------------------------

  static String maskId(String id) {
    if (id.length <= 6) {
      return id;
    }

    return '${id.substring(0, 4)}'
        '••••'
        '${id.substring(id.length - 2)}';
  }

  // --------------------------------------------------
  // BUILD SCREEN
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {

    final app = context.watch<AppState>();

    final user = app.user!;

    final pass = _pass;

    final int remaining = pass == null
        ? 0
        : _remainingSeconds(pass);

    final bool expired =
        pass == null || remaining <= 0;

    final bool canShowQR =
        pass != null &&
        remaining > 0 &&
        app.isUnlocked &&
        app.stage == AppStage.pass;

    final roleLabel =
        user.role == UserRole.student
            ? 'Student'
            : 'Staff';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: kPagePadding,
          child: SingleChildScrollView(
            child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [

              const SizedBox(height: 34),

              // HEADER
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [

                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: 18,
                      ),
                      child: Text(
                        'Your Access Pass',
                        style: AppText.stateTitle,
                      ),
                    ),
                  ),

                  _CloseButton(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const LogoutScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 13),

              // USER NAME
              Text(
                user.name,
                style: AppText.name,
              ),

              const SizedBox(height: 3),

              // USER ROLE AND MASKED ID
              Text(
                '$roleLabel · ${maskId(user.campusId)}',
                style: AppText.small,
              ),

              const SizedBox(height: 18),

              const SizedBox(height: 18),

              // QR CODE
              Center(
                child: _qrBox(
                  pass: pass,
                  canShowQR: canShowQR,
                  expired: expired,
                ),
              ),

              const SizedBox(height: 14),

              // COUNTDOWN STATUS
              SizedBox(
                width: double.infinity,
                child: Text(
                  _getStatusText(
                    remaining: remaining,
                    canShowQR: canShowQR,
                  ),
                  textAlign: TextAlign.center,
                  style: AppText.inter(
                    14,
                    FontWeight.w600,
                    _refreshFailed
                        ? AppColors.red
                        : canShowQR
                            ? AppColors.amber
                            : AppColors.textSecondary,
                  ),
                ),
              ),

              const SizedBox(height: 11),

              // EXPIRY PROGRESS INDICATOR
              Center(
                child: SizedBox(
                  width: 240,
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: canShowQR
                          ? (remaining /
                                  passValiditySeconds)
                              .clamp(0.0, 1.0)
                          : 0.0,
                      minHeight: 6,
                      backgroundColor:
                          AppColors.track,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // SECURITY MESSAGE
              SizedBox(
                width: double.infinity,
                child: Text(
                  canShowQR
                      ? 'Short-lived signed QR · '
                        'Refreshes automatically'
                      : 'Secure QR credential '
                        'is not currently available',
                  textAlign: TextAlign.center,
                  style: AppText.caption,
                ),
              ),

              const SizedBox(height: 24),

              // RETRY BUTTON
              if (_refreshFailed &&
                  !_refreshing &&
                  app.isUnlocked)
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _refresh(initial: true);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry QR'),
                  ),
                ),

              const SizedBox(height: 20),

              if (!canShowQR)
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    _refreshFailed
                        ? 'Unable to generate the QR pass. Try again.'
                        : 'Waiting for a valid '
                          'signed access credential.',
                    textAlign: TextAlign.center,
                    style: AppText.footnote,
                  ),
                ),

              const SizedBox(height: 16),
            ],
          ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------
  // STATUS TEXT
  // --------------------------------------------------

  String _getStatusText({
    required int remaining,
    required bool canShowQR,
  }) {

    if (_refreshFailed) {
      return 'Unable to generate pass';
    }

    if (_refreshing) {
      return 'Generating secure pass…';
    }

    if (!canShowQR) {
      return 'Pass Expired';
    }

    return 'Expires in ${remaining}s';
  }

  // --------------------------------------------------
  // QR WIDGET
  // --------------------------------------------------

  Widget _qrBox({
    required PassToken? pass,
    required bool canShowQR,
    required bool expired,
  }) {

    return Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
        ),
      ),

      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(16),

        child: Stack(
          fit: StackFit.expand,
          children: [

            // Only show a non-expired,
            // authenticated credential.
            if (canShowQR && pass != null)
              Padding(
                padding:
                    const EdgeInsets.all(12),
                child: QrImageView(
                  data: pass.token,
                  version: QrVersions.auto,
                  errorCorrectionLevel:
                      QrErrorCorrectLevel.L,
                  backgroundColor:
                      Colors.white,
                  padding: EdgeInsets.zero,
                  eyeStyle: const QrEyeStyle(
                    eyeShape:
                        QrEyeShape.square,
                    color:
                        AppColors.qrInk,
                  ),
                  dataModuleStyle:
                      const QrDataModuleStyle(
                    dataModuleShape:
                        QrDataModuleShape.square,
                    color:
                        AppColors.qrInk,
                  ),
                ),
              ),

            // Placeholder for expired,
            // unavailable, or refreshing passes.
            if (!canShowQR)
              Container(
                color: Colors.white,
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [

                    if (_refreshing)
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 3,
                          color:
                              AppColors.primary,
                        ),
                      )
                    else
                      Icon(
                        _refreshFailed
                            ? Icons.wifi_off
                            : Icons.lock_clock,
                        size: 38,
                        color: _refreshFailed
                            ? AppColors.red
                            : AppColors.primary,
                      ),

                    const SizedBox(height: 14),

                    Text(
                      _refreshing
                          ? 'Refreshing pass…'
                          : _refreshFailed
                              ? 'QR unavailable'
                              : 'Pass Expired',
                      style: AppText.inter(
                        14,
                        FontWeight.w600,
                        AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Text(
                      _refreshFailed
                          ? 'Check connection'
                          : 'Generating secure access',
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------
// CLOSE BUTTON
// --------------------------------------------------

class _CloseButton extends StatelessWidget {
  const _CloseButton({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.red,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder:
            const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            Icons.close,
            size: 18,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
