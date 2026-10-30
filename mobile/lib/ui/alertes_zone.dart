import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/constants/app_colors.dart';

/// Bandeau des alertes de zone en cours pour une région (information publique).
class BandeauAlertesZone extends StatefulWidget {
  final String? region;
  const BandeauAlertesZone({super.key, this.region});
  @override
  State<BandeauAlertesZone> createState() => _BandeauAlertesZoneState();
}

class _BandeauAlertesZoneState extends State<BandeauAlertesZone> {
  List<Map<String, dynamic>> _alertes = [];
  final Set<int> _masquees = {};

  @override
  void initState() {
    super.initState();
    Api.instance.get<Map<String, dynamic>>('/alertes/zones/', params: {'en_cours': 1, 'region': widget.region}).then((r) {
      if (mounted) setState(() => _alertes = List<Map<String, dynamic>>.from(r['results']));
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final visibles = _alertes.where((a) => !_masquees.contains(a['id'])).take(2).toList();
    return Column(children: [
      for (final a in visibles)
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          decoration: BoxDecoration(
            color: a['niveau'] == 'danger' ? const Color(0xFFFDE3E4) : a['niveau'] == 'vigilance' ? AppColors.jauneClair : AppColors.vert50,
            borderRadius: BorderRadius.circular(16),
            border: Border(left: BorderSide(width: 4, color: a['niveau'] == 'danger' ? AppColors.crimson : a['niveau'] == 'vigilance' ? const Color(0xFFF5D90A) : AppColors.vert600)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.campaign_rounded, color: AppColors.textDark),
            const SizedBox(width: 10),
            Expanded(child: Text.rich(TextSpan(children: [
              TextSpan(text: '${a['titre']}\n', style: const TextStyle(fontWeight: FontWeight.w800)),
              TextSpan(text: a['message']),
            ]), style: const TextStyle(color: AppColors.textDark, height: 1.35))),
            IconButton(tooltip: 'Masquer', visualDensity: VisualDensity.compact, onPressed: () => setState(() => _masquees.add(a['id'])),
                icon: const Icon(Icons.close, size: 18, color: AppColors.textDark)),
          ]),
        ),
    ]);
  }
}
