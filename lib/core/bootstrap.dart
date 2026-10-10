import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/login_screen.dart';
import 'config.dart';
import 'theme.dart';

/// Démarrage commun aux deux applications (Client et Pro).
Future<void> bootstrap({
  required String title,
  required ServiceAxis axis,
  required Widget home,
  required bool isPro,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!AppConfig.isDemo) {
    await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey);
  }
  runApp(MaterialApp(
    title: title,
    debugShowCheckedModeBanner: false,
    theme: buildTheme(axis),
    locale: const Locale('fr'),
    supportedLocales: const [Locale('fr'), Locale('ar')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: AuthGate(isPro: isPro, child: home),
  ));
}

/// Affiche la connexion par SMS si nécessaire (jamais en mode démo).
class AuthGate extends StatelessWidget {
  final bool isPro;
  final Widget child;
  const AuthGate({super.key, required this.isPro, required this.child});

  @override
  Widget build(BuildContext context) {
    if (AppConfig.isDemo) return _DemoBanner(child: child);
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, _) {
        final session = Supabase.instance.client.auth.currentSession;
        return session == null ? LoginScreen(isPro: isPro) : child;
      },
    );
  }
}

class _DemoBanner extends StatelessWidget {
  final Widget child;
  const _DemoBanner({required this.child});
  @override
  Widget build(BuildContext context) => Banner(
        message: 'DÉMO',
        location: BannerLocation.topEnd,
        color: Brand.green,
        child: child,
      );
}
