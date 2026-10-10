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

/// Affiche l'inscription tant que l'utilisateur n'a pas de profil (jamais en mode démo).
class AuthGate extends StatefulWidget {
  final bool isPro;
  final Widget child;
  const AuthGate({super.key, required this.isPro, required this.child});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? _ready; // null = vérification en cours

  @override
  void initState() {
    super.initState();
    if (!AppConfig.isDemo) _check();
  }

  Future<void> _check() async {
    final client = Supabase.instance.client;
    var ok = false;
    try {
      final uid = client.auth.currentUser?.id;
      if (uid != null) {
        ok = await client.from('profiles').select('id').eq('id', uid).maybeSingle() != null;
      }
    } catch (_) {}
    if (mounted) setState(() => _ready = ok);
  }

  @override
  Widget build(BuildContext context) {
    if (AppConfig.isDemo) return _DemoBanner(child: widget.child);
    if (_ready == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_ready == true) return widget.child;
    return LoginScreen(isPro: widget.isPro, onDone: () => setState(() => _ready = true));
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
