import 'core/bootstrap.dart';
import 'core/theme.dart';
import 'pro/pro_shell.dart';

/// Application PRESTATAIRES (abonnement 1 500 DA/mois par virement) — DÉPANINI Pro.
void main() => bootstrap(
      title: 'DÉPANINI Pro',
      axis: ServiceAxis.depannage,
      isPro: true,
      home: const ProShell(),
    );
