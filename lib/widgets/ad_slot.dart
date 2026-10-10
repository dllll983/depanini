import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/repository.dart';
import '../core/theme.dart';

/// Emplacement publicitaire réutilisable (interface client ou Pro).
/// Affiche une pub active de la table `ads`, sinon un encart « Votre publicité ici ».
class AdSlot extends StatefulWidget {
  final String surface; // 'client' | 'pro'
  final String slot; // 'home_banner', 'list_sponsored', 'tracking_banner', 'pro_dashboard', 'pro_offers'
  final String placeholder;
  final double height;
  final bool dark;

  const AdSlot({
    super.key,
    required this.surface,
    required this.slot,
    this.placeholder = 'Votre publicité ici',
    this.height = 64,
    this.dark = false,
  });

  @override
  State<AdSlot> createState() => _AdSlotState();
}

class _AdSlotState extends State<AdSlot> {
  late final Future<Ad?> _ad = Repository.instance.adFor(surface: widget.surface, slot: widget.slot).catchError((_) => null);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Ad?>(
      future: _ad,
      builder: (context, snap) {
        final ad = snap.data;
        if (ad == null) return _placeholder();
        return Semantics(
          label: 'Publicité ${ad.advertiser}',
          button: ad.link != null,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: ad.link == null ? null : () => launchUrl(Uri.parse(ad.link!), mode: LaunchMode.externalApplication),
            child: Stack(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(ad.imageUrl, height: widget.height, width: double.infinity, fit: BoxFit.cover),
              ),
              Positioned(
                left: 8,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(4)),
                  child: const Text('Sponsorisé', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _placeholder() => Container(
        height: widget.height,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: widget.dark ? Brand.black : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: widget.dark ? Brand.black : const Color(0xFF9AA0AA)),
        ),
        child: Row(children: [
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('SPONSORISÉ',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1, color: widget.dark ? Brand.yellow : Brand.muted)),
              Text(widget.placeholder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: widget.dark ? Colors.white : Brand.black)),
            ]),
          ),
        ]),
      );
}
