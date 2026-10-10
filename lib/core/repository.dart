import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'models.dart';

SupabaseClient get db => Supabase.instance.client;

class Ad {
  final String id, advertiser, imageUrl;
  final String? link;
  const Ad(this.id, this.advertiser, this.imageUrl, this.link);
}

/// Accès aux données. Chaque méthode a deux branches :
/// - serveur Supabase réel (production) ;
/// - mode démo (aucun serveur) : données simulées autour de l'utilisateur.
class Repository {
  Repository._();
  static final Repository instance = Repository._();

  /// Incrémenté quand la fiche prestataire change (profil enregistré) : le tableau de bord se recharge.
  final providerVersion = ValueNotifier<int>(0);

  // ------------------------------------------------------------------ CLIENT

  Future<List<NearbyProvider>> nearby({
    required LatLng me,
    required String axis,
    String? category,
    int maxKm = 30,
  }) async {
    if (AppConfig.isDemo) return _demo.providers(me, axis, maxKm);
    final rows = await db.rpc('nearby_providers', params: {
      'p_lat': me.latitude,
      'p_lng': me.longitude,
      'p_axis': axis,
      'p_category': category,
      'max_km': maxKm,
    }) as List<dynamic>;
    return rows.map((r) => NearbyProvider.fromMap(Map<String, dynamic>.from(r as Map))).toList();
  }

  Future<String> createRequest({
    required NearbyProvider provider,
    required String axis,
    required String category,
    required LatLng pickup,
    String? destination,
    DateTime? scheduledAt,
    bool roundTrip = false,
  }) async {
    if (AppConfig.isDemo) return _demo.createRequest(provider.position, pickup);
    final row = await db.from('requests').insert({
      'client_id': db.auth.currentUser!.id,
      'provider_id': provider.id,
      'axis': axis,
      'category_id': category,
      'pickup': 'POINT(${pickup.longitude} ${pickup.latitude})',
      'destination': destination,
      'scheduled_at': scheduledAt?.toIso8601String(),
      'round_trip': roundTrip,
    }).select('id').single();
    return row['id'] as String;
  }

  /// Statut de la demande, en temps réel.
  Stream<String> requestStatus(String requestId) {
    if (AppConfig.isDemo) return _demo.status(requestId);
    return db
        .from('requests')
        .stream(primaryKey: ['id'])
        .eq('id', requestId)
        .map((rows) => rows.isEmpty ? 'sent' : rows.first['status'] as String);
  }

  /// Position du prestataire pendant la mission, en temps réel.
  Stream<LatLng> tracking(String requestId) {
    if (AppConfig.isDemo) return _demo.tracking(requestId);
    return db
        .from('request_tracking')
        .stream(primaryKey: ['id'])
        .eq('request_id', requestId)
        .order('recorded_at')
        .where((rows) => rows.isNotEmpty)
        .map((rows) => LatLng((rows.last['lat'] as num).toDouble(), (rows.last['lng'] as num).toDouble()));
  }

  Future<void> cancelRequest(String requestId) async {
    if (AppConfig.isDemo) return _demo.cancel(requestId);
    await db.from('requests').update({'status': 'cancelled'}).eq('id', requestId);
  }

  Future<void> review(String requestId, String providerId, int stars, String comment) async {
    if (AppConfig.isDemo) return;
    await db.from('reviews').insert({
      'request_id': requestId,
      'provider_id': providerId,
      'client_id': db.auth.currentUser!.id,
      'stars': stars,
      'comment': comment,
    });
  }

  /// Téléphones échangés uniquement après acceptation.
  Future<String?> otherPartyPhone(String requestId, {required bool asClient}) async {
    if (AppConfig.isDemo) return '0550000000';
    final rows = await db.rpc('request_contacts', params: {'p_request': requestId}) as List;
    if (rows.isEmpty) return null;
    final m = Map<String, dynamic>.from(rows.first as Map);
    return (asClient ? m['provider_phone'] : m['client_phone']) as String?;
  }

  /// Publicité active pour un emplacement (régie directe, table `ads`).
  Future<Ad?> adFor({required String surface, required String slot, String? wilaya}) async {
    if (AppConfig.isDemo) return null;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await db
        .from('ads')
        .select()
        .eq('surface', surface)
        .eq('slot', slot)
        .lte('starts_on', today)
        .gte('ends_on', today)
        .limit(10);
    final match = rows.where((r) {
      final w = List<String>.from((r['wilayas'] as List?) ?? const []);
      return w.isEmpty || (wilaya != null && w.contains(wilaya));
    }).toList()
      ..shuffle();
    if (match.isEmpty) return null;
    final r = match.first;
    return Ad(r['id'] as String, r['advertiser'] as String,
        db.storage.from('ads').getPublicUrl(r['image_path'] as String), r['link_url'] as String?);
  }

  // ------------------------------------------------------------- PRESTATAIRE

  Future<void> setOnline(bool online, {LatLng? at}) async {
    if (AppConfig.isDemo) return _demo.setOnline(online);
    await db.from('providers').update({
      'is_online': online,
      if (at != null) 'location': 'POINT(${at.longitude} ${at.latitude})',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', db.auth.currentUser!.id);
  }

  Future<List<IncomingRequest>> incomingRequests() async {
    if (AppConfig.isDemo) return _demo.incoming();
    final rows = await db.rpc('incoming_requests') as List;
    return rows.map((r) => IncomingRequest.fromMap(Map<String, dynamic>.from(r as Map))).toList();
  }

  Future<void> respond(String requestId, {required bool accept}) async {
    if (AppConfig.isDemo) return _demo.respond(requestId);
    await db.rpc('respond_request', params: {'p_request': requestId, 'p_accept': accept});
  }

  /// Position du client, visible seulement après acceptation.
  Future<LatLng?> clientPickup(String requestId) async {
    if (AppConfig.isDemo) return _demo.clientPickup;
    final row = await db.rpc('request_pickup', params: {'p_request': requestId}) as List;
    if (row.isEmpty) return null;
    final m = Map<String, dynamic>.from(row.first as Map);
    return LatLng((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble());
  }

  Future<void> setRequestStatus(String requestId, String status) async {
    if (AppConfig.isDemo) return;
    await db.from('requests').update({'status': status, 'updated_at': DateTime.now().toIso8601String()}).eq('id', requestId);
  }

  Future<void> pushPosition(String requestId, LatLng p) async {
    if (AppConfig.isDemo) return;
    await db.from('request_tracking').insert({'request_id': requestId, 'lat': p.latitude, 'lng': p.longitude});
  }

  /// Fiche prestataire de l'utilisateur connecté (null si pas encore créée).
  Future<Map<String, dynamic>?> myProvider() async {
    if (AppConfig.isDemo) return {'business_name': 'Karim B. Dépannage', 'status': 'verified'};
    return db.from('providers').select().eq('id', db.auth.currentUser!.id).maybeSingle();
  }

  Future<DateTime?> subscriptionUntil() async {
    if (AppConfig.isDemo) return DateTime.now().add(const Duration(days: 30));
    final row = await db.from('providers').select('subscription_until').eq('id', db.auth.currentUser!.id).maybeSingle();
    final v = row?['subscription_until'] as String?;
    return v == null ? null : DateTime.parse(v);
  }

  /// Déclaration d'un virement d'abonnement (aucun paiement dans l'application).
  Future<void> declarePayment({required int months, required Uint8List receipt}) async {
    if (AppConfig.isDemo) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      return;
    }
    final uid = db.auth.currentUser!.id;
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await db.storage.from('receipts').uploadBinary(path, receipt);
    await db.from('subscription_payments').insert({
      'provider_id': uid,
      'months': months,
      'amount_da': AppConfig.subscriptionOffers[months],
      'reference': paymentReference(),
      'receipt_path': path,
    });
  }

  String paymentReference() {
    final uid = AppConfig.isDemo ? 'demo4' : (db.auth.currentUser?.id ?? '00000');
    return 'DEP-${uid.substring(0, 5).toUpperCase()}';
  }

  // ------------------------------------------------------------------- DÉMO
  final _demo = _DemoBackend();
}

/// Serveur simulé : permet d'utiliser l'application sans aucun backend.
class _DemoBackend {
  final _rnd = Random(42);
  final _requests = <String, _DemoRequest>{};
  DateTime? _onlineSince;
  bool _incomingHandled = false;
  LatLng clientPickup = const LatLng(AppConfig.fallbackLat + 0.02, AppConfig.fallbackLng + 0.025);

  static const _towNames = [
    ('Karim B. Dépannage', 'Plateau 5 t'),
    ('Atlas Remorquage', 'Grue + plateau'),
    ('Ouest Assistance Auto', 'Plateau 3,5 t'),
    ('Mécano Express', 'Mécanicien mobile'),
    ('Sahel Dépannage 24/24', 'Plateau 5 t'),
    ('Garage Mobile El Bahia', 'Atelier mobile'),
  ];
  static const _ambNames = [
    ('Ambulances El Amel', 'Ambulance équipée O₂'),
    ('Secours Santé Transport', 'Ambulance allongée'),
    ('Ambulances Ibn Sina', 'Véhicule sanitaire léger'),
    ('Rahma Transport Sanitaire', 'Ambulance équipée O₂'),
    ('Wiam Ambulances', 'Ambulance allongée'),
  ];

  List<NearbyProvider> providers(LatLng me, String axis, int maxKm) {
    final names = axis == 'ambulance' ? _ambNames : _towNames;
    final list = <NearbyProvider>[];
    for (var i = 0; i < names.length; i++) {
      final km = 1.2 + i * 2.3 + _rnd.nextDouble();
      if (km > maxKm) continue;
      final angle = (i * 67 + 20) * pi / 180;
      final dLat = km * cos(angle) / 111.0;
      final dLng = km * sin(angle) / (111.0 * cos(me.latitude * pi / 180));
      list.add(NearbyProvider(
        id: 'demo-$axis-$i',
        name: names[i].$1,
        vehicle: names[i].$2,
        distanceKm: double.parse(km.toStringAsFixed(1)),
        rating: double.parse((4.9 - i * 0.12).toStringAsFixed(1)),
        ratingCount: 140 - i * 17,
        basePriceDa: axis == 'ambulance' ? 4000 + i * 500 : 2500 + i * 300,
        position: LatLng(me.latitude + dLat, me.longitude + dLng),
      ));
    }
    return list;
  }

  String createRequest(LatLng from, LatLng to) {
    final id = 'demo-req-${DateTime.now().millisecondsSinceEpoch}';
    _requests[id] = _DemoRequest(from, to, DateTime.now());
    return id;
  }

  Stream<String> status(String id) async* {
    final r = _requests[id];
    if (r == null) {
      yield 'expired';
      return;
    }
    const steps = [('sent', 0), ('accepted', 3), ('en_route', 5), ('on_site', 35), ('done', 50)];
    for (final (s, at) in steps) {
      final wait = r.created.add(Duration(seconds: at)).difference(DateTime.now());
      if (!wait.isNegative) await Future<void>.delayed(wait);
      if (r.cancelled) {
        yield 'cancelled';
        return;
      }
      yield s;
    }
  }

  Stream<LatLng> tracking(String id) async* {
    final r = _requests[id];
    if (r == null) return;
    yield r.from;
    const total = 30;
    for (var i = 1; i <= total; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (r.cancelled) return;
      final t = i / total;
      yield LatLng(
        r.from.latitude + (r.to.latitude - r.from.latitude) * t,
        r.from.longitude + (r.to.longitude - r.from.longitude) * t,
      );
    }
  }

  void cancel(String id) => _requests[id]?.cancelled = true;

  void setOnline(bool online) {
    _onlineSince = online ? DateTime.now() : null;
    if (online) _incomingHandled = false;
  }

  List<IncomingRequest> incoming() {
    final since = _onlineSince;
    if (since == null || _incomingHandled) return const [];
    if (DateTime.now().difference(since).inSeconds < 4) return const [];
    return const [
      IncomingRequest(id: 'demo-incoming-1', categoryId: 'remorquage', destination: 'Garage choisi par le client', distanceKm: 4.8),
    ];
  }

  void respond(String id) => _incomingHandled = true;
}

class _DemoRequest {
  final LatLng from, to;
  final DateTime created;
  bool cancelled = false;
  _DemoRequest(this.from, this.to, this.created);
}
