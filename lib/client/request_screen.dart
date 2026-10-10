import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/models.dart';
import '../core/theme.dart';
import 'home_screen.dart' show EmergencyButton;
import 'nearby_screen.dart';

/// Étape 1 du parcours client : choisir la prestation et la destination.
class RequestScreen extends StatefulWidget {
  final ServiceAxis axis;
  const RequestScreen({super.key, required this.axis});
  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  late final List<Category> _categories =
      widget.axis == ServiceAxis.depannage ? depannageCategories : ambulanceCategories;
  late Category _category = _categories.first;
  final _destination = TextEditingController();
  DateTime? _when;
  bool _roundTrip = false, _recurring = false, _forRelative = false;

  bool get _isAmbulance => widget.axis == ServiceAxis.ambulance;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, firstDate: now, lastDate: now.add(const Duration(days: 90)), initialDate: now);
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 8, minute: 0));
    if (t == null) return;
    setState(() => _when = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  void _next() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Theme(
          data: buildTheme(widget.axis),
          child: NearbyScreen(
            axis: widget.axis,
            category: _category,
            destination: _destination.text.trim().isEmpty ? null : _destination.text.trim(),
            scheduledAt: _when,
            roundTrip: _roundTrip,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.axis.primary;
    return Scaffold(
      appBar: AppBar(
        title: BrandLogo(
          size: 20,
          accent: _isAmbulance ? const Color(0xFFFF5A68) : Brand.yellow,
          suffix: _isAmbulance ? 'Ambulance' : null,
        ),
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        if (_isAmbulance) ...[const EmergencyButton(), const SizedBox(height: 20)],
        Text(_isAmbulance ? 'Type de transport' : 'De quoi avez-vous besoin ?',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in _categories)
            ChoiceChip(
              label: Text(c.label),
              selected: _category == c,
              selectedColor: primary,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                color: _category == c ? widget.axis.onPrimary : widget.axis.dark,
              ),
              onSelected: (_) => setState(() => _category = c),
            ),
        ]),
        const SizedBox(height: 20),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('DÉPART', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Brand.muted)),
            const SizedBox(height: 4),
            const Row(children: [
              Icon(Icons.my_location, size: 18, color: Colors.blue),
              SizedBox(width: 8),
              Text('Ma position actuelle (GPS)', style: TextStyle(fontWeight: FontWeight.w600)),
            ]),
            const Divider(height: 28),
            Text(_isAmbulance ? 'DESTINATION (hôpital, clinique, centre de soins)' : 'DESTINATION (facultatif)',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Brand.muted)),
            TextField(
              controller: _destination,
              decoration: InputDecoration(
                hintText: _isAmbulance ? 'Ex. CHU, centre de dialyse…' : 'Ex. mon garage, domicile…',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ]),
        ),
        if (_isAmbulance) ...[
          const SizedBox(height: 14),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.event),
                title: Text(_when == null ? 'Maintenant' : DateFormat('dd/MM/yyyy à HH:mm').format(_when!)),
                subtitle: const Text('Date et heure du transport'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickDate,
              ),
              SwitchListTile(
                value: _roundTrip,
                activeColor: Brand.red,
                onChanged: (v) => setState(() => _roundTrip = v),
                title: const Text('Aller-retour'),
              ),
              SwitchListTile(
                value: _recurring,
                activeColor: Brand.red,
                onChanged: (v) => setState(() => _recurring = v),
                title: const Text('Transport récurrent'),
                subtitle: const Text('Dialyse, chimiothérapie, rééducation'),
              ),
              SwitchListTile(
                value: _forRelative,
                activeColor: Brand.red,
                onChanged: (v) => setState(() => _forRelative = v),
                title: const Text('Pour un proche'),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          const Text(
            "Aucune information médicale n'est demandée. Seules les sociétés agréées par la wilaya sont proposées.",
            style: TextStyle(fontSize: 12, color: Brand.muted),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _next,
          child: Text(_isAmbulance ? 'Voir les ambulances proches' : 'Voir les dépanneurs proches'),
        ),
      ]),
    );
  }
}
