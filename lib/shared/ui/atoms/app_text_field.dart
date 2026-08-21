import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constant/app_icons.dart';
import '../../../core/theme/theme.dart';
import 'app_kicker.dart';

/// The design system's text input.
///
/// The label sits ABOVE the field as a kicker, and that is a design decision
/// taken from the boards rather than a Material default worked around: the
/// booking widget labels every input group with a small uppercase kicker
/// above it (`1 / Medico`, `2 / Dia`, `3 / Hora`). A floating Material label
/// would introduce a second, contradictory labelling language into the same
/// form.
///
/// See `core/theme/components/app_input_theme.dart` for where the field's
/// shape, height and focus treatment come from — the boards contain no form
/// controls at all, so those values are derived and the derivation is
/// written down.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onSubmitted,
    this.onChanged,
    this.prefixIcon,
    this.autofillHints,
    this.inputFormatters,
    this.enabled = true,
    this.maxLength,
    this.autofocus = false,
    this.focusNode,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;

  /// Passwords. Renders the eye toggle in the suffix and starts hidden — the
  /// toggle is not optional, because a hidden field with no way to check it
  /// is how people mistype a password three times and give up.
  final bool obscure;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final IconData? prefixIcon;
  final List<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final int? maxLength;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.md,
      children: <Widget>[
        // The board's group label: kicker at 11px, muted.
        AppKicker(text: widget.label, size: 11),
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          obscureText: _hidden,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          validator: widget.validator,
          onFieldSubmitted: widget.onSubmitted,
          onChanged: widget.onChanged,
          autofillHints: widget.autofillHints,
          inputFormatters: widget.inputFormatters,
          maxLength: widget.maxLength,
          cursorColor: AppColors.blue,
          style: AppTypography.body.copyWith(
            color: AppColors.ink,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            helperText: widget.helper,
            counterText: '',
            prefixIcon: widget.prefixIcon == null
                ? null
                : Icon(widget.prefixIcon, size: 20),
            suffixIcon: widget.obscure
                ? IconButton(
                    onPressed: () => setState(() => _hidden = !_hidden),
                    icon: Icon(
                      _hidden ? AppIcons.reveal : AppIcons.conceal,
                      size: 20,
                    ),
                    tooltip: _hidden
                        ? 'Mostrar contrasena'
                        : 'Ocultar contrasena',
                    color: AppColors.ink3,
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
