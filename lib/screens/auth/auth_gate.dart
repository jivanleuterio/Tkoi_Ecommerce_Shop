import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
import '../../services/admin_access_service.dart';
import '../../models/admin_access.dart';
import '../admin/admin_shell.dart';
import '../buyer/main_shell.dart';
import '../buyer/help_support_screen.dart';
import '../splash_screen.dart';
import 'login_screen.dart';
import 'restricted_account_screen.dart';
import 'reset_password_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  static const _minimumSplashDuration = Duration(milliseconds: 2500);

  Timer? _splashTimer;
  bool _minimumSplashFinished = false;

  @override
  void initState() {
    super.initState();
    _splashTimer = Timer(_minimumSplashDuration, () {
      if (mounted) setState(() => _minimumSplashFinished = true);
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return StreamBuilder<AuthState>(
      stream: auth.authChanges,
      builder: (context, snapshot) {
        // Keep the branded startup animation visible long enough to be
        // appreciated, while Supabase authentication resolves in parallel.
        if (!_minimumSplashFinished) return const SplashScreen();
        if (snapshot.data?.event == AuthChangeEvent.passwordRecovery) {
          return const ResetPasswordScreen();
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            auth.currentSession == null) {
          return const SplashScreen();
        }
        if (auth.currentSession == null) return const LoginScreen();
        return _AccessGate(key: ValueKey(auth.currentSession!.user.id));
      },
    );
  }
}

class _AccessGate extends StatefulWidget {
  const _AccessGate({super.key});

  @override
  State<_AccessGate> createState() => _AccessGateState();
}

class _AccessGateState extends State<_AccessGate> {
  late Future<AdminAccessContext> _future;

  @override
  void initState() {
    super.initState();
    _future = AdminAccessService().getMyContext();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AdminAccessContext>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const SplashScreen();
      }
      // Migration 11 may not be installed yet. Preserve the existing app
      // experience until the additive admin foundation is applied.
      if (snapshot.hasError) return const MainShell();
      final access = snapshot.data!;
      return switch (resolveAccessDestination(access)) {
        AccessDestination.restricted => RestrictedAccountScreen(
          access: access,
          onAppeal: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => const CreateSupportTicketScreen(
                initialCategory: 'appeal',
                initialSubject: 'Appeal account restriction',
                categoryLocked: true,
              ),
            ),
          ),
        ),
        AccessDestination.admin => AdminShell(access: access),
        AccessDestination.marketplace => MainShell(access: access),
      };
    },
  );
}
