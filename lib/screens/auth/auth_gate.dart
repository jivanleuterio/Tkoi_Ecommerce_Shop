import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
import '../buyer/main_shell.dart';
import '../splash_screen.dart';
import 'login_screen.dart';
import 'reset_password_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return StreamBuilder<AuthState>(
      stream: auth.authChanges,
      builder: (context, snapshot) {
        if (snapshot.data?.event == AuthChangeEvent.passwordRecovery) {
          return const ResetPasswordScreen();
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            auth.currentSession == null) {
          return const SplashScreen();
        }
        return auth.currentSession == null
            ? const LoginScreen()
            : const MainShell();
      },
    );
  }
}
