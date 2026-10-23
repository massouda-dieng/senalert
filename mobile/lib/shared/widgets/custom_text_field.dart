import 'package:flutter/material.dart';
import 'package:senalert_mobile/core/constants/app_colors.dart';

class CustomTextField extends StatefulWidget {
  final String hint;
  final IconData prefixIcon;
  final bool isPassword;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final bool onDark;

  const CustomTextField({
    super.key,
    required this.hint,
    required this.prefixIcon,
    required this.controller,
    this.isPassword = false,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.onDark = false,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.onDark ? Colors.white70 : AppColors.textGrey;
    return TextFormField(
      controller: widget.controller,
      obscureText: widget.isPassword ? _obscure : false,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      style: TextStyle(
        fontSize: 15,
        color: widget.onDark ? Colors.white : AppColors.textDark,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: TextStyle(color: widget.onDark ? Colors.white54 : AppColors.textMuted, fontSize: 14),
        fillColor: widget.onDark ? Colors.white.withOpacity(0.08) : null,
        enabledBorder: widget.onDark
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.16)),
              )
            : null,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(widget.prefixIcon, color: iconColor, size: 20),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 48),
        suffixIcon: widget.isPassword
            ? IconButton(
                tooltip: _obscure ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
                icon: Icon(
                  _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: iconColor,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
      ),
    );
  }
}
