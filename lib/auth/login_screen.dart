import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/repository.dart';
import '../core/theme.dart';

/// Connexion par numéro de téléphone + code SMS (OTP). Aucun mot de passe.
class LoginScreen extends StatefulWidget {
  final bool isPro;
  const LoginScreen({super.key, required this.isPro});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false, _busy = false;
  bool _accepted = false;
  String? _error;

  /// 0550 12 34 56 → +213550123456
  String get _e164 {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    final local = digits.startsWith('213') ? digits.substring(3) : digits.replaceFirst(RegExp(r'^0'), '');
    return '+213$local';
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() { _busy = true; _error = null; });
    try {
      await action();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Erreur : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() => _run(() async {
        await db.auth.signInWithOtp(phone: _e164);
        setState(() => _codeSent = true);
      });

  Future<void> _verify() => _run(() async {
        await db.auth.verifyOTP(phone: _e164, token: _code.text.trim(), type: OtpType.sms);
        final uid = db.auth.currentUser!.id;
        await db.from('profiles').upsert({'id': uid, 'phone': _e164, 'role': widget.isPro ? 'provider' : 'client'});
      });

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
            const SizedBox(height: 40),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(_codeSent ? 'Code reçu par SMS' : 'Votre numéro de téléphone',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 12),
                if (!_codeSent)
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(prefixText: '+213 ', hintText: '550 12 34 56'),
                  )
                else
                  TextField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(hintText: '6 chiffres'),
                  ),
                if (!_codeSent)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _accepted,
                    onChanged: (v) => setState(() => _accepted = v ?? false),
                    title: const Text(
                      "J'accepte les conditions d'utilisation et la politique de confidentialité "
                      '(loi 18-07). Ma position n\'est partagée qu\'avec le prestataire choisi.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_error!, style: const TextStyle(color: Brand.redDark)),
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy || (!_codeSent && !_accepted) ? null : (_codeSent ? _verify : _sendCode),
                  child: Text(_busy ? 'Patientez…' : (_codeSent ? 'Valider' : 'Recevoir le code')),
                ),
                if (_codeSent)
                  TextButton(onPressed: () => setState(() => _codeSent = false), child: const Text('Changer de numéro')),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
