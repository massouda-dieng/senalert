import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:senalert_mobile/core/constants/app_colors.dart';

/// Bouton principal SenAlert (dégradé bleu nuit par défaut, 54 px de haut).
/// API inchangée : text, onPressed, isLoading, color, outlined.
class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final Color? color;
  final bool outlined;
  final IconData? icon;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.color,
    this.outlined = false,
    this.icon,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      widget.text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15.5,
        fontWeight: FontWeight.w700,
        color: widget.outlined ? (widget.color ?? AppColors.navy800) : AppColors.white,
        letterSpacing: 0.2,
      ),
    );

    if (widget.outlined) {
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: OutlinedButton(
          onPressed: widget.isLoading ? null : widget.onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: widget.color ?? AppColors.border, width: 1.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          child: label,
        ),
      );
    }

    final gradient = widget.color != null
        ? LinearGradient(colors: [widget.color!, Color.lerp(widget.color!, Colors.black, 0.18)!])
        : AppColors.actionGradient;
    final glow = widget.color ?? AppColors.blue600;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: glow.withOpacity(0.32), blurRadius: 18, offset: const Offset(0, 8)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: widget.isLoading ? null : widget.onPressed,
              child: Center(
                child: widget.isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2.5),
                      )
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                        ],
                        label,
                      ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
