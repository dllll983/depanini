import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../core/models.dart';
import '../core/repository.dart';
import '../core/theme.dart';
import '../widgets/ad_slot.dart';

/// Étape 3 : suivi en temps réel, appel du prestataire, puis avis.
class TrackingScreen extends StatefulWidget {
  final String requestId;
  final NearbyProvider provider;
  final LatLng me;
  final ServiceAxis axis;
  const TrackingScreen({super.key, required this.requestId, required this.provider, required this.me, required this.axis});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final _map = MapController();
  StreamSubscription<String>? _statusSub;
  StreamSubscription<LatLng>? _posSub;
  String _status = 'sent';
  late LatLng _providerPos = widget.provider.position;

  static const _steps = ['accepted', 'en_route', 'on_site', 'done'];
  static const _stepLabels = ['Acceptée', 'En route', 'Sur place', 'Terminé'];

  @override
  void initState() {
    super.initState();
    _statusSub = Repository.instance.requestStatus(widget.requestId).listen((s) {
      if (!mounted) return;
      setState(() => _status = s);
      if (s == 'done') _askReview();
    });
    _posSub = Repository.instance.tracking(widget.requestId).listen((p) {
      if (mounted) setState(() => _providerPos = p);
    });
    // Sans réponse du prestataire en 90 s, la demande est annulée pour en choisir un autre.
    _timeout = Timer(const Duration(seconds: 90), () async {
      if (_status != 'sent') return;
      await Repository.instance.cancelRequest(widget.requestId);
      if (mounted) setState(() => _status = 'expired');
    });
  }

  Timer? _timeout;

  @override
  void dispose() {
    _timeout?.cancel();
    _statusSub?.cancel();
    _posSub?.cancel();
    super.dispose();
  }

  double get _remainingKm => const Distance().as(LengthUnit.Meter, _providerPos, widget.me) / 1000;

  Future<void> _call({bool whatsapp = false}) async {
    final phone = await Repository.instance.otherPartyPhone(widget.requestId, asClient: true);
    if (phone == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le numéro sera visible dès que le prestataire aura accepté.')),
        );
      }
      return;
    }
    final intl = '213${phone.replaceFirst(RegExp(r'^0'), '')}';
    await launchUrl(
      Uri.parse(whatsapp ? 'https://wa.me/$intl' : 'tel:$phone'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _askReview() async {
    var stars = 5;
    final comment = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Icon(Icons.check_circle, color: Brand.green, size: 56),
            const SizedBox(height: 8),
            const Text('Intervention terminée', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            Text('Notez ${widget.provider.name}', textAlign: TextAlign.center, style: const TextStyle(color: Brand.muted)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  iconSize: 36,
                  tooltip: '$i étoile${i > 1 ? 's' : ''}',
                  onPressed: () => setSheet(() => stars = i),
                  icon: Icon(i <= stars ? Icons.star_rounded : Icons.star_outline_rounded, color: const Color(0xFFFFB000)),
                ),
            ]),
            TextField(controller: comment, decoration: const InputDecoration(hintText: 'Un commentaire (facultatif)')),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Envoyer mon avis')),
          ]),
        ),
      ),
    );
    if (ok == true) {
      await Repository.instance.review(widget.requestId, widget.provider.id, stars, comment.text.trim());
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stepIndex = _steps.indexOf(_status);
    final closed = _status == 'cancelled' || _status == 'expired';
    final eta = (_remainingKm / 35 * 60).ceil();

    return Scaffold(
      appBar: AppBar(title: const Text('Suivi de votre demande')),
      body: Column(children: [
        Expanded(
          child: Stack(children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCameraFit: CameraFit.bounds(
                  bounds: LatLngBounds(widget.me, widget.provider.position),
                  padding: const EdgeInsets.all(60),
                ),
              ),
              children: [
                TileLayer(urlTemplate: AppConfig.tileUrl, userAgentPackageName: 'dz.depanini.client'),
                PolylineLayer(polylines: [
                  Polyline(points: [_providerPos, widget.me], strokeWidth: 5, color: widget.axis.dark),
                ]),
                MarkerLayer(markers: [
                  Marker(
                    point: widget.me,
                    width: 26,
                    height: 26,
                    child: Container(
                      decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                    ),
                  ),
                  Marker(
                    point: _providerPos,
                    width: 46,
                    height: 46,
                    child: Container(
                      decoration: BoxDecoration(
                        color: widget.axis.primary,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: widget.axis.dark, width: 2.5),
                      ),
                      child: Icon(
                        widget.axis == ServiceAxis.depannage ? Icons.local_shipping : Icons.airport_shuttle,
                        color: widget.axis.onPrimary,
                        size: 24,
                      ),
                    ),
                  ),
                ]),
              ],
            ),
            if (_status == 'en_route')
              Positioned(
                top: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(color: widget.axis.dark, borderRadius: BorderRadius.circular(16)),
                    child: Column(children: [
                      Text('$eta min', style: TextStyle(color: widget.axis.primary == Brand.red ? Colors.white : Brand.yellow, fontSize: 24, fontWeight: FontWeight.w800)),
                      Text('arrivée estimée · ${_remainingKm.toStringAsFixed(1)} km', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
        Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
          child: SafeArea(
            top: false,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                for (var i = 0; i < _steps.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          height: 5,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: i < stepIndex ? Brand.green : (i == stepIndex ? widget.axis.primary : Brand.line),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(_stepLabels[i], style: TextStyle(fontSize: 11, fontWeight: i == stepIndex ? FontWeight.w700 : FontWeight.w400)),
                      ]),
                    ),
                  ),
              ]),
              const SizedBox(height: 12),
              Text(requestStatusLabels[_status] ?? _status, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              Text('${widget.provider.name} · ${widget.provider.vehicle ?? ''}', style: const TextStyle(color: Brand.muted, fontSize: 13)),
              const SizedBox(height: 12),
              if (!closed && _status != 'sent')
                Row(children: [
                  Expanded(child: FilledButton.icon(onPressed: () => _call(), icon: const Icon(Icons.phone), label: const Text('Appeler'))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: Brand.greenDark, side: const BorderSide(color: Brand.green, width: 1.5)),
                      onPressed: () => _call(whatsapp: true),
                      child: const Text('WhatsApp'),
                    ),
                  ),
                ]),
              const SizedBox(height: 10),
              const Text("Vous réglez directement le prestataire. Aucun paiement dans l'application.",
                  style: TextStyle(fontSize: 12, color: Brand.muted)),
              const SizedBox(height: 10),
              const AdSlot(surface: 'client', slot: 'tracking_banner', height: 54, placeholder: 'Assurance, pièces, pneus…'),
              if (_status == 'sent' || _status == 'accepted')
                TextButton(
                  onPressed: () async {
                    await Repository.instance.cancelRequest(widget.requestId);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Annuler la demande', style: TextStyle(color: Brand.redDark)),
                ),
              if (closed) FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Choisir un autre prestataire')),
            ]),
          ),
        ),
      ]),
    );
  }
}
