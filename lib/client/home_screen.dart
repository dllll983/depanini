import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../core/location_service.dart';
import '../core/theme.dart';
import '../widgets/ad_slot.dart';
import 'request_screen.dart';

class ClientHomeScreen extends StatelessWidget {
  const ClientHomeScreen({super.key});

  void _open(BuildContext context, ServiceAxis axis) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Theme(data: buildTheme(axis), child: RequestScreen(axis: axis))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 64),
          decoration: const BoxDecoration(
            color: Brand.black,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            BrandLogo(size: 26),
            SizedBox(height: 16),
            Text('Bonjour, où avez-vous besoin d\'aide ?', style: TextStyle(color: Color(0xFFB9BCC4), fontSize: 14)),
            SizedBox(height: 4),
            Row(children: [
              Icon(Icons.location_on_outlined, color: Brand.yellow, size: 18),
              SizedBox(width: 6),
              Text('Position GPS utilisée automatiquement',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
            ]),
          ]),
        ),
        Expanded(
          child: Transform.translate(
            offset: const Offset(0, -44),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _AxisTile(
                  title: 'Dépannage auto',
                  subtitle: 'Remorquage, batterie, crevaison, mécanicien',
                  icon: Icons.car_repair,
                  bg: Brand.yellow,
                  fg: Brand.black,
                  iconBg: Brand.black,
                  iconFg: Brand.yellow,
                  onTap: () => _open(context, ServiceAxis.depannage),
                ),
                const SizedBox(height: 14),
                _AxisTile(
                  title: 'Ambulance',
                  subtitle: 'Transport domicile ↔ hôpital, dialyse, sortie',
                  icon: Icons.local_hospital_outlined,
                  bg: Brand.navy,
                  fg: Colors.white,
                  iconBg: Brand.red,
                  iconFg: Colors.white,
                  onTap: () => _open(context, ServiceAxis.ambulance),
                ),
                const SizedBox(height: 14),
                const EmergencyButton(),
                const SizedBox(height: 14),
                const Row(children: [
                  Expanded(child: _QuickCard(title: 'SOS proche', subtitle: 'Envoyer ma position par SMS', sos: true)),
                  SizedBox(width: 12),
                  Expanded(child: _QuickCard(title: 'Mes demandes', subtitle: 'Historique et avis')),
                ]),
                const SizedBox(height: 20),
                const AdSlot(surface: 'client', slot: 'home_banner', placeholder: 'Assurance, concession, pièces…'),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class EmergencyButton extends StatelessWidget {
  const EmergencyButton({super.key});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => launchUrl(Uri.parse('tel:${AppConfig.emergencyNumber}')),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Brand.red, width: 1.5),
            ),
            child: const Row(children: [
              CircleAvatar(radius: 18, backgroundColor: Color(0xFFFDE7E9), child: Icon(Icons.phone, color: Brand.redDark, size: 18)),
              SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Urgence vitale ? Appelez le 14',
                      style: TextStyle(color: Brand.redDark, fontWeight: FontWeight.w700, fontSize: 14)),
                  Text('Protection civile, appel direct', style: TextStyle(color: Brand.muted, fontSize: 12)),
                ]),
              ),
            ]),
          ),
        ),
      );
}

class _AxisTile extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color bg, fg, iconBg, iconFg;
  final VoidCallback onTap;
  const _AxisTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.iconBg,
    required this.iconFg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: bg,
        elevation: 6,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(18)),
                child: Icon(icon, size: 32, color: iconFg),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(color: fg, fontSize: 19, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: fg.withOpacity(0.85), fontSize: 13)),
                ]),
              ),
              Icon(Icons.chevron_right, color: fg),
            ]),
          ),
        ),
      );
}

class _QuickCard extends StatelessWidget {
  final String title, subtitle;
  final bool sos;
  const _QuickCard({required this.title, required this.subtitle, this.sos = false});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            if (sos) {
              final p = await LocationService.current();
              final text = "J'ai besoin d'aide. Ma position : https://maps.google.com/?q=${p.latitude},${p.longitude}";
              await launchUrl(Uri.parse('sms:?body=${Uri.encodeComponent(text)}'));
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Historique : disponible avec le serveur en ligne.')));
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: Brand.muted, fontSize: 12)),
            ]),
          ),
        ),
      );
}
