import 'package:flutter/material.dart';

import 'credits_photos.dart';

/// Photo d'illustration embarquée, avec mention de licence (CC BY / CC BY-SA).
class PhotoIllustration extends StatelessWidget {
  final String nom;
  final bool credit;
  final Widget? superposition;
  const PhotoIllustration(this.nom, {super.key, this.credit = true, this.superposition});

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        Image.asset('assets/images/photos/$nom.jpg', fit: BoxFit.cover, excludeFromSemantics: true,
            errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF005527))),
        if (superposition != null) superposition!,
        if (credit && creditsPhotos[nom] != null)
          Positioned(
            right: 8, bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(4)),
              child: Text(creditsPhotos[nom]!, style: const TextStyle(color: Colors.white70, fontSize: 9)),
            ),
          ),
      ]);
}
