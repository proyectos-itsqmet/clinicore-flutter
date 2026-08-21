import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constant/app_icons.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/routes/app_path.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/helpers/validators.dart';
import '../../../../shared/ui/atoms/atoms.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/login/login_bloc.dart';
import '../widgets/auth_form_shell.dart';

/// Sign in.
///
/// The identity field takes either an email or a cedula, because a patient
/// remembers their cedula and may not remember which address they signed up
/// with. `LoginParams.fromIdentity` decides which one it is from the `@`.
///
/// ## What this screen does NOT do
///
/// It does not navigate on success. `LoginBloc` reports the session to
/// [AuthBloc], the router's `refreshListenable` notices, and the redirect moves
/// the app to the booking tab. That indirection is worth it: the same path
/// then covers biometric unlock, registration and a restored session, and
/// there is exactly one place that decides where a signed-in patient belongs.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LoginBloc>(
      create: (_) =>
          sl<LoginBloc>()..add(const LoginBiometricAvailabilityRequested()),
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _identity = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _identity.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Either an email or a cedula. The `@` decides, which is enough: no cedula
  /// contains one and no email address omits one.
  String? _validateIdentity(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return 'Ingresa tu correo o cedula';
    return v.contains('@') ? Validators.email(v) : Validators.cedula(v);
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<LoginBloc>().add(
      LoginSubmitted(identity: _identity.text, password: _password.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LoginBloc, LoginState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        final AuthSessionOutcome outcome = AuthSessionOutcome.of(state);
        switch (outcome) {
          case AuthSessionOutcome.granted:
            // Hand the session up. The router does the navigating.
            context.read<AuthBloc>().add(AuthSessionGranted(state.session!));
          case AuthSessionOutcome.rejected:
            _showFailure(context, state.failure!);
          case AuthSessionOutcome.pending:
            break;
        }
      },
      builder: (context, state) {
        return AuthFormShell(
          kicker: 'Turnos en linea',
          title: 'Entra a tu clinica.',
          subtitle: 'Tus citas, tu historia y tus recetas en un solo lugar.',
          footer: AuthFooterLink(
            message: 'No tienes cuenta?',
            actionLabel: 'Crea una',
            onTap: () => context.push(AppPath.registerScreen),
          ),
          children: <Widget>[
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.section,
                children: <Widget>[
                  AppTextField(
                    label: 'Correo o cedula',
                    controller: _identity,
                    hint: 'tu@correo.com',
                    prefixIcon: AppIcons.email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    enabled: !state.isSubmitting,
                    autofillHints: const <String>[AutofillHints.username],
                    validator: _validateIdentity,
                  ),
                  AppTextField(
                    label: 'Contrasena',
                    controller: _password,
                    hint: 'Tu contrasena',
                    prefixIcon: AppIcons.password,
                    obscure: true,
                    textInputAction: TextInputAction.done,
                    enabled: !state.isSubmitting,
                    autofillHints: const <String>[AutofillHints.password],
                    validator: Validators.password,
                    onSubmitted: (_) => _submit(),
                  ),
                ],
              ),
            ),

            // Right-aligned and above the CTA: an escape hatch, not a step.
            Align(
              alignment: Alignment.centerRight,
              child: _TextLink(
                label: 'Olvidaste tu contrasena?',
                onTap: state.isSubmitting
                    ? null
                    : () => context.push(AppPath.forgotPasswordScreen),
              ),
            ),

            AppButton(
              label: 'Ingresar',
              size: AppButtonSize.lg,
              fullWidth: true,
              isLoading: state.isSubmitting,
              trailing: const Icon(AppIcons.arrowRight),
              onPressed: _submit,
            ),

            // Only when the device can actually do it AND there is a stored
            // session to unlock. See `AuthRepository.canUnlockWithBiometrics`.
            if (state.biometricsAvailable)
              AppButton(
                label: 'Ingresar con huella',
                variant: AppButtonVariant.ghost,
                fullWidth: true,
                leading: const Icon(AppIcons.biometrics),
                onPressed: state.isSubmitting
                    ? null
                    : () => context.read<LoginBloc>().add(
                        const LoginBiometricRequested(),
                      ),
              ),
          ],
        );
      },
    );
  }

  void _showFailure(BuildContext context, Failure failure) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(failure.message)));
    context.read<LoginBloc>().add(const LoginFailureDismissed());
  }
}

/// What a [LoginState] transition means for navigation.
///
/// Extracting this keeps the listener a three-case switch instead of a nest of
/// null checks, and makes the invariant explicit: `granted` guarantees
/// `session != null`, `rejected` guarantees `failure != null`.
enum AuthSessionOutcome {
  granted,
  rejected,
  pending;

  static AuthSessionOutcome of(LoginState state) {
    if (state.status == LoginStatus.success && state.session != null) {
      return AuthSessionOutcome.granted;
    }
    if (state.status == LoginStatus.failure && state.failure != null) {
      return AuthSessionOutcome.rejected;
    }
    return AuthSessionOutcome.pending;
  }
}

/// A 13px-to-14px text action with a 44px touch target around it.
class _TextLink extends StatelessWidget {
  const _TextLink({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.touchMin),
          child: Center(
            child: Text(
              label,
              style: AppTypography.meta.copyWith(
                color: onTap == null ? AppColors.ink3 : AppColors.blueText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
