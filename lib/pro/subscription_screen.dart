import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../core/config.dart';
import '../core/repository.dart';
import '../core/theme.dart';
import '../widgets/ad_slot.dart';

/// Abonnement payé PAR VIREMENT hors application (CCP, BaridiMob, banque).
/// Le prestataire envoie la photo du reçu ; l'administrateur valide.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});
  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _repo = Repository.instance;
  int _months = 1;
  bool _sending = false;
  DateTime? _until;
  final _history = <String>[];

  @override
  void initState() {
    super.initState();
    _repo.subscriptionUntil().then((d) {
      if (mounted) setState(() => _until = d);
    }).catchError((_) {});
  }

  String _da(int v) => '${NumberFormat.decimalPattern('fr').format(v)} DA';

  Future<void> _sendReceipt(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source, imageQuality: 70, maxWidth: 1600);
    if (file == null) return;
    setState(() => _sending = true);
    try {
      await _repo.declarePayment(months: _months, receipt: await file.readAsBytes());
      _history.insert(0, '${DateFormat('dd/MM/yyyy').format(DateTime.now())} · ${_da(AppConfig.subscriptionOffers[_months]!)} · en vérification');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reçu envoyé. Votre abonnement sera prolongé après vérification du virement.')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Envoi impossible : $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final until = _until;
    final daysLeft = until == null ? 0 : until.difference(DateTime.now()).inDays.clamp(0, 365);
    final ref = _repo.paymentReference();

    return Scaffold(
      appBar: AppBar(title: const Text('Mon abonnement')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Panel(
          color: Brand.black,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Brand.yellow, borderRadius: BorderRadius.circular(6)),
                child: const Text('DÉPANINI PRO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Brand.black)),
              ),
              const Spacer(),
              Text(daysLeft > 0 ? '● Actif' : '● Expiré',
                  style: TextStyle(color: daysLeft > 0 ? const Color(0xFF7DE3A6) : const Color(0xFFFF8A94), fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 10),
            const Text.rich(TextSpan(children: [
              TextSpan(text: '1 500 ', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
              TextSpan(text: 'DA / mois', style: TextStyle(fontSize: 15, color: Color(0xFFB9BCC4))),
            ])),
            Text(
              until == null ? 'Aucun abonnement en cours' : 'Valable jusqu\'au ${DateFormat('dd/MM/yyyy').format(until)} · 0 % de commission',
              style: const TextStyle(color: Color(0xFFB9BCC4), fontSize: 13),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: daysLeft / 30,
                minHeight: 6,
                color: Brand.yellow,
                backgroundColor: const Color(0xFF2C2E33),
              ),
            ),
            const SizedBox(height: 4),
            Text('$daysLeft jours restants', style: const TextStyle(color: Color(0xFFB9BCC4), fontSize: 11)),
          ]),
        ),
        const SizedBox(height: 16),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Renouveler par virement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text("Aucun paiement dans l'application. Faites un virement CCP, BaridiMob ou bancaire, puis envoyez la photo du reçu.",
                style: TextStyle(color: Brand.muted, fontSize: 13)),
            const SizedBox(height: 12),
            _row('Bénéficiaire', AppConfig.payeeName),
            _row('RIP CCP / RIB', AppConfig.payeeAccount, copy: true),
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Expanded(child: Text('Référence à indiquer', style: TextStyle(color: Color(0xFF6B5300)))),
                Text(ref, style: const TextStyle(fontWeight: FontWeight.w800)),
                IconButton(
                  tooltip: 'Copier la référence',
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () => Clipboard.setData(ClipboardData(text: ref)),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            SegmentedButton<int>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(selectedBackgroundColor: Brand.yellow),
              segments: [
                for (final e in AppConfig.subscriptionOffers.entries)
                  ButtonSegment(value: e.key, label: Text('${e.key} mois\n${_da(e.value)}', textAlign: TextAlign.center)),
              ],
              selected: {_months},
              onSelectionChanged: (s) => setState(() => _months = s.first),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _sending ? null : () => _sendReceipt(ImageSource.camera),
              icon: const Icon(Icons.photo_camera),
              label: Text(_sending ? 'Envoi…' : 'Photographier le reçu'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _sending ? null : () => _sendReceipt(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choisir dans la galerie'),
            ),
          ]),
        ),
        if (_history.isNotEmpty) ...[
          const SizedBox(height: 16),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Historique', style: TextStyle(fontWeight: FontWeight.w700)),
              for (final h in _history) Padding(padding: const EdgeInsets.only(top: 6), child: Text(h)),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        const AdSlot(surface: 'pro', slot: 'pro_offers', placeholder: 'Assurance flotte, crédit-bail'),
      ]),
    );
  }

  Widget _row(String label, String value, {bool copy = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(color: Brand.muted))),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
          if (copy)
            IconButton(
              tooltip: 'Copier',
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () => Clipboard.setData(ClipboardData(text: value)),
            ),
        ]),
      );
}
