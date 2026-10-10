import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/config.dart';
import '../core/location_service.dart';
import '../core/models.dart';
import '../core/repository.dart';
import '../core/theme.dart';
import '../widgets/ad_slot.dart';
import 'tracking_screen.dart';

/// Étape 2 : carte + liste des prestataires les plus proches, triés par distance réelle.
class NearbyScreen extends StatefulWidget {
  final ServiceAxis axis;
  final Category category;
  final String? destination;
  final DateTime? scheduledAt;
  final bool roundTrip;

  const NearbyScreen({
    super.key,
    required this.axis,
    required this.category,
    this.destination,
    this.scheduledAt,
    this.roundTrip = false,
  });

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  LatLng? _me;
  List<NearbyProvider> _providers = const [];
  String? _error;
  int _radius = 20;
  bool _loading = true;
  String? _sendingTo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final me = await LocationService.current();
      final list = await Repository.instance.nearby(
        me: me,
        axis: widget.axis.name,
        category: widget.category.id,
        maxKm: _radius,
      );
      if (!mounted) return;
      setState(() { _me = me; _providers = list; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _request(NearbyProvider p) async {
    setState(() => _sendingTo = p.id);
    try {
      final id = await Repository.instance.createRequest(
        provider: p,
        axis: widget.axis.name,
        category: widget.category.id,
        pickup: _me!,
        destination: widget.destination,
        scheduledAt: widget.scheduledAt,
        roundTrip: widget.roundTrip,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Theme(
            data: buildTheme(widget.axis),
            child: TrackingScreen(requestId: id, provider: p, me: _me!, axis: widget.axis),
          ),
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Envoi impossible : $e')));
    } finally {
      if (mounted) setState(() => _sendingTo = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.axis == ServiceAxis.depannage ? 'Dépanneurs proches' : 'Ambulances proches';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _loading
          ? const _Loading()
          : _error != null
              ? _Message(text: _error!, action: 'Réessayer', onAction: _load)
              : Column(children: [
                  SizedBox(height: 250, child: _map()),
                  Expanded(
                    child: _providers.isEmpty
                        ? _Message(
                            text: 'Aucun prestataire disponible à moins de $_radius km.',
                            action: _radius < 100 ? 'Élargir à ${_radius < 50 ? 50 : 100} km' : 'Réessayer',
                            onAction: () {
                              setState(() => _radius = _radius < 50 ? 50 : 100);
                              _load();
                            },
                          )
                        : ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              Text('${_providers.length} ${widget.category.label.toLowerCase()} à moins de $_radius km',
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 12),
                              AdSlot(
                                surface: 'client',
                                slot: 'list_sponsored',
                                height: 68,
                                placeholder: widget.axis == ServiceAxis.ambulance
                                    ? 'Clinique, laboratoire partenaire'
                                    : 'Garage partenaire : diagnostic offert',
                              ),
                              const SizedBox(height: 12),
                              for (final p in _providers)
                                _ProviderCard(
                                  p: p,
                                  axis: widget.axis,
                                  sending: _sendingTo == p.id,
                                  onRequest: _sendingTo == null ? () => _request(p) : null,
                                ),
                            ],
                          ),
                  ),
                ]),
    );
  }

  Widget _map() {
    final me = _me!;
    return FlutterMap(
      options: MapOptions(initialCenter: me, initialZoom: 12.5),
      children: [
        TileLayer(urlTemplate: AppConfig.tileUrl, userAgentPackageName: 'dz.depanini.client'),
        MarkerLayer(markers: [
          for (final p in _providers)
            Marker(
              point: p.position,
              width: 64,
              height: 30,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(color: widget.axis.dark, borderRadius: BorderRadius.circular(12)),
                child: Text('${p.distanceKm} km',
                    style: TextStyle(color: widget.axis.primary, fontWeight: FontWeight.w700, fontSize: 11)),
              ),
            ),
          Marker(
            point: me,
            width: 26,
            height: 26,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
              ),
            ),
          ),
        ]),
        RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap')]),
      ],
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final NearbyProvider p;
  final ServiceAxis axis;
  final bool sending;
  final VoidCallback? onRequest;
  const _ProviderCard({required this.p, required this.axis, required this.sending, required this.onRequest});

  @override
  Widget build(BuildContext context) {
    final initials = p.name.split(' ').where((w) => w.isNotEmpty).take(2).map((w) => w[0]).join().toUpperCase();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Brand.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: axis.dark, borderRadius: BorderRadius.circular(14)),
            child: Text(initials, style: TextStyle(color: axis.primary == Brand.red ? Colors.white : axis.primary, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(p.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                const Icon(Icons.verified, size: 16, color: Brand.green, semanticLabel: 'Vérifié'),
              ]),
              Text('${p.vehicle ?? ''} · ★ ${p.rating.toStringAsFixed(1)} (${p.ratingCount} avis)',
                  style: const TextStyle(fontSize: 12, color: Brand.muted)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${p.distanceKm} km', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            Text('~${p.etaMinutes} min', style: const TextStyle(fontSize: 12, color: Brand.muted)),
          ]),
        ]),
        if (p.basePriceDa != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: Brand.grey, borderRadius: BorderRadius.circular(10)),
            child: Text('Tarif indicatif du prestataire : dès ${p.basePriceDa} DA · à régler sur place',
                style: const TextStyle(fontSize: 12, color: Brand.muted)),
          ),
        ],
        const SizedBox(height: 10),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: onRequest,
          child: Text(sending ? 'Envoi…' : 'Demander'),
        ),
      ]),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Recherche des prestataires autour de vous…'),
        ]),
      );
}

class _Message extends StatelessWidget {
  final String text, action;
  final VoidCallback onAction;
  const _Message({required this.text, required this.action, required this.onAction});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(action)),
          ]),
        ),
      );
}
