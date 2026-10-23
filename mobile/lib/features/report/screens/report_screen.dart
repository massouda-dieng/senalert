import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:senalert_mobile/core/constants/app_colors.dart';
import 'package:senalert_mobile/features/incidents/providers/incident_provider.dart';
import 'package:senalert_mobile/shared/widgets/custom_button.dart';
import 'package:senalert_mobile/shared/widgets/sa_ui.dart';

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

  /// Étape visuelle : 0 type · 1 photo/description · 2 position
  int _step = 0;
  bool _typeFromQueryApplied = false;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pré-sélection du type depuis l'accueil (/report?type=incendie).
    if (_typeFromQueryApplied) return;
    _typeFromQueryApplied = true;
    final q = GoRouterState.of(context).uri.queryParameters['type'];
    if (q == null) return;
    final match = _types.where((t) => IncidentProvider.typeToApi(t) == q);
    if (match.isNotEmpty) _type = match.first;
  }

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

  Future<void> _pickPhoto() async {
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

  void _next() {
    if (_step == 1 && !_formKey.currentState!.validate()) return;
    setState(() => _step++);
  }

  void _back() {
    if (_step == 0) {
      context.go('/home');
    } else {
      setState(() => _step--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          SaHeader(
            title: 'Nouveau signalement',
            subtitle: const ['Type d\'incident', 'Photo et description', 'Position et envoi'][_step],
            onBack: _back,
            bottom: _Stepper(step: _step),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(anim),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    children: [
                      if (_step == 0) ..._typeStep(),
                      if (_step == 1) ..._detailsStep(),
                      if (_step == 2) ..._positionStep(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: _step < 2
                  ? CustomButton(text: 'Suivant', icon: Icons.arrow_forward_rounded, onPressed: _next)
                  : Consumer<IncidentProvider>(
                      builder: (_, p, __) => CustomButton(
                        text: 'Envoyer le signalement',
                        icon: Icons.send_rounded,
                        color: AppColors.orangeDeep,
                        isLoading: p.isLoading,
                        onPressed: _submit,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ----- Étape 1 : type + région -----
  List<Widget> _typeStep() => [
        Text('Choisissez le type d\'incident', style: SaText.display(17)),
        const SizedBox(height: 4),
        Text('Sélectionnez la catégorie qui correspond le mieux.', style: SaText.body(13)),
        const SizedBox(height: 14),
        for (var i = 0; i < _types.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SaFadeSlide(index: i, child: _typeTile(_types[i])),
          ),
        const SizedBox(height: 8),
        _label('Région du Sénégal'),
        _dropdown(
          value: _selectedRegion,
          icon: Icons.map_rounded,
          items: _regions,
          onChanged: (v) => setState(() => _selectedRegion = v),
        ),
      ];

  Widget _typeTile(String label) {
    final t = SaIncidentType.of(label);
    final sel = _type == label;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: sel
            ? [BoxShadow(color: t.color.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6))]
            : null,
      ),
      child: SaCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: Border.all(color: sel ? t.color : AppColors.border, width: sel ? 1.8 : 1),
        onTap: () => setState(() => _type = label),
        child: Row(children: [
          SaTypeIcon(label, size: 44),
          const SizedBox(width: 14),
          Expanded(child: Text(t.label, style: SaText.body(14.5, color: AppColors.textDark, weight: FontWeight.w700))),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: sel
                ? Icon(Icons.check_circle_rounded, key: const ValueKey(1), color: t.color)
                : const Icon(Icons.chevron_right_rounded, key: ValueKey(0), color: AppColors.textMuted),
          ),
        ]),
      ),
    );
  }

  // ----- Étape 2 : photo + description -----
  List<Widget> _detailsStep() {
    final hasPhoto = _selectedImageBytes != null || _hasDemoPhoto;
    return [
      Row(children: [
        SaTypeIcon(_type, size: 36),
        const SizedBox(width: 10),
        Text(SaIncidentType.of(_type).label, style: SaText.display(16)),
      ]),
      const SizedBox(height: 18),
      _label('Photo de l\'incident'),
      GestureDetector(
        onTap: _pickPhoto,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 170,
          width: double.infinity,
          decoration: BoxDecoration(
            color: hasPhoto ? AppColors.emerald.withOpacity(0.06) : AppColors.blue50,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: hasPhoto ? AppColors.emerald : AppColors.blue600.withOpacity(0.35),
              width: hasPhoto ? 2 : 1.4,
            ),
          ),
          child: _selectedImageBytes != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.memory(_selectedImageBytes!, fit: BoxFit.cover),
                )
              : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: AppColors.navy800.withOpacity(0.08), blurRadius: 12)],
                    ),
                    child: Icon(_hasDemoPhoto ? Icons.check_rounded : Icons.add_a_photo_rounded,
                        color: _hasDemoPhoto ? AppColors.emerald : AppColors.blue600),
                  ),
                  const SizedBox(height: 10),
                  Text(_hasDemoPhoto ? 'Photo de l\'incident jointe' : 'Ajouter une photo',
                      style: SaText.body(14, color: AppColors.textDark, weight: FontWeight.w700)),
                  Text(_hasDemoPhoto ? '' : 'Choisir dans la galerie', style: SaText.body(12)),
                ]),
        ),
      ),
      const SizedBox(height: 18),
      _label('Description'),
      TextFormField(
        controller: _descCtrl,
        maxLines: 5,
        validator: (v) => v == null || v.isEmpty ? 'Description obligatoire' : null,
        decoration: const InputDecoration(hintText: 'Décrivez ce qui s\'est passé…'),
      ),
    ];
  }

  // ----- Étape 3 : position + récapitulatif -----
  List<Widget> _positionStep() => [
        _label('Localisation'),
        SaCard(
          padding: EdgeInsets.zero,
          onTap: _getLocation,
          child: Column(children: [
            Container(
              height: 120,
              decoration: const BoxDecoration(gradient: AppColors.headerGradient),
              child: Stack(alignment: Alignment.center, children: [
                Positioned.fill(child: CustomPaint(painter: _MapLinesPainter())),
                SaPulse(
                  size: 80,
                  color: _lat != null ? AppColors.emerald : AppColors.orange,
                  child: Icon(Icons.location_on_rounded,
                      size: 36, color: _lat != null ? const Color(0xFF34D399) : AppColors.orange),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Icon(Icons.my_location_rounded, color: _lat != null ? AppColors.emerald : AppColors.blue600),
                const SizedBox(width: 10),
                Expanded(
                  child: _loadingLoc
                      ? const Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.blue600)),
                        )
                      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_lat != null ? 'Position GPS détectée' : 'Utiliser ma position actuelle',
                              style: SaText.body(14, color: AppColors.textDark, weight: FontWeight.w700)),
                          Text(_locationText, style: SaText.body(12)),
                        ]),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        _label('Récapitulatif'),
        SaCard(
          child: Column(children: [
            _recap(Icons.category_rounded, 'Type', SaIncidentType.of(_type).label),
            _recap(Icons.map_rounded, 'Région', _selectedRegion),
            _recap(Icons.photo_rounded, 'Photo',
                (_selectedImageBytes != null || _hasDemoPhoto) ? 'Jointe' : 'Aucune'),
            _recap(Icons.notes_rounded, 'Description', _descCtrl.text, last: true),
          ]),
        ),
      ];

  Widget _recap(IconData icon, String k, String v, {bool last = false}) => Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: AppColors.textGrey),
          const SizedBox(width: 10),
          SizedBox(width: 90, child: Text(k, style: SaText.body(13))),
          Expanded(
            child: Text(v,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: SaText.body(13, color: AppColors.textDark, weight: FontWeight.w600)),
          ),
        ]),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: SaText.body(13.5, color: AppColors.textDark, weight: FontWeight.w700)),
      );

  Widget _dropdown({
    required String value,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: value,
            borderRadius: BorderRadius.circular(16),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textGrey),
            items: items
                .map((r) => DropdownMenuItem(
                      value: r,
                      child: Row(children: [
                        Icon(icon, size: 18, color: AppColors.blue600),
                        const SizedBox(width: 10),
                        Text(r, style: SaText.body(14, color: AppColors.textDark, weight: FontWeight.w600)),
                      ]),
                    ))
                .toList(),
            onChanged: (v) => onChanged(v!),
          ),
        ),
      );
}

class _Stepper extends StatelessWidget {
  final int step;
  const _Stepper({required this.step});

  @override
  Widget build(BuildContext context) {
    const labels = ['Type', 'Détails', 'Position'];
    return Row(
      children: List.generate(5, (i) {
        if (i.isOdd) {
          final done = step > i ~/ 2;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 3,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: done ? AppColors.orange : Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }
        final idx = i ~/ 2;
        final active = idx == step;
        final done = idx < step;
        return Column(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done || active ? AppColors.orange : Colors.white.withOpacity(0.12),
              border: Border.all(color: Colors.white.withOpacity(active ? 0.9 : 0.2), width: active ? 2 : 1),
            ),
            child: done
                ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                : Text('${idx + 1}', style: SaText.body(13, color: Colors.white, weight: FontWeight.w800)),
          ),
          const SizedBox(height: 4),
          Text(labels[idx], style: SaText.body(11, color: Colors.white.withOpacity(active ? 1 : 0.7))),
        ]);
      }),
    );
  }
}

/// Lignes de « carte » décoratives (pas de vraies tuiles : la position
/// réelle est affichée en texte).
class _MapLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
        Path()
          ..moveTo(0, s.height * 0.7)
          ..quadraticBezierTo(s.width * 0.4, s.height * 0.4, s.width, s.height * 0.6),
        p);
    canvas.drawLine(Offset(s.width * 0.3, 0), Offset(s.width * 0.45, s.height), p..strokeWidth = 4);
    canvas.drawLine(Offset(s.width * 0.75, 0), Offset(s.width * 0.6, s.height), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
