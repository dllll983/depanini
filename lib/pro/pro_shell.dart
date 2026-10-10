import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'subscription_screen.dart';

/// Navigation principale de l'app DÉPANINI Pro.
class ProShell extends StatefulWidget {
  const ProShell({super.key});
  @override
  State<ProShell> createState() => _ProShellState();
}

class _ProShellState extends State<ProShell> {
  int _tab = 0;
  static const _pages = [ProDashboardScreen(), SubscriptionScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _tab, children: _pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          indicatorColor: Brand.yellow,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Accueil'),
            NavigationDestination(icon: Icon(Icons.card_membership_outlined), selectedIcon: Icon(Icons.card_membership), label: 'Abonnement'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
          ],
        ),
      );
}
