import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:senalert_mobile/core/constants/app_colors.dart';

/// Enum representing the UX severity levels for national alerts.
enum AlertSeverity { info, vigilance, danger, urgence }

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const _SenAlertAppBar(),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Dark Institutional Header Section
            const _HeaderHeroSection(),

            const SizedBox(height: 20),

            // Main Content Area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Actions Grid Title & Subtitle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Actions Rapides & Services',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Accès direct aux services de secours',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textGrey.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.darkSlate.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.shield_outlined, size: 13, color: AppColors.darkSlate),
                            SizedBox(width: 4),
                            Text(
                              '6 Services',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkSlate,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Unified Responsive Action Cards Grid
                  const _QuickActionGrid(),

                  const SizedBox(height: 28),

                  // Real-time Emergency Statistics Section
                  const _StatSection(),

                  const SizedBox(height: 28),

                  // Recent Incidents Feed Section
                  const _RecentIncidentsSection(),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const _SenAlertBottomNavBar(currentIndex: 0),
    );
  }
}

/// App Bar component with institutional header branding & notifications
class _SenAlertAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _SenAlertAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.darkSlate,
      elevation: 0,
      toolbarHeight: 64,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.crimson,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppColors.crimson.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/senalert_logo.png',
              height: 22,
              width: 22,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.shield_rounded,
                color: AppColors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    'SenAlert',
                    style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'SN',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'Réseau National Actif',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Notifications',
          icon: Stack(
            children: [
              const Icon(Icons.notifications_none_rounded, color: AppColors.white, size: 24),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.crimson,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          onPressed: () {},
        ),
        IconButton(
          tooltip: 'Profil',
          icon: const Icon(Icons.account_circle_outlined, color: AppColors.white, size: 25),
          onPressed: () => context.go('/profile'),
        ),
        const SizedBox(width: 6),
      ],
    );
  }
}

/// Dark Hero Section containing national metadata, alert banner, and SOS button
class _HeaderHeroSection extends StatelessWidget {
  const _HeaderHeroSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.darkSlate,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Stack(
        children: [
          // Signature SenAlert Watermark Emblem
          Positioned(
            right: -20,
            top: -20,
            child: Opacity(
              opacity: 0.05,
              child: Image.asset(
                'assets/images/senalert_logo.png',
                height: 170,
                width: 170,
                fit: BoxFit.contain,
              ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SERVICE NATIONAL D\'ALERTE & DE SECOURS',
                style: TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'RÉPUBLIQUE DU SÉNÉGAL',
                style: TextStyle(
                  color: AppColors.textGrey.withOpacity(0.8),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // National Weather Alert Notification Banner
          const _AlertBanner(
            severity: AlertSeverity.vigilance,
            title: 'VIGILANCE MÉTÉO SÉNÉGAL',
            message: 'Risque de fortes pluies & orages à Dakar, Thiès & Kaolack.',
            timeInfo: 'Aujourd\'hui 14h - 20h',
          ),

          const SizedBox(height: 14),

          // Primary Reassuring SOS Panic Trigger Card
          const _SosButton(),
        ],
      ),
    ],
  ),
);
  }
}



/// Dynamic Alert Banner Component with 4 Severity Levels
class _AlertBanner extends StatelessWidget {
  final AlertSeverity severity;
  final String title;
  final String message;
  final String timeInfo;

  const _AlertBanner({
    required this.severity,
    required this.title,
    required this.message,
    required this.timeInfo,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getSeverityConfig(severity);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: config.borderColor, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: config.iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(config.icon, color: config.accentColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: config.accentColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: config.accentColor.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        config.pillLabel,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: config.accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 11, color: Colors.white.withOpacity(0.7)),
                    const SizedBox(width: 4),
                    Text(
                      timeInfo,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _SeverityConfig _getSeverityConfig(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.info:
        return _SeverityConfig(
          pillLabel: 'INFO',
          icon: Icons.info_outline_rounded,
          accentColor: AppColors.alertInfo,
          backgroundColor: AppColors.alertInfo.withOpacity(0.12),
          borderColor: AppColors.alertInfo.withOpacity(0.4),
          iconBgColor: AppColors.alertInfo.withOpacity(0.2),
        );
      case AlertSeverity.vigilance:
        return _SeverityConfig(
          pillLabel: 'VIGILANCE',
          icon: Icons.campaign_rounded,
          accentColor: AppColors.alertVigilance,
          backgroundColor: AppColors.alertVigilance.withOpacity(0.15),
          borderColor: AppColors.alertVigilance.withOpacity(0.5),
          iconBgColor: AppColors.alertVigilance.withOpacity(0.25),
        );
      case AlertSeverity.danger:
        return _SeverityConfig(
          pillLabel: 'DANGER',
          icon: Icons.warning_amber_rounded,
          accentColor: AppColors.alertDanger,
          backgroundColor: AppColors.alertDanger.withOpacity(0.18),
          borderColor: AppColors.alertDanger.withOpacity(0.6),
          iconBgColor: AppColors.alertDanger.withOpacity(0.3),
        );
      case AlertSeverity.urgence:
        return _SeverityConfig(
          pillLabel: 'URGENCE MAX',
          icon: Icons.error_outline_rounded,
          accentColor: AppColors.alertUrgence,
          backgroundColor: AppColors.alertUrgence.withOpacity(0.22),
          borderColor: AppColors.alertUrgence.withOpacity(0.7),
          iconBgColor: AppColors.alertUrgence.withOpacity(0.35),
        );
    }
  }
}

class _SeverityConfig {
  final String pillLabel;
  final IconData icon;
  final Color accentColor;
  final Color backgroundColor;
  final Color borderColor;
  final Color iconBgColor;

  _SeverityConfig({
    required this.pillLabel,
    required this.icon,
    required this.accentColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.iconBgColor,
  });
}

/// Primary SOS Panic Trigger Card (Reassuring & Highly Accessible)
class _SosButton extends StatelessWidget {
  const _SosButton();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/sos'),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.crimson,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppColors.crimson.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Row(
          children: [
            // Circular SOS Action Badge Icon
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.touch_app_rounded,
                  color: AppColors.crimson,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Content Typography
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'BOUTON SOS PANIQUE',
                        style: TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Hold 3s',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Alerter les secours • Géolocalisation GPS active',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Arrow Prompt
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.white,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Unified Cohesive Quick Action Grid with Responsive Layout
class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 2;
        double childAspectRatio = 1.12;

        if (constraints.maxWidth > 900) {
          crossAxisCount = 4;
          childAspectRatio = 1.35;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 3;
          childAspectRatio = 1.25;
        } else if (constraints.maxWidth < 360) {
          crossAxisCount = 2;
          childAspectRatio = 0.95;
        }

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: childAspectRatio,
          children: [
            _QuickActionTile(
              title: 'Signaler une Urgence',
              subtitle: 'Photo, Vidéo & GPS',
              tag: 'URGENT',
              icon: Icons.add_alert_rounded,
              accentColor: AppColors.crimson,
              onTap: () => context.go('/report'),
            ),
            _QuickActionTile(
              title: 'Carte GPS Interactive',
              subtitle: 'Alertes en temps réel',
              tag: 'LIVE MAP',
              icon: Icons.map_rounded,
              accentColor: AppColors.navy,
              onTap: () => context.go('/map'),
            ),
            _QuickActionTile(
              title: 'Services de Secours',
              subtitle: 'Hôpitaux, Police, Sapeurs',
              tag: 'PROXIMITÉ',
              icon: Icons.local_hospital_rounded,
              accentColor: AppColors.darkSlate,
              onTap: () => context.go('/services'),
            ),
            _QuickActionTile(
              title: 'Assistant IA Secours',
              subtitle: 'Secourisme & IA 24h/7d',
              tag: 'IA CONSEIL 🤖',
              icon: Icons.smart_toy_rounded,
              accentColor: AppColors.emerald,
              onTap: () => context.go('/first-aid'),
            ),
            _QuickActionTile(
              title: 'Liste des Incidents',
              subtitle: 'Fil d\'alertes publiques',
              tag: 'FLUX DIRECT',
              icon: Icons.format_list_bulleted_rounded,
              accentColor: AppColors.info,
              onTap: () => context.go('/incidents'),
            ),
            _QuickActionTile(
              title: 'Numéros SOS 24/7',
              subtitle: 'Appels 18, 17, 15 direct',
              tag: 'SOS DIRECT',
              icon: Icons.phone_in_talk_rounded,
              accentColor: AppColors.warning,
              onTap: () => context.go('/sos'),
            ),
          ],
        );
      },
    );
  }
}

/// Unified SenAlert Action Tile Card Component
class _QuickActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String tag;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Row: Colored Accent Icon Badge & Category Tag Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        icon,
                        color: accentColor,
                        size: 24,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accentColor.withOpacity(0.2)),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),

                // Bottom Text Hierarchy
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textGrey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.textGrey.withOpacity(0.6),
                          size: 13,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Real-time Rescue Activity Statistics Component
class _StatSection extends StatelessWidget {
  const _StatSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Activité des Secours',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                letterSpacing: -0.4,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  'Aujourd\'hui',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatBadge(
              label: 'Signalés',
              value: '142',
              icon: Icons.warning_amber_rounded,
              color: AppColors.darkSlate,
              bgTint: AppColors.darkSlate.withOpacity(0.08),
            ),
            const SizedBox(width: 10),
            _StatBadge(
              label: 'En cours',
              value: '18',
              icon: Icons.run_circle_outlined,
              color: AppColors.warning,
              bgTint: AppColors.warning.withOpacity(0.1),
            ),
            const SizedBox(width: 10),
            _StatBadge(
              label: 'Pris en charge',
              value: '124',
              icon: Icons.verified_user_rounded,
              color: AppColors.emerald,
              bgTint: AppColors.emerald.withOpacity(0.1),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgTint;

  const _StatBadge({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgTint,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: bgTint,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Recent Incidents Feed Component
class _RecentIncidentsSection extends StatelessWidget {
  const _RecentIncidentsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Dernières Alertes Nationales',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                letterSpacing: -0.4,
              ),
            ),
            TextButton.icon(
              onPressed: () => context.go('/incidents'),
              icon: const Icon(Icons.arrow_forward_rounded, size: 15),
              label: const Text('Tout voir'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.crimson,
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        _RecentIncidentCard(
          title: 'Accident de circulation grave',
          location: 'Autoroute à Péage, Sortie Rufisque',
          time: 'Il y a 12 min',
          type: 'accident',
          status: 'Pompiers en route',
          statusColor: AppColors.warning,
        ),
        const SizedBox(height: 10),
        _RecentIncidentCard(
          title: 'Début d\'incendie entrepôt',
          location: 'Zone Industrielle de Mbao, Dakar',
          time: 'Il y a 45 min',
          type: 'incendie',
          status: 'Intervention en cours',
          statusColor: AppColors.crimson,
        ),
      ],
    );
  }
}

class _RecentIncidentCard extends StatelessWidget {
  final String title;
  final String location;
  final String time;
  final String type;
  final String status;
  final Color statusColor;

  const _RecentIncidentCard({
    required this.title,
    required this.location,
    required this.time,
    required this.status,
    required this.statusColor,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              type == 'incendie'
                  ? Icons.local_fire_department_rounded
                  : Icons.car_crash_rounded,
              color: statusColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textGrey),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                time,
                style: const TextStyle(fontSize: 10, color: AppColors.textGrey, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Redesigned Bottom Navigation Bar with Highlighted Center Button
class _SenAlertBottomNavBar extends StatelessWidget {
  final int currentIndex;

  const _SenAlertBottomNavBar({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        elevation: 0,
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.crimson,
        unselectedItemColor: AppColors.textGrey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        type: BottomNavigationBarType.fixed,
        onTap: (i) {
          if (i == 1) context.go('/incidents');
          if (i == 2) context.go('/report');
          if (i == 3) context.go('/first-aid');
          if (i == 4) context.go('/profile');
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Accueil',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_rounded),
            label: 'Incidents',
          ),
          // Signaler: Highlighted Primary Action Center Button
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.crimson,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.crimson.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.add_rounded, color: AppColors.white, size: 22),
            ),
            label: 'Signaler',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.medical_services_rounded),
            label: 'Secours',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
