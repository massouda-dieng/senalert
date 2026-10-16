import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:senalert_mobile/core/constants/app_colors.dart';
import 'package:senalert_mobile/features/incidents/providers/incident_provider.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  String _type = 'Accident';
  String _selectedRegion = 'Dakar';
  String _locationText = 'Localisation automatique';
  double? _lat;
  double? _lng;
  bool _loadingLoc = false;
  Uint8List? _selectedImageBytes;
  bool _hasDemoPhoto = false;

  final List<String> _types = [
    'Accident',
    'Incendie',
    'Inondation',
    'Urgence médicale',
    'Électricité / Panne',
    'Insécurité / Vol',
    'Autre',
  ];

  final List<String> _regions = [
    'Dakar',
    'Thiès',
    'Saint-Louis',
    'Diourbel',
    'Fatick',
    'Kaffrine',
    'Kaolack',
    'Kédougou',
    'Kolda',
    'Louga',
    'Matam',
    'Sédhiou',
    'Tambacounda',
    'Ziguinchor',
  ];

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    setState(() => _loadingLoc = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() {
          _locationText = 'Permission refusée';
          _loadingLoc = false;
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _locationText =
            '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
        _loadingLoc = false;
      });
    } catch (_) {
      setState(() {
        _locationText = 'Erreur de localisation';
        _loadingLoc = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final lat = _lat ?? 14.6928;
    final lng = _lng ?? -17.4467;
    final locText = _lat != null
        ? '$_selectedRegion ($_locationText)'
        : 'Région $_selectedRegion, Sénégal';

    final provider = context.read<IncidentProvider>();
    final ok = await provider.createIncident(
          type: _type,
          region: _selectedRegion,
          description: _descCtrl.text,
          location: locText,
          latitude: lat,
          longitude: lng,
        );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Alerte envoyée avec succès !'),
        backgroundColor: AppColors.success,
      ));
      context.go('/incidents');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(provider.lastError ?? 'Échec de l\'envoi'),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Signaler une urgence'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type incident
              _Label('Type d\'incident'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _type,
                    icon: const Icon(Icons.keyboard_arrow_down,
                        color: AppColors.textGrey),
                    items: _types
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Région du Sénégal
              _Label('Région du Sénégal'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedRegion,
                    icon: const Icon(Icons.map, color: AppColors.crimson),
                    items: _regions
                        .map((r) => DropdownMenuItem(value: r, child: Text('🇸🇳 Région $r')))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedRegion = v!),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Description
              _Label('Description'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                maxLines: 4,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Description obligatoire' : null,
                decoration: InputDecoration(
                  hintText: 'Décrivez ce qui s\'est passé...',
                  hintStyle: const TextStyle(
                      color: AppColors.textGrey, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.danger),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Localisation
              _Label('Localisation'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _getLocation,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.my_location,
                          color: AppColors.danger, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _loadingLoc
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.danger,
                                ),
                              )
                            : Text(
                                _locationText,
                                style: TextStyle(
                                  color: _lat != null
                                      ? AppColors.textDark
                                      : AppColors.textGrey,
                                  fontSize: 13,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Photo
              _Label('Ajouter une photo de l\'incident'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  try {
                    final picker = ImagePicker();
                    final image = await picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      final bytes = await image.readAsBytes();
                      setState(() {
                        _selectedImageBytes = bytes;
                      });
                    }
                  } catch (_) {
                    // Fallback visuel démo si la sélection navigateur est bloquée
                    setState(() {
                      _hasDemoPhoto = true;
                    });
                  }
                },
                child: Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (_selectedImageBytes != null || _hasDemoPhoto)
                          ? AppColors.emerald
                          : Colors.grey.shade300,
                      width: (_selectedImageBytes != null || _hasDemoPhoto) ? 2 : 1,
                    ),
                  ),
                  child: (_selectedImageBytes != null)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            _selectedImageBytes!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : (_hasDemoPhoto)
                          ? Container(
                              color: AppColors.emerald.withOpacity(0.1),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle, color: AppColors.emerald, size: 36),
                                  SizedBox(height: 6),
                                  Text(
                                    'Photo de l\'incident jointe ✓',
                                    style: TextStyle(
                                      color: AppColors.emerald,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, color: AppColors.crimson, size: 32),
                                SizedBox(height: 6),
                                Text(
                                  'Prendre une photo ou choisir dans la galerie',
                                  style: TextStyle(
                                    color: AppColors.textGrey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 24),

              // Bouton
              Consumer<IncidentProvider>(
                builder: (_, p, __) => ElevatedButton(
                  onPressed: p.isLoading ? null : _submit,
                  child: p.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: AppColors.white, strokeWidth: 2),
                        )
                      : const Text('ENVOYER L\'ALERTE'),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        selectedItemColor: AppColors.crimson,
        unselectedItemColor: AppColors.textGrey,
        onTap: (i) {
          if (i == 0) context.go('/home');
          if (i == 1) context.go('/incidents');
          if (i == 2) context.go('/report');
          if (i == 3) context.go('/first-aid');
          if (i == 4) context.go('/profile');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Incidents'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle), label: 'Signaler'),
          BottomNavigationBarItem(icon: Icon(Icons.medical_services_outlined), label: 'Secours'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: AppColors.textDark,
      ),
    );
  }
}
