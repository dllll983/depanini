import 'client/home_screen.dart';
import 'core/bootstrap.dart';
import 'core/theme.dart';

/// Application CLIENTS (gratuite) — DÉPANINI.
void main() => bootstrap(
      title: 'DÉPANINI',
      axis: ServiceAxis.depannage,
      isPro: false,
      home: const ClientHomeScreen(),
    );
