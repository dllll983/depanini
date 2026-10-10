import 'package:latlong2/latlong.dart';

/// Prestations proposées, par axe. Identifiants identiques à la table `categories`.
class Category {
  final String id, label;
  final bool ambulance;
  const Category(this.id, this.label, {this.ambulance = false});
}

const depannageCategories = [
  Category('remorquage', 'Remorquage'),
  Category('depannage_place', 'Dépannage sur place'),
  Category('mecanicien', 'Mécanicien mobile'),
  Category('ouverture', 'Ouverture de véhicule'),
];

const ambulanceCategories = [
  Category('ambulance_allonge', 'Transport allongé', ambulance: true),
  Category('ambulance_assis', 'Transport assis', ambulance: true),
  Category('ambulance_oxygene', 'Ambulance avec oxygène', ambulance: true),
];

String categoryLabel(String id) =>
    [...depannageCategories, ...ambulanceCategories].firstWhere((c) => c.id == id, orElse: () => Category(id, id)).label;

class NearbyProvider {
  final String id, name;
  final String? vehicle;
  final double distanceKm, rating;
  final int ratingCount;
  final int? basePriceDa;
  final LatLng position;

  const NearbyProvider({
    required this.id,
    required this.name,
    required this.vehicle,
    required this.distanceKm,
    required this.rating,
    required this.ratingCount,
    required this.basePriceDa,
    required this.position,
  });

  factory NearbyProvider.fromMap(Map<String, dynamic> m) => NearbyProvider(
        id: m['id'] as String,
        name: m['business_name'] as String,
        vehicle: m['vehicle_desc'] as String?,
        distanceKm: (m['distance_km'] as num).toDouble(),
        rating: (m['rating_avg'] as num).toDouble(),
        ratingCount: (m['rating_count'] as num).toInt(),
        basePriceDa: (m['base_price_da'] as num?)?.toInt(),
        position: LatLng((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble()),
      );

  /// Délai estimé (vitesse moyenne 35 km/h en ville).
  int get etaMinutes => (distanceKm / 35 * 60).ceil().clamp(2, 999);
}

class IncomingRequest {
  final String id, categoryId;
  final String? destination;
  final double distanceKm;
  const IncomingRequest({required this.id, required this.categoryId, required this.destination, required this.distanceKm});

  factory IncomingRequest.fromMap(Map<String, dynamic> m) => IncomingRequest(
        id: m['id'] as String,
        categoryId: m['category_id'] as String,
        destination: m['destination'] as String?,
        distanceKm: (m['distance_km'] as num).toDouble(),
      );
}

/// Statuts d'une demande, identiques à l'enum SQL `request_status`.
const requestStatusLabels = {
  'sent': 'En attente de réponse du prestataire…',
  'accepted': 'Demande acceptée',
  'en_route': 'En route vers vous',
  'on_site': 'Le prestataire est sur place',
  'done': 'Intervention terminée',
  'cancelled': 'Demande annulée',
  'expired': 'Pas de réponse : choisissez un autre prestataire',
};
