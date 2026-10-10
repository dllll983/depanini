/// Configuration injectée au moment de la compilation :
///   --dart-define=SUPABASE_URL=...  --dart-define=SUPABASE_ANON_KEY=...
/// Sans ces valeurs, l'application démarre en MODE DÉMO (données simulées),
/// ce qui permet de l'installer et de la tester tout de suite.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isDemo => supabaseUrl.isEmpty || supabaseAnonKey.isEmpty;

  /// Serveur de tuiles cartographiques. En production : votre propre serveur OSM.
  static const tileUrl = String.fromEnvironment(
    'TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  static const emergencyNumber = '14'; // Protection civile

  /// Position de repli si le GPS est indisponible (centre d'Oran).
  static const fallbackLat = 35.6971;
  static const fallbackLng = -0.6308;

  /// Coordonnées de virement affichées dans l'app Pro (à remplacer).
  static const payeeName = String.fromEnvironment('PAYEE_NAME', defaultValue: '[RAISON SOCIALE DÉPANINI]');
  static const payeeAccount = String.fromEnvironment('PAYEE_ACCOUNT', defaultValue: '[RIP CCP / RIB À RENSEIGNER]');

  static const subscriptionOffers = {1: 1500, 3: 4200, 12: 15000};
}
