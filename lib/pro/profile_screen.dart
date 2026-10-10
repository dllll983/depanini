import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/config.dart';
import '../core/repository.dart';
import '../core/theme.dart';

/// Profil prestataire : activité, véhicule, tarifs indicatifs, documents à vérifier.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController(text: AppConfig.isDemo ? 'Karim B. Dépannage' : '');
  final _vehicle = TextEditingController(text: AppConfig.isDemo ? 'Plateau 5 t' : '');
  final _plate = TextEditingController();
  final _base = TextEditingController(text: AppConfig.isDemo ? '2500' : '');
  final _perKm = TextEditingController(text: AppConfig.isDemo ? '100' : '');
  String _axis = 'depannage';
  int _radius = 20;
  bool _saving = false;

  static const _docs = {
    'registre_commerce': 'Registre de commerce ou carte d\'artisan',
    'identite': 'Pièce d\'identité',
    'carte_grise': 'Carte grise du véhicule',
    'assurance': 'Assurance du véhicule',
    'agrement_wilaya': 'Agrément de wilaya (ambulance)',
  };
  final _uploaded = <String>{};

  Future<void> _upload(String type) async {
    final file = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1600);
    if (file == null) return;
    if (!AppConfig.isDemo) {
      final uid = db.auth.currentUser!.id;
      final path = '$uid/$type-${DateTime.now().millisecondsSinceEpoch}.jpg';
      await db.storage.from('documents').uploadBinary(path, await file.readAsBytes());
      await db.from('provider_documents').insert({'provider_id': uid, 'doc_type': type, 'file_path': path});
    }
    setState(() => _uploaded.add(type));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (!AppConfig.isDemo) {
        await db.from('providers').upsert({
          'id': db.auth.currentUser!.id,
          'business_name': _name.text.trim(),
          'axis': _axis,
          'categories': _axis == 'ambulance' ? ['ambulance_allonge', 'ambulance_assis'] : ['remorquage', 'depannage_place'],
          'wilaya': 'Oran',
          'radius_km': _radius,
          'vehicle_desc': _vehicle.text.trim(),
          'plate': _plate.text.trim(),
          'base_price_da': int.tryParse(_base.text),
          'price_per_km_da': int.tryParse(_perKm.text),
        });
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil enregistré.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final docs = _docs.entries.where((e) => e.key != 'agrement_wilaya' || _axis == 'ambulance');
    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Activité', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(selectedBackgroundColor: Brand.yellow),
              segments: const [
                ButtonSegment(value: 'depannage', label: Text('Dépannage')),
                ButtonSegment(value: 'ambulance', label: Text('Ambulance')),
              ],
              selected: {_axis},
              onSelectionChanged: (s) => setState(() => _axis = s.first),
            ),
            const SizedBox(height: 12),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nom commercial')),
            const SizedBox(height: 10),
            TextField(controller: _vehicle, decoration: const InputDecoration(labelText: 'Véhicule (ex. Plateau 5 t)')),
            const SizedBox(height: 10),
            TextField(controller: _plate, decoration: const InputDecoration(labelText: 'Immatriculation')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _base,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Tarif de base (DA)'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _perKm,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Par km (DA)'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Text("Rayon d'intervention : $_radius km", style: const TextStyle(fontWeight: FontWeight.w600)),
            Slider(
              value: _radius.toDouble(),
              min: 5,
              max: 100,
              divisions: 19,
              activeColor: Brand.black,
              label: '$_radius km',
              onChanged: (v) => setState(() => _radius = v.round()),
            ),
            const Text('Les tarifs sont indicatifs et réglés directement par le client.', style: TextStyle(fontSize: 12, color: Brand.muted)),
          ]),
        ),
        const SizedBox(height: 16),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Documents à vérifier', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const Text('Votre badge « Vérifié » est attribué après contrôle.', style: TextStyle(fontSize: 12, color: Brand.muted)),
            const SizedBox(height: 8),
            for (final d in docs)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(_uploaded.contains(d.key) ? Icons.check_circle : Icons.upload_file,
                    color: _uploaded.contains(d.key) ? Brand.green : Brand.muted),
                title: Text(d.value, style: const TextStyle(fontSize: 14)),
                subtitle: Text(_uploaded.contains(d.key) ? 'Envoyé · en vérification' : 'À envoyer'),
                onTap: () => _upload(d.key),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Enregistrement…' : 'Enregistrer le profil')),
        if (!AppConfig.isDemo) ...[
          const SizedBox(height: 8),
          TextButton(onPressed: () => db.auth.signOut(), child: const Text('Se déconnecter')),
        ],
      ]),
    );
  }
}
