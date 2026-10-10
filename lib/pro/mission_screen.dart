import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../core/location_service.dart';
import '../core/models.dart';
import '../core/repository.dart';
import '../core/theme.dart';

/// Mission acceptée : navigation vers le client, appel, changements de statut.
class MissionScreen extends StatefulWidget {
  final IncomingRequest request;
  const MissionScreen({super.key, required this.request});
  @override
  State<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends State<MissionScreen> {
  final _repo = Repository.instance;
  LatLng? _client, _me;
  String _status = 'accepted';
  StreamSubscription<LatLng>? _posSub;

  static const _next = {'accepted': 'en_route', 'en_route': 'on_site', 'on_site': 'done'};
  static const _buttons = {
    'accepted': 'Je pars maintenant',
    'en_route': 'Je suis arrivé',
    'on_site': 'Mission terminée',
  };

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final me = await LocationService.current();
    final client = await _repo.clientPickup(widget.request.id);
    if (!mounted) return;
    setState(() { _me = me; _client = client; });
    // Position partagée avec le client uniquement pendant la mission.
    _posSub = LocationService.stream(distanceFilterMeters: 20).listen((p) {
      _me = p;
      _repo.pushPosition(widget.request.id, p);
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  Future<void> _advance() async {
    final next = _next[_status];
    if (next == null) return;
    await _repo.setRequestStatus(widget.request.id, next);
    if (next == 'done') {
      if (mounted) Navigator.pop(context);
      return;
    }
    setState(() => _status = next);
  }

  Future<void> _navigate(String app) async {
    final c = _client;
    if (c == null) return;
    final uri = app == 'waze'
        ? Uri.parse('https://waze.com/ul?ll=${c.latitude},${c.longitude}&navigate=yes')
        : Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${c.latitude},${c.longitude}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _call({bool whatsapp = false}) async {
    final phone = await _repo.otherPartyPhone(widget.request.id, asClient: false);
    if (phone == null) return;
    final intl = '213${phone.replaceFirst(RegExp(r'^0'), '')}';
    await launchUrl(Uri.parse(whatsapp ? 'https://wa.me/$intl' : 'tel:$phone'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final client = _client, me = _me;
    return Scaffold(
      appBar: AppBar(title: Text('Mission · ${categoryLabel(widget.request.categoryId)}')),
      body: Column(children: [
        Expanded(
          child: client == null || me == null
              ? const Center(child: CircularProgressIndicator())
              : FlutterMap(
                  options: MapOptions(
                    initialCameraFit: CameraFit.bounds(bounds: LatLngBounds(client, me), padding: const EdgeInsets.all(60)),
                  ),
                  children: [
                    TileLayer(urlTemplate: AppConfig.tileUrl, userAgentPackageName: 'dz.depanini.pro'),
                    PolylineLayer(polylines: [Polyline(points: [me, client], strokeWidth: 5, color: Brand.yellow)]),
                    MarkerLayer(markers: [
                      Marker(
                        point: client,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.location_on, color: Brand.red, size: 40),
                      ),
                      Marker(
                        point: me,
                        width: 44,
                        height: 44,
                        child: Container(
                          decoration: BoxDecoration(color: Brand.yellow, borderRadius: BorderRadius.circular(12), border: Border.all(color: Brand.black, width: 2)),
                          child: const Icon(Icons.local_shipping, color: Brand.black),
                        ),
                      ),
                    ]),
                  ],
                ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(18),
          child: SafeArea(
            top: false,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(requestStatusLabels[_status] ?? _status, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              if (widget.request.destination != null)
                Text('Destination : ${widget.request.destination}', style: const TextStyle(color: Brand.muted)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => _navigate('maps'), child: const Text('Google Maps'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(onPressed: () => _navigate('waze'), child: const Text('Waze'))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: () => _call(), icon: const Icon(Icons.phone), label: const Text('Appeler'))),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: Brand.greenDark, side: const BorderSide(color: Brand.green, width: 1.5)),
                    onPressed: () => _call(whatsapp: true),
                    child: const Text('WhatsApp'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _status == 'on_site' ? Brand.green : Brand.yellow,
                  foregroundColor: _status == 'on_site' ? Colors.white : Brand.black,
                ),
                onPressed: _advance,
                child: Text(_buttons[_status] ?? 'Terminer'),
              ),
              const SizedBox(height: 6),
              const Text('Votre position est partagée avec ce client uniquement pendant la mission.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Brand.muted)),
            ]),
          ),
        ),
      ]),
    );
  }
}
