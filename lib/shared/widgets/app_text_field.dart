import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Labeled text field with an inline error message slot — the shared shape
/// every form in the app uses so 422 field errors from the backend render
/// consistently (section 63).
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.errorText,
    this.hintText,
    this.keyboardType,
    this.inputFormatters,
    this.autofocus = false,
    this.enabled = true,
    this.textAlign = TextAlign.start,
    this.style,
    this.onChanged,
    this.onSubmitted,
    this.prefixText,
    this.maxLength,
    this.semanticsLabel,
  });

  final String label;
  final TextEditingController? controller;
  final String? errorText;
  final String? hintText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;
  final bool enabled;
  final TextAlign textAlign;
  final TextStyle? style;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? prefixText;
  final int? maxLength;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      autofocus: autofocus,
      enabled: enabled,
      textAlign: textAlign,
      style: style,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        errorText: errorText,
        prefixText: prefixText,
        counterText: '',
        semanticCounterText: semanticsLabel,
      ),
    );
  }
}
