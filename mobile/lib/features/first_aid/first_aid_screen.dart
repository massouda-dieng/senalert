import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:senalert_mobile/core/constants/app_colors.dart';
import 'package:senalert_mobile/shared/widgets/sa_ui.dart';

// ─── Clé API Groq via dart-define (jamais en dur dans le code) ───────────────
// Lancement : flutter run --dart-define=GROQ_API_KEY=gsk_xxx
// En production : flutter build apk --dart-define=GROQ_API_KEY=gsk_xxx
const _kGroqKey = String.fromEnvironment('GROQ_API_KEY', defaultValue: '');

// ─── Prompt système : rôle, langue, numéros d'urgence Sénégal ────────────────
const _kSystemPrompt = '''
Tu es SenAlert AI, l'assistant officiel de la plateforme d'urgences citoyennes du Sénégal.
Règles absolues :
- Réponds TOUJOURS en français, de façon concise et structurée (bullet points ou numérotation).
- Garde le contexte de la conversation : tu te souviens de tout ce qui a été dit.
- Pour toute urgence vitale, cite les numéros : SAMU 15 · Pompiers 18 · Police 17 · SOS Urgences 1515.
- Si tu ne sais pas, dis-le honnêtement au lieu d'inventer.
- Limite tes réponses à 400 mots maximum.
- Tu peux utiliser des emojis avec modération pour améliorer la lisibilité.
''';

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  });
}

class FirstAidScreen extends StatefulWidget {
  const FirstAidScreen({super.key});

  @override
  State<FirstAidScreen> createState() => _FirstAidScreenState();
}

class _FirstAidScreenState extends State<FirstAidScreen> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  bool _isTyping = false;

  // Historique de la conversation (envoyé à Groq à chaque tour)
  final List<Map<String, String>> _history = [];

  final List<_ChatMessage> _messages = [
    _ChatMessage(
      text: 'Bonjour ! Je suis **SenAlert AI** 🤖\n\n'
          'Posez-moi n\'importe quelle question sur les **premiers secours**, '
          'les **risques au Sénégal** ou choisissez une urgence ci-dessous.\n\n'
          '🆘 SAMU **15** · Pompiers **18** · Police **17**',
      isUser: false,
      timestamp: DateTime.now(),
    ),
  ];

  final List<Map<String, String>> _chips = [
    {'icon': '🚑', 'label': 'Arrêt cardiaque / RCP',   'q': 'Que faire en cas d\'arrêt cardiaque ? Explique le RCP étape par étape.'},
    {'icon': '🔥', 'label': 'Incendie & fumée',          'q': 'Que faire en cas d\'incendie ou d\'inhalation de fumée ?'},
    {'icon': '🌊', 'label': 'Inondation',                'q': 'Comment réagir face à une inondation à Dakar ?'},
    {'icon': '🐍', 'label': 'Morsure de serpent',        'q': 'Comment traiter une morsure de serpent au Sénégal ?'},
    {'icon': '⚡', 'label': 'Électrocution',              'q': 'Que faire en cas d\'électrocution ?'},
    {'icon': '🩸', 'label': 'Hémorragie abondante',      'q': 'Comment stopper une forte hémorragie ?'},
    {'icon': '🤒', 'label': 'Malaise / évanouissement',  'q': 'Que faire si quelqu\'un s\'évanouit ?'},
    {'icon': '🌡️', 'label': 'Coup de chaleur',           'q': 'Comment traiter un coup de chaleur ou une insolation ?'},
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Envoi avec historique complet ──────────────────────────────────────────
  Future<void> _send(String text) async {
    final q = text.trim();
    if (q.isEmpty || _isTyping) return;

    // Ajouter le message utilisateur
    _history.add({'role': 'user', 'content': q});
    setState(() {
      _messages.add(_ChatMessage(text: q, isUser: true, timestamp: DateTime.now()));
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();

    // Construire les messages avec historique complet
    final payload = [
      {'role': 'system', 'content': _kSystemPrompt},
      ..._history,
    ];

    // Si pas de clé → mode hors-ligne direct
    if (_kGroqKey.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(_ChatMessage(
          text: _fallback(q),
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
      return;
    }

    try {
      final res = await Dio().post(
        'https://api.groq.com/openai/v1/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_kGroqKey',
            'Content-Type': 'application/json',
          },
          sendTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 15),
        ),
        data: {
          'model': 'qwen/qwen3.8-27b',   // Modèle confirmé actif sur ce compte Groq
          'messages': payload,
          'max_tokens': 600,
          'temperature': 0.5,
        },
      );

      final content = res.data?['choices']?[0]?['message']?['content']?.toString().trim();
      if (content != null && content.isNotEmpty) {
        _history.add({'role': 'assistant', 'content': content});
        if (!mounted) return;
        setState(() {
          _isTyping = false;
          _messages.add(_ChatMessage(text: content, isUser: false, timestamp: DateTime.now()));
        });
        _scrollToBottom();
        return;
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      String errMsg;
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        errMsg = '⏱️ Délai dépassé. Vérifiez votre connexion internet et réessayez.';
      } else if (code == 429) {
        errMsg = '🔄 Trop de requêtes. Attendez quelques secondes puis réessayez.';
      } else if (code != null && code >= 500) {
        errMsg = '⚠️ Le service IA est temporairement indisponible. Voici une réponse de secours :';
      } else {
        errMsg = '📵 Pas de connexion internet.';
      }
      // Retirer le dernier message user de l'historique (échec)
      if (_history.isNotEmpty && _history.last['role'] == 'user') _history.removeLast();
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(_ChatMessage(
          text: '$errMsg\n\n${_fallback(q)}',
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ));
      });
      _scrollToBottom();
      return;
    } catch (_) {}

    // Fallback enrichi
    if (_history.isNotEmpty && _history.last['role'] == 'user') _history.removeLast();
    if (!mounted) return;
    setState(() {
      _isTyping = false;
      _messages.add(_ChatMessage(
        text: _fallback(q),
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  // ── Réponses locales enrichies (fallback sans internet) ────────────────────
  String _fallback(String q) {
    final lq = q.toLowerCase();

    if (_matches(lq, ['cardiaque', 'rcp', 'coeur', 'réanima', 'massage'])) {
      return '🚑 **ARRÊT CARDIAQUE — Protocole RCP**\n\n'
          '1. Vérifiez la sécurité des lieux\n'
          '2. Appelez le **SAMU au 15** immédiatement\n'
          '3. Allongez la victime sur le dos, surface dure\n'
          '4. **30 compressions** au centre du thorax (fort, rapide ~100/min)\n'
          '5. **2 insufflations** bouche-à-bouche\n'
          '6. Répétez jusqu\'à l\'arrivée des secours\n\n'
          '_Ne vous arrêtez pas. Chaque minute compte._';
    }
    if (_matches(lq, ['incendie', 'feu', 'fumée', 'brûlure', 'flamme'])) {
      return '🔥 **INCENDIE — Consignes de sécurité**\n\n'
          '1. Alertez les occupants et **évacuez immédiatement**\n'
          '2. Rampez sous la fumée (l\'air pur est près du sol)\n'
          '3. Fermez les portes derrière vous (ralentit les flammes)\n'
          '4. N\'utilisez jamais l\'ascenseur\n'
          '5. Appelez les **Pompiers au 18** depuis l\'extérieur\n'
          '6. Ne revenez jamais dans un bâtiment en feu\n\n'
          '🔥 **Brûlure** : eau froide 10–15 min, ne percez pas les cloques.';
    }
    if (_matches(lq, ['inondation', 'pluie', 'eau', 'fleuve', 'noyade'])) {
      return '🌊 **INONDATION — Réflexes vitaux**\n\n'
          '1. Coupez **électricité** et **gaz** immédiatement\n'
          '2. Montez dans les étages avec téléphones et papiers\n'
          '3. **Ne traversez jamais** une zone inondée (même en voiture)\n'
          '4. Signalez-vous aux secours avec une torche ou un vêtement\n'
          '5. Suivez les annonces officielles\n\n'
          '🆘 **Noyade** : ne sautez pas. Tendez un objet (corde, vêtement).';
    }
    if (_matches(lq, ['serpent', 'morsure', 'scorpion', 'venin', 'piqûre'])) {
      return '🐍 **MORSURE DE SERPENT / SCORPION**\n\n'
          '1. Restez **calme et immobile** (réduit la propagation du venin)\n'
          '2. Allongez le membre touché **sous le niveau du cœur**\n'
          '3. ❌ NE PAS : inciser, sucer, poser de garrot serré, appliquer de glace\n'
          '4. Notez l\'heure de la morsure et la description du serpent\n'
          '5. Transportez d\'urgence vers un **centre de santé** ou appelez le **SAMU 15**';
    }
    if (_matches(lq, ['électrocution', 'électr', 'courant', 'jus', 'electr'])) {
      return '⚡ **ÉLECTROCUTION**\n\n'
          '1. **NE TOUCHEZ PAS la victime** si le courant est encore actif !\n'
          '2. Coupez le **disjoncteur général**\n'
          '3. Éloignez la source avec un objet isolant sec (bois, plastique)\n'
          '4. Appelez **Pompiers 18** et commencez la RCP si inconscient\n'
          '5. Même sans blessure visible, consultation médicale obligatoire';
    }
    if (_matches(lq, ['saignement', 'hémorragie', 'sang', 'plaie', 'coupure'])) {
      return '🩸 **HÉMORRAGIE — Arrêter le saignement**\n\n'
          '1. **Pression directe forte** avec tissu propre ou pansement stérile\n'
          '2. Maintenez la pression **sans relâcher** (10–15 min minimum)\n'
          '3. Allongez la victime, surélevez le membre si possible\n'
          '4. **Garrot** uniquement si hémorragie artérielle incontrôlable :\n'
          '   - 5–7 cm au-dessus de la plaie\n'
          '   - Notez l\'heure de pose\n'
          '5. Appelez le **SAMU au 15**';
    }
    if (_matches(lq, ['évanoui', 'évanouissement', 'malaise', 'inconscient', 'syncope'])) {
      return '😵 **ÉVANOUISSEMENT / MALAISE**\n\n'
          '1. Allongez la personne et **surélevez les jambes** (30 cm)\n'
          '2. Desserrez les vêtements serrés\n'
          '3. Assurez-vous qu\'elle **respire** — si non, démarrez la RCP\n'
          '4. **Position latérale de sécurité** si elle respire mais reste inconsciente\n'
          '5. Ne lui donnez rien à boire ni à manger\n'
          '6. Appelez **SAMU 15** si elle ne reprend pas conscience en 1 min';
    }
    if (_matches(lq, ['chaleur', 'insolation', 'coup de soleil', 'déshydrat'])) {
      return '🌡️ **COUP DE CHALEUR / INSOLATION**\n\n'
          '1. Transportez la personne à l\'**ombre** ou dans un endroit frais\n'
          '2. Allongez-la et surélevez légèrement les jambes\n'
          '3. Rafraîchissez : eau fraîche sur le corps, ventilateur\n'
          '4. **Hydratez** si elle est consciente (eau, pas de boissons sucrées)\n'
          '5. ⚠️ Temp > 40°C = urgence → **SAMU 15** immédiatement\n\n'
          '_Prévention : évitez le soleil 12h–16h, buvez 2 L/jour minimum._';
    }

    // Réponse générique
    return '🤖 **SenAlert AI — Conseil général**\n\n'
        'Pour la situation que vous décrivez :\n'
        '1. **Sécurisez** la zone (protégez-vous et la victime)\n'
        '2. **Évaluez** l\'état : conscience, respiration\n'
        '3. **Appelez les secours** :\n'
        '   - SAMU **15** (urgences médicales)\n'
        '   - Pompiers **18** (incendie, accident)\n'
        '   - Police **17** (sécurité)\n'
        '   - SOS Urgences **1515**\n'
        '4. **Signalez** votre position sur SenAlert\n\n'
        '_⚠️ Mode hors-ligne — Reconnectez-vous pour des réponses personnalisées._';
  }

  bool _matches(String q, List<String> keywords) =>
      keywords.any((k) => q.contains(k));

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isFirstMsg = _messages.length == 1 && !_isTyping;

    return Scaffold(
      backgroundColor: AppColors.navy900,
      body: SaNightBackdrop(
        child: SafeArea(
          bottom: false,
          child: Column(children: [
            _buildHeader(context),
            if (!isFirstMsg) _buildChipsBar(),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  itemCount: _messages.length +
                      (_isTyping ? 1 : 0) +
                      (isFirstMsg ? 1 : 0),
                  itemBuilder: (ctx, idx) {
                    if (isFirstMsg && idx == 0) return _WelcomeHero(chips: _chips, onTap: _send);
                    final i = isFirstMsg ? idx - 1 : idx;
                    if (i == _messages.length && _isTyping) return const _TypingBubble();
                    if (i >= _messages.length) return const SizedBox.shrink();
                    return _ChatBubble(msg: _messages[i]);
                  },
                ),
              ),
            ),
            _buildInput(),
          ]),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 6),
      child: Row(children: [
        SaIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Retour',
          onTap: () => context.go('/home'),
        ),
        const SizedBox(width: 10),
        const SaRobotAvatar(size: 42, animate: true),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Assistant IA', style: SaText.display(17, color: Colors.white)),
            Row(children: [
              Container(
                width: 7, height: 7,
                decoration: const BoxDecoration(color: Color(0xFF34D399), shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  'SAMU 15 · Pompiers 18 · Police 17',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SaText.body(11.5, color: Colors.white.withOpacity(0.65)),
                ),
              ),
            ]),
          ]),
        ),
        // Bouton effacer la conversation
        if (_messages.length > 1)
          SaIconButton(
            icon: Icons.restart_alt_rounded,
            tooltip: 'Nouvelle conversation',
            onTap: () => setState(() {
              _messages.removeRange(1, _messages.length);
              _history.clear();
            }),
          ),
      ]),
    );
  }

  Widget _buildChipsBar() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _chips.length,
        itemBuilder: (_, i) {
          final c = _chips[i];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: _isTyping ? null : () => _send(c['q']!),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _isTyping
                      ? Colors.white.withOpacity(0.05)
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: Text(
                  '${c['icon']} ${c['label']}',
                  style: SaText.body(12,
                      color: _isTyping
                          ? Colors.white.withOpacity(0.4)
                          : Colors.white,
                      weight: FontWeight.w600),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      color: AppColors.background,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy800.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  style: SaText.body(14.5, color: AppColors.textDark),
                  decoration: InputDecoration(
                    hintText: _isTyping
                        ? 'SenAlert AI répond…'
                        : 'Posez votre question d\'urgence…',
                    hintStyle: SaText.body(14, color: AppColors.textMuted),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onSubmitted: _send,
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _isTyping ? null : AppColors.actionGradient,
                  color: _isTyping ? AppColors.border : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _isTyping ? null : () => _send(_controller.text),
                    child: Icon(
                      _isTyping ? Icons.hourglass_top_rounded : Icons.send_rounded,
                      color: _isTyping ? AppColors.textMuted : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Écran d'accueil avec suggestions cliquables ─────────────────────────────
class _WelcomeHero extends StatelessWidget {
  final List<Map<String, String>> chips;
  final void Function(String) onTap;
  const _WelcomeHero({required this.chips, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Avatar + titre centré
        Center(
          child: Column(children: [
            const SaRobotAvatar(size: 80, animate: true),
            const SizedBox(height: 10),
            Text('SenAlert AI', style: SaText.display(20, color: AppColors.textDark)),
            const SizedBox(height: 4),
            Text(
              'Assistant premiers secours · disponible 24h/24',
              style: SaText.body(13, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
        const SizedBox(height: 20),
        // Numéros d'urgence
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.crimson.withOpacity(0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.crimson.withOpacity(0.15)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _UrgenceNum('SAMU', '15', AppColors.crimson),
              _divider(),
              _UrgenceNum('Pompiers', '18', AppColors.orangeDeep),
              _divider(),
              _UrgenceNum('Police', '17', AppColors.navy800),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Situations fréquentes',
            style: SaText.body(13, color: AppColors.textDark, weight: FontWeight.w700)),
        const SizedBox(height: 10),
        // Grille de suggestions
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.6,
          children: chips.map((c) => _ChipCard(
            icon: c['icon']!,
            label: c['label']!,
            onTap: () => onTap(c['q']!),
          )).toList(),
        ),
      ]),
    );
  }

  Widget _divider() => Container(
      width: 1, height: 30, color: AppColors.crimson.withOpacity(0.2));
}

class _UrgenceNum extends StatelessWidget {
  final String label, num;
  final Color color;
  const _UrgenceNum(this.label, this.num, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(num, style: SaText.display(22, color: color, weight: FontWeight.w900)),
      Text(label, style: SaText.body(11, color: AppColors.textMuted, weight: FontWeight.w600)),
    ]);
  }
}

class _ChipCard extends StatefulWidget {
  final String icon, label;
  final VoidCallback onTap;
  const _ChipCard({required this.icon, required this.label, required this.onTap});

  @override
  State<_ChipCard> createState() => _ChipCardState();
}

class _ChipCardState extends State<_ChipCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _pressed ? AppColors.navy800.withOpacity(0.06) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _pressed ? AppColors.navy800.withOpacity(0.3) : AppColors.border,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
            ],
          ),
          child: Row(children: [
            Text(widget.icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.label,
                maxLines: 2,
                style: SaText.body(12, color: AppColors.textDark, weight: FontWeight.w600)
                    .copyWith(height: 1.25),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Bulle de message ─────────────────────────────────────────────────────────
class _ChatBubble extends StatelessWidget {
  final _ChatMessage msg;
  const _ChatBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final hh = '${msg.timestamp.hour.toString().padLeft(2, '0')}:'
        '${msg.timestamp.minute.toString().padLeft(2, '0')}';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(msg.isUser ? 20 * (1 - v) : -20 * (1 - v), 0),
          child: c,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          mainAxisAlignment:
              msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!msg.isUser) ...[
              const SaRobotAvatar(size: 30),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                decoration: BoxDecoration(
                  gradient: msg.isUser ? AppColors.actionGradient : null,
                  color: msg.isUser
                      ? null
                      : msg.isError
                          ? const Color(0xFFFFF7ED)
                          : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(msg.isUser ? 20 : 4),
                    bottomRight: Radius.circular(msg.isUser ? 4 : 20),
                  ),
                  border: msg.isUser
                      ? null
                      : Border.all(
                          color: msg.isError
                              ? AppColors.orange.withOpacity(0.4)
                              : AppColors.border,
                        ),
                  boxShadow: [
                    BoxShadow(
                      color: (msg.isUser ? AppColors.blue600 : AppColors.navy800)
                          .withOpacity(msg.isUser ? 0.2 : 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SelectableText(
                      msg.text,
                      style: SaText.body(
                        14,
                        color: msg.isUser ? Colors.white : AppColors.textDark,
                        weight: FontWeight.w500,
                      ).copyWith(height: 1.55),
                    ),
                    const SizedBox(height: 4),
                    Text(hh,
                        style: SaText.body(
                          10.5,
                          color: msg.isUser
                              ? Colors.white70
                              : AppColors.textMuted,
                        )),
                  ],
                ),
              ),
            ),
            if (msg.isUser) const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Indicateur « en train d'écrire » ────────────────────────────────────────
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const SaRobotAvatar(size: 30, animate: true),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
              bottomLeft: Radius.circular(4),
            ),
            border: Border.all(color: AppColors.border),
          ),
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final t = ((_c.value - i * 0.2) % 1.0).clamp(0.0, 1.0);
                final y = t < 0.5
                    ? -6 * Curves.easeOut.transform(t * 2)
                    : -6 * (1 - Curves.easeIn.transform((t - 0.5) * 2));
                return Transform.translate(
                  offset: Offset(0, y),
                  child: Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: Color.lerp(
                          AppColors.textMuted, AppColors.blue600, -y / 6),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ]),
    );
  }
}
