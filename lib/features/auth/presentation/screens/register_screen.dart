import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constant/app_icons.dart';
import '../../../../core/routes/app_path.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/helpers/validators.dart';
import '../../../../shared/ui/atoms/atoms.dart';
import '../blocs/registration/registration_bloc.dart';
import '../widgets/auth_form_shell.dart';

/// Step 1 of 3 — the email and cedula the account will be filed under.
///
/// ## Why this screen asks for two fields and not eight
///
/// The backend's registration is a two-call flow, and the order is not
/// negotiable. `POST /auth/init-registration-patient` takes ONLY
/// `{email, ci}`, checks that neither is already registered, mails a code and
/// issues the 5-minute token that the second call authenticates with. Only
/// then does `POST /auth/register-patient` accept the full `PatientDTO`.
///
/// A single-page sign-up form cannot work against that: without the flash
/// token from step 1, `register-patient` has no `Authentication` and fails.
/// So this screen collects the identity, the next collects the code, and the
/// third collects everything else.
///
/// The upside is real, not just compliance: a patient learns that their cedula
/// is already registered after typing two fields, not eight.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _cedula = TextEditingController();

  bool _accepted = false;
  bool _showConsentError = false;

  @override
  void dispose() {
    _email.dispose();
    _cedula.dispose();
    super.dispose();
  }

  void _submit() {
    final bool formOk = _formKey.currentState?.validate() ?? false;
    setState(() => _showConsentError = !_accepted);
    if (!formOk || !_accepted) return;

    context.read<RegistrationBloc>().add(
      RegistrationIdentitySubmitted(
        email: _email.text.trim(),
        cedula: _cedula.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RegistrationBloc, RegistrationState>(
      listenWhen: (previous, current) =>
          previous.step != current.step || previous.status != current.status,
      listener: (context, state) {
        if (state.step == RegistrationStep.verification) {
          context.push(AppPath.registerVerificationScreen);
          return;
        }
        final failure = state.failure;
        if (state.status == RegistrationStatus.failure && failure != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(failure.message)));
          context.read<RegistrationBloc>().add(
            const RegistrationFailureDismissed(),
          );
        }
      },
      builder: (context, state) {
        return AuthFormShell(
          kicker: 'Paso 1 de 3',
          title: 'Empecemos por lo basico.',
          subtitle:
              'Con tu correo y tu cedula te enviamos un codigo para '
              'confirmar que eres tu.',
          onBack: () => context.pop(),
          footer: AuthFooterLink(
            message: 'Ya tienes cuenta?',
            actionLabel: 'Ingresa',
            onTap: () => context.pop(),
          ),
          children: <Widget>[
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.section,
                children: <Widget>[
                  AppTextField(
                    label: 'Correo',
                    controller: _email,
                    hint: 'tu@correo.com',
                    prefixIcon: AppIcons.email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    enabled: !state.isSubmitting,
                    autofillHints: const <String>[AutofillHints.email],
                    validator: Validators.email,
                  ),
                  AppTextField(
                    label: 'Cedula',
                    controller: _cedula,
                    hint: '10 digitos',
                    helper: 'Tu historia clinica se archiva con este numero.',
                    prefixIcon: AppIcons.identityCard,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    enabled: !state.isSubmitting,
                    maxLength: 10,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: Validators.cedula,
                    onSubmitted: (_) => _submit(),
                  ),
                ],
              ),
            ),

            _ConsentRow(
              value: _accepted,
              showError: _showConsentError && !_accepted,
              onChanged: (value) => setState(() {
                _accepted = value;
                if (value) _showConsentError = false;
              }),
              onOpenTerms: () => context.push(AppPath.termsScreen),
              onOpenPrivacy: () => context.push(AppPath.privacyScreen),
            ),

            AppButton(
              label: 'Enviar codigo',
              size: AppButtonSize.lg,
              fullWidth: true,
              isLoading: state.isSubmitting,
              trailing: const Icon(AppIcons.arrowRight),
              onPressed: _submit,
            ),
          ],
        );
      },
    );
  }
}

/// Consent, with both documents reachable from the sentence itself.
///
/// Stateful for one reason — a [TapGestureRecognizer] on a [TextSpan] is owned
/// by whoever creates it and MUST be disposed. Building them inline in a
/// `build` that reruns on every keystroke leaks one pair per rebuild, which
/// Flutter's leak tracker flags in tests and nobody notices in production
/// until the profiler is open.
class _ConsentRow extends StatefulWidget {
  const _ConsentRow({
    required this.value,
    required this.showError,
    required this.onChanged,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  final bool value;
  final bool showError;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  @override
  State<_ConsentRow> createState() => _ConsentRowState();
}

class _ConsentRowState extends State<_ConsentRow> {
  late final TapGestureRecognizer _termsTap = TapGestureRecognizer()
    ..onTap = () => widget.onOpenTerms();
  late final TapGestureRecognizer _privacyTap = TapGestureRecognizer()
    ..onTap = () => widget.onOpenPrivacy();

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle linkStyle = AppTypography.cap.copyWith(
      color: AppColors.blueText,
      fontWeight: FontWeight.w700,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.md,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.md,
          children: <Widget>[
            SizedBox.square(
              dimension: 24,
              child: Checkbox(
                value: widget.value,
                onChanged: (v) => widget.onChanged(v ?? false),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    const TextSpan(text: 'Acepto los '),
                    TextSpan(
                      text: 'terminos y condiciones',
                      style: linkStyle,
                      recognizer: _termsTap,
                    ),
                    const TextSpan(text: ' y la '),
                    TextSpan(
                      text: 'politica de privacidad',
                      style: linkStyle,
                      recognizer: _privacyTap,
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
                style: AppTypography.cap.copyWith(color: AppColors.ink2),
              ),
            ),
          ],
        ),
        if (widget.showError)
          Text(
            'Tienes que aceptar los terminos para continuar',
            style: AppTypography.cap.copyWith(
              color: AppColors.emergency,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}
