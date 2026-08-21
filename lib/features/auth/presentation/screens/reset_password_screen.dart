import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constant/app_icons.dart';
import '../../../../core/routes/app_path.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/helpers/validators.dart';
import '../../../../shared/ui/atoms/atoms.dart';
import '../../../../shared/ui/molecules/molecules.dart';
import '../widgets/auth_form_shell.dart';

/// Set a new password, after the code has been verified.
///
/// The rules are stated up front as a checklist that ticks itself as the user
/// types, rather than as an error that appears after they get it wrong. Same
/// information, opposite feeling — and it is the difference between a form
/// that helps and a form that scolds.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Drives the live checklist below.
    _password.addListener(_onTyped);
  }

  @override
  void dispose() {
    _password.removeListener(_onTyped);
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _onTyped() => setState(() {});

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _submitting = false);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Contrasena actualizada')));
    // Straight back to the start of the stack: the old session, if any, is
    // no longer valid.
    context.go(AppPath.loginScreen);
  }

  @override
  Widget build(BuildContext context) {
    final String value = _password.text;

    return AuthFormShell(
      kicker: 'Contrasena nueva',
      title: 'Elige una nueva.',
      subtitle: 'Cuando la guardes, cerramos las demas sesiones.',
      onBack: () => context.pop(),
      children: <Widget>[
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.section,
            children: <Widget>[
              AppTextField(
                label: 'Contrasena nueva',
                controller: _password,
                hint: 'Minimo 8 caracteres',
                prefixIcon: AppIcons.password,
                obscure: true,
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[AutofillHints.newPassword],
                validator: Validators.password,
              ),
              AppTextField(
                label: 'Repite la contrasena',
                controller: _confirm,
                hint: 'La misma de arriba',
                prefixIcon: AppIcons.password,
                obscure: true,
                textInputAction: TextInputAction.done,
                validator: (v) => Validators.confirmPassword(v, _password.text),
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),

        AppCard(
          padding: const EdgeInsets.all(AppSpacing.cardPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.md,
            children: <Widget>[
              const AppKicker(text: 'Debe tener', size: 11),
              _Rule(label: 'Al menos 8 caracteres', met: value.length >= 8),
              _Rule(
                label: 'Al menos una letra',
                met: RegExp(r'[A-Za-z]').hasMatch(value),
              ),
              _Rule(
                label: 'Al menos un numero',
                met: RegExp(r'\d').hasMatch(value),
              ),
            ],
          ),
        ),

        AppButton(
          label: 'Guardar contrasena',
          size: AppButtonSize.lg,
          fullWidth: true,
          isLoading: _submitting,
          onPressed: _submit,
        ),
      ],
    );
  }
}

/// One line of the live checklist. Met rules go `ok` green with a check; unmet
/// ones stay `ink-3` with a hollow marker — never red, because a rule the user
/// has not reached yet is not an error.
class _Rule extends StatelessWidget {
  const _Rule({required this.label, required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: AppSpacing.md,
      children: <Widget>[
        AnimatedContainer(
          duration: AppMotion.tone,
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: met ? AppColors.ok : Colors.transparent,
            border: met ? null : Border.all(color: AppColors.line, width: 1.5),
          ),
          child: met
              ? const Icon(AppIcons.success, size: 12, color: AppColors.surface)
              : null,
        ),
        Expanded(
          child: Text(
            label,
            style: AppTypography.cap.copyWith(
              color: met ? AppColors.ok : AppColors.ink3,
              fontWeight: met ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}
