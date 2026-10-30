import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api.dart';

/// Cloche des notifications avec le nombre de messages non lus, posée sur un fond sombre.
class ClocheNotifications extends StatefulWidget {
  const ClocheNotifications({super.key});
  @override
  State<ClocheNotifications> createState() => _ClocheNotificationsState();
}

class _ClocheNotificationsState extends State<ClocheNotifications> {
  int _nonLues = 0;
  Timer? _minuteur;

  @override
  void initState() {
    super.initState();
    _charger();
    _minuteur = Timer.periodic(const Duration(seconds: 30), (_) => _charger());
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      final r = await Api.instance.get<Map<String, dynamic>>('/notifications/compteur/');
      if (mounted) setState(() => _nonLues = (r['non_lues'] as num?)?.toInt() ?? 0);
    } on ApiException {
      // Compteur indicatif : la page Notifications affiche l'erreur réseau.
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: _nonLues > 0 ? 'Notifications ($_nonLues non lues)' : 'Notifications',
        onPressed: () => context.push('/notifications').then((_) => _charger()),
        icon: Badge(
          isLabelVisible: _nonLues > 0,
          label: Text(_nonLues > 99 ? '99+' : '$_nonLues'),
          child: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 26),
        ),
      );
}
