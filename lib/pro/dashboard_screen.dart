import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../core/location_service.dart';
import '../core/models.dart';
import '../core/repository.dart';
import '../core/theme.dart';
import '../widgets/ad_slot.dart';
import 'mission_screen.dart';

/// Tableau de bord prestataire : interrupteur En ligne + demandes reçues.
class ProDashboardScreen extends StatefulWidget {
  const ProDashboardScreen({super.key});
  @override
  State<ProDashboardScreen> createState() => _ProDashboardScreenState();
}

class _ProDashboardScreenState extends State<ProDashboardScreen> {
  final _repo = Repository.instance;
  bool _online = false, _busy = false;
  StreamSubscription<LatLng>? _posSub;
  Timer? _poll;
  List<IncomingRequest> _incoming = const [];
  DateTime? _subUntil;
  bool _hasProfile = true;
  int _missions = 0;

  @override
  void initState() {
    super.initState();
    _reload();
    _repo.providerVersion.addListener(_reload);
  }

  /// Recharge la fiche prestataire (profil créé ? abonnement valable ?).
  Future<void> _reload() async {
    try {
      final p = await _repo.myProvider();
      final until = await _repo.subscriptionUntil();
      if (mounted) setState(() { _hasProfile = p != null; _subUntil = until; });
    } catch (_) {}
  }

  Future<void> _toggle(bool value) async {
    setState(() => _busy = true);
    try {
      if (value) {
        await _reload();
        if (!_hasProfile) throw 'Complétez d\'abord votre profil (onglet Profil).';
        final p = await LocationService.current();
        await _repo.setOnline(true, at: p);
        _posSub = LocationService.stream().listen((pos) => _repo.setOnline(true, at: pos));
        _poll = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
      } else {
        await _posSub?.cancel();
        _poll?.cancel();
        await _repo.setOnline(false);
        _incoming = const [];
      }
      setState(() => _online = value);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    try {
      final list = await _repo.incomingRequests();
      if (mounted) setState(() => _incoming = list);
    } catch (_) {}
  }

  Future<void> _respond(IncomingRequest r, bool accept) async {
    await _repo.respond(r.id, accept: accept);
    setState(() => _incoming = _incoming.where((x) => x.id != r.id).toList());
    if (accept && mounted) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => MissionScreen(request: r)));
      if (mounted) setState(() => _missions++);
    }
  }

  @override
  void dispose() {
    _repo.providerVersion.removeListener(_reload);
    _posSub?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subActive = _subUntil != null && _subUntil!.isAfter(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: const BrandLogo(size: 20, suffix: 'PRO'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              backgroundColor: subActive ? const Color(0xFF14361F) : const Color(0xFF3A1216),
              side: BorderSide(color: subActive ? Brand.green : Brand.red),
              label: Text(
                subActive ? 'Abonnement actif' : 'Abonnement expiré',
                style: TextStyle(color: subActive ? const Color(0xFF7DE3A6) : const Color(0xFFFF8A94), fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(padding: const EdgeInsets.all(20), physics: const AlwaysScrollableScrollPhysics(), children: [
        if (!_hasProfile)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Panel(
              color: const Color(0xFFFFF8E1),
              border: Border.all(color: Brand.yellow, width: 1.5),
              child: const Text(
                'Bienvenue ! Complétez votre profil (onglet Profil) : votre premier mois est offert. '
                'Tirez ensuite cet écran vers le bas pour actualiser.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        Panel(
          color: _online ? Brand.black : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: SwitchListTile(
            value: _online,
            activeColor: Colors.white,
            activeTrackColor: Brand.green,
            onChanged: _busy || (!subActive && _hasProfile) ? null : _toggle,
            title: Text(_online ? 'Vous êtes en ligne' : 'Vous êtes hors ligne',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: _online ? Colors.white : Brand.black)),
            subtitle: Text(
              !subActive
                  ? 'Renouvelez votre abonnement pour recevoir des demandes'
                  : (_online ? 'Visible par les clients proches' : 'Activez pour recevoir des demandes'),
              style: TextStyle(color: _online ? Colors.white70 : Brand.muted),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _Stat(value: '$_missions', label: 'missions')),
          const SizedBox(width: 10),
          const Expanded(child: _Stat(value: '4,8', label: 'note moyenne')),
          const SizedBox(width: 10),
          const Expanded(child: _Stat(value: '0 %', label: 'commission')),
        ]),
        const SizedBox(height: 18),
        const Text('Demandes reçues', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (_incoming.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              _online ? 'En attente de demandes autour de vous…' : 'Passez en ligne pour recevoir des demandes.',
              style: const TextStyle(color: Brand.muted),
            ),
          ),
        for (final r in _incoming)
          Panel(
            border: Border.all(color: Brand.yellow, width: 2),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFFFFF4CC), borderRadius: BorderRadius.circular(8)),
                  child: Text(categoryLabel(r.categoryId), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6B5300))),
                ),
                const Spacer(),
                Text('${r.distanceKm} km', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ]),
              const SizedBox(height: 10),
              Text('Client à ${r.distanceKm} km de vous', style: const TextStyle(fontWeight: FontWeight.w600)),
              if (r.destination != null) Text('Vers : ${r.destination}'),
              const SizedBox(height: 6),
              const Text('Position exacte et téléphone visibles après acceptation.', style: TextStyle(fontSize: 12, color: Brand.muted)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => _respond(r, false), child: const Text('Refuser'))),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: FilledButton(onPressed: () => _respond(r, true), child: const Text('Accepter'))),
              ]),
            ]),
          ),
        const SizedBox(height: 20),
        const AdSlot(surface: 'pro', slot: 'pro_dashboard', dark: true, placeholder: 'Pneus, pièces : tarif pro'),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value, label;
  const _Stat({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Panel(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(fontSize: 11, color: Brand.muted)),
        ]),
      );
}
