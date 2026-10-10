import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../core/repository.dart';
import '../core/theme.dart';

/// Inscription en une étape : nom + téléphone + consentement.
/// Phase pilote : connexion « anonyme » Supabase (pas de SMS à payer).
/// Production : remplacer par la vérification du numéro par SMS (OTP) via une passerelle opérateur.
class LoginScreen extends StatefulWidget {
  final bool isPro;
  final VoidCallback onDone;
  const LoginScreen({super.key, required this.isPro, required this.onDone});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _accepted = false, _busy = false;
  String? _error;

  /// 0550 12 34 56 → 0550123456
  String get _cleanPhone {
    var d = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('213')) d = '0${d.substring(3)}';
    if (!d.startsWith('0')) d = '0$d';
    return d;
  }

  bool get _valid => _name.text.trim().length >= 2 && RegExp(r'^0[5-7]\d{8}$').hasMatch(_cleanPhone) && _accepted;

  Future<void> _start() async {
    setState(() { _busy = true; _error = null; });
    try {
      if (db.auth.currentSession == null) await db.auth.signInAnonymously();
      await db.from('profiles').upsert({
        'id': db.auth.currentUser!.id,
        'full_name': _name.text.trim(),
        'phone': _cleanPhone,
        'role': widget.isPro ? 'provider' : 'client',
      });
      widget.onDone();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Connexion impossible : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.black,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          children: [
            BrandLogo(size: 36, suffix: widget.isPro ? 'PRO' : null),
            const SizedBox(height: 8),
            Text(widget.isPro ? 'Plus de clients. 0 % de commission.' : 'En panne ? On arrive.',
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 36),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(widget.isPro ? 'Créer mon espace prestataire' : 'Bienvenue',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 14),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: widget.isPro ? 'Nom du responsable' : 'Votre prénom et nom'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Téléphone',
                    hintText: '0550 12 34 56',
                    helperText: 'Communiqué uniquement au prestataire ou client de votre mission',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _accepted,
                  onChanged: (v) => setState(() => _accepted = v ?? false),
                  title: const Text(
                    "J'accepte les conditions d'utilisation et la politique de confidentialité (loi 18-07). "
                    "Ma position n'est partagée qu'avec le prestataire ou le client de ma mission.",
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_error!, style: const TextStyle(color: Brand.redDark)),
                  ),
                FilledButton(
                  onPressed: _busy || !_valid ? null : _start,
                  child: Text(_busy ? 'Patientez…' : 'Commencer'),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
