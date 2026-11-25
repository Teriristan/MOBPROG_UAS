import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants.dart';
import 'core/theme/bootstrap_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/follow_provider.dart';
import 'providers/nav_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/tracking_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_shell.dart';
import 'widgets/app_logo.dart';
import 'widgets/bs/bs_alert.dart';

class LarikuApp extends StatelessWidget {
  const LarikuApp({super.key, required this.settings});

  final SettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, FollowProvider>(
          create: (_) => FollowProvider(),
          update: (_, auth, previous) {
            final provider = previous ?? FollowProvider();
            provider.updateUser(auth.user?.uid);
            return provider;
          },
        ),
        ChangeNotifierProvider<NavProvider>(create: (_) => NavProvider()),
        ChangeNotifierProvider<TrackingProvider>(
          create: (_) => TrackingProvider(settings: settings),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.select<AuthProvider, bool>((a) => a.isLoggedIn);
    return loggedIn ? const HomeShell() : const LoginScreen();
  }
}

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppLogo(size: 72),
                    const SizedBox(height: 16),
                    BsAlert(
                      message:
                          'Penyimpanan lokal (localStorage) tidak bisa '
                          'dibuka. Pastikan browser tidak memblokir '
                          'penyimpanan situs, lalu muat ulang halaman.\n\n'
                          '$message',
                      variant: BsVariant.danger,
                      icon: Icons.error_outline,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
