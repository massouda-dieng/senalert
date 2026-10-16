import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:senalert_mobile/core/constants/app_colors.dart';

class FirstAidScreen extends StatefulWidget {
  const FirstAidScreen({super.key});

  @override
  State<FirstAidScreen> createState() => _FirstAidScreenState();
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class _FirstAidScreenState extends State<FirstAidScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  final List<_ChatMessage> _messages = [
    _ChatMessage(
      text: "Bonjour ! Je suis l'Assistant IA Secours de SenAlert 🤖.\n\n"
          "Posez-moi n'importe quelle question sur les premiers secours, la gestion des risques au Sénégal ou choisissez un cas d'urgence ci-dessous.",
      isUser: false,
      timestamp: DateTime.now(),
    ),
  ];

  final List<Map<String, String>> _promptChips = [
    {'label': '🚑 Arrêt cardiaque / RCP', 'query': 'Que faire en cas d\'arrêt cardiaque ?'},
    {'label': '🔥 Incendie & Fumée', 'query': 'Que faire en cas d\'incendie ou de fumée ?'},
    {'label': '🌊 Inondation à Dakar', 'query': 'Comment réagir face à une inondation ?'},
    {'label': '🐍 Morsure de serpent', 'query': 'Comment traiter une morsure de serpent ?'},
    {'label': '⚡ Électrocution', 'query': 'Que faire en cas d\'accident électrique ?'},
    {'label': '🩸 Saignement massif', 'query': 'Comment stopper une forte hémorragie ?'},
  ];

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMessage = _ChatMessage(
      text: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isTyping = true;
    });

    _controller.clear();
    _scrollToBottom();

    // Direct call to Groq AI API (Llama-3.3-70B) with instant fallback
    const groqApiKey = '${GROQ_API_KEY}';
    try {
      final directDio = Dio();
      final res = await directDio.post(
        'https://api.groq.com/openai/v1/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $groqApiKey',
            'Content-Type': 'application/json',
          },
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
        data: {
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {
              'role': 'system',
              'content': 'Tu es SenAlert AI, l\'assistant virtuel d\'urgence officiel de la plateforme de secours de la République du Sénégal. Réponds avec concision, clarté et professionnalisme. Propose toujours les consignes vitales et les numéros d\'urgence (SAMU 15, Pompiers 18, Police 17) si nécessaire.',
            },
            {
              'role': 'user',
              'content': userMessage.text,
            }
          ],
          'max_tokens': 500,
          'temperature': 0.7,
        },
      );

      if (res.statusCode == 200 && res.data != null) {
        final content = res.data['choices']?[0]?['message']?['content'];
        if (content != null && content.toString().trim().isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _isTyping = false;
            _messages.add(_ChatMessage(
              text: content.toString().trim(),
              isUser: false,
              timestamp: DateTime.now(),
            ));
          });
          _scrollToBottom();
          return;
        }
      }
    } catch (e) {
      debugPrint('Direct Groq API call fallback: $e');
    }

    if (!mounted) return;
    final responseText = _generateAiResponse(userMessage.text);
    setState(() {
      _isTyping = false;
      _messages.add(_ChatMessage(
        text: responseText,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  String _generateAiResponse(String query) {
    final q = query.toLowerCase();

    if (q.contains('cardiaque') || q.contains('rcp') || q.contains('coeur')) {
      return "🚑 **PROTOCOLE URGENCE ARRÊT CARDIAQUE (SAMU 15)** :\n\n"
          "1. Vérifiez la sécurité et la conscience de la victime.\n"
          "2. **Appelez immédiatement le SAMU au 15 ou les Pompiers au 18**.\n"
          "3. Placez la victime sur le dos sur une surface dure.\n"
          "4. Alternez **30 compressions thoraciques** (100 à 120/min) au centre de la poitrine et **2 insufflations**.\n"
          "5. Ne vous arrêtez pas jusqu'à l'arrivée des secours.";
    }

    if (q.contains('incendie') || q.contains('feu') || q.contains('fumee')) {
      return "🔥 **CONSIGNES URGENCE INCENDIE (POMPIERS 18)** :\n\n"
          "1. **Évacuez immédiatement** en alerteurs les occupants.\n"
          "2. Rampez au sol sous la fumée (l'air pur reste près du sol).\n"
          "3. Fermez les portes pour contenir les flammes et n'utilisez pas d'ascenseur.\n"
          "4. **Appelez les Sapeurs-Pompiers au 18** dès que vous êtes en sécurité dehors.";
    }

    if (q.contains('inondation') || q.contains('eau') || q.contains('pluie')) {
      return "🌊 **CONSIGNES INONDATION / PLUIES DILUVIENNES** :\n\n"
          "1. Coupez immédiatement l'électricité et le gaz.\n"
          "2. Montez dans les étages avec vos téléphones et papiers officiels.\n"
          "3. **Ne tentez pas de franchir une zone inondée** à pied ou en véhicule.\n"
          "4. Suivez les bulletins météo officiels sur SenAlert.";
    }

    if (q.contains('serpent') || q.contains('morsure') || q.contains('scorpion')) {
      return "🐍 **URGENCE MORSURE DE SERPENT / SCORPION** :\n\n"
          "1. Allongez la victime et gardez-la **calme et immobile** (réduit la diffusion du venin).\n"
          "2. Immobilisez le membre touché sous le niveau du cœur.\n"
          "3. **NE PAS inciser, NE PAS sucer la plaie, NE PAS poser de garrot serré**.\n"
          "4. Transportez d'urgence vers le centre de santé le plus proche ou appelez le SAMU (15).";
    }

    if (q.contains('electric') || q.contains('jus') || q.contains('courant')) {
      return "⚡ **URGENCE ÉLECTROCUTION** :\n\n"
          "1. **NE TOUCHEZ PAS la victime** tant que le courant est actif !\n"
          "2. Coupez le disjoncteur général immédiatement.\n"
          "3. Si impossible, éloignez la source électrique avec un objet isolant sec (bois, plastique).\n"
          "4. Appelez les Sapeurs-Pompiers (18) et commencez la RCP si inanimé.";
    }

    if (q.contains('saignement') || q.contains('sang') || q.contains('hemorragie')) {
      return "🩸 **PROTOCOLE HÉMORRAGIE ABONDANTE** :\n\n"
          "1. Exercez une **pression directe forte** sur la plaie avec un tissu propre.\n"
          "2. Allongez la victime pour prévenir l'état de choc.\n"
          "3. Maintenez la compression en continu jusqu'à l'arrivée du SAMU (15).\n"
          "4. Ne posez un garrot au-dessus de la plaie qu'en cas d'urgence vitale incontrôlable.";
    }

    return "🤖 **CONSEIL ASSISTANT IA SENALERT** :\n\n"
        "Pour cette situation ($query), appliquez les règles de sécurité universelles :\n"
        "1. Protégez la zone et évitez le suraccident.\n"
        "2. Évaluez l'état de la victime (respiration, conscience).\n"
        "3. **Contactez immédiatement les secours au Sénégal : SAMU (15) ou Pompiers (18)**.\n"
        "4. Déclenchez l'Alerte SOS sur l'application SenAlert pour transmettre votre géolocalisation GPS directe.";
  }

  void _scrollToBottom() {
    Future.microtask(() {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.darkSlate,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => context.go('/home'),
        ),
        title: const Row(
          children: [
            Icon(Icons.smart_toy_rounded, color: AppColors.emerald, size: 22),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assistant IA Secours & Urgences',
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'Protocoles Officiels SAMU 15 & Pompiers 18',
                  style: TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Prompt suggestion chips bar
          Container(
            height: 52,
            color: AppColors.navy,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _promptChips.length,
              itemBuilder: (context, index) {
                final chip = _promptChips[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    backgroundColor: AppColors.darkSlate,
                    side: const BorderSide(color: AppColors.border),
                    label: Text(
                      chip['label']!,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => _sendMessage(chip['query']!),
                  ),
                );
              },
            ),
          ),

          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.emerald,
                          child: Icon(Icons.smart_toy, color: AppColors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.crimson,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Assistant IA en train de répondre...',
                                style: TextStyle(
                                  color: AppColors.textGrey,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final msg = _messages[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    mainAxisAlignment:
                        msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!msg.isUser) ...[
                        const CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.emerald,
                          child: Icon(Icons.smart_toy, color: AppColors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: msg.isUser ? AppColors.crimson : AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: Border.all(
                              color: msg.isUser ? AppColors.crimson : AppColors.border,
                            ),
                          ),
                          child: Text(
                            msg.text,
                            style: TextStyle(
                              color: msg.isUser ? AppColors.white : AppColors.textDark,
                              fontSize: 13.5,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ),
                      if (msg.isUser) ...[
                        const SizedBox(width: 10),
                        const CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.darkSlate,
                          child: Icon(Icons.person, color: AppColors.white, size: 18),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),

          // Message input bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white,
              border: const Border(top: BorderSide(color: AppColors.border)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Posez votre question d\'urgence...',
                      hintStyle: const TextStyle(color: AppColors.textGrey, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(style: BorderStyle.none),
                      ),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  backgroundColor: AppColors.crimson,
                  elevation: 0,
                  onPressed: () => _sendMessage(_controller.text),
                  child: const Icon(Icons.send_rounded, color: AppColors.white, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
