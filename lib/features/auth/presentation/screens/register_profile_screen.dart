import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constant/app_icons.dart';
import '../../../../core/routes/app_path.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/helpers/validators.dart';
import '../../../../shared/ui/atoms/atoms.dart';
import '../../domain/entities/patient_registration.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/registration/registration_bloc.dart';
import '../widgets/auth_form_shell.dart';
import '../widgets/registration_flow_listeners.dart';

/// Step 3 of 3 — the rest of the patient record, and the call that creates it.
///
/// The fields are exactly `PatientDTO`'s, in the order a person can answer
/// them. Two of them are worth explaining:
///
/// * **First and last name are separate inputs.** The DTO has two fields, and
///   splitting one "nombre completo" on whitespace guesses wrong the moment
///   someone has two surnames — which in Ecuador is everybody.
/// * **The birthday is required**, because the server marks it `@NotNull`.
///   That is not bureaucracy: dosing, reference ranges and screening intervals
///   all depend on age, so a patient record without it is clinically useless.
///
/// Everything below the divider is optional on the server and is presented as
/// optional here, rather than being demanded on a form the patient is trying
/// to finish inside a five-minute window.
class RegisterProfileScreen extends StatefulWidget {
  const RegisterProfileScreen({super.key});

  @override
  State<RegisterProfileScreen> createState() => _RegisterProfileScreenState();
}

class _RegisterProfileScreenState extends State<RegisterProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _emergencyName = TextEditingController();
  final TextEditingController _emergencyPhone = TextEditingController();

  DateTime? _birthday;
  Gender? _gender;

  // Both fields live OUTSIDE the `Form` — one is a date picker, the other a
  // chip row — so `Form.validate()` cannot see them and the screen has to
  // check them itself. These two flags are that check's output.
  bool _birthdayMissing = false;
  bool _genderMissing = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _password.dispose();
    _confirm.dispose();
    _phone.dispose();
    _address.dispose();
    _emergencyName.dispose();
    _emergencyPhone.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      // Opens on a plausible adult rather than on today — nobody registering
      // for a clinic was born this morning, and starting at today means
      // scrolling back thirty years.
      initialDate: _birthday ?? DateTime(now.year - 30, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Listo',
      // A calendar is the wrong default for a birthday — it takes many taps to
      // reach 1978. Typing is faster, and the calendar is still one tap away.
      initialEntryMode: DatePickerEntryMode.input,
    );

    if (picked == null) return;
    setState(() {
      _birthday = picked;
      _birthdayMissing = false;
    });
  }

  void _submit() {
    final bool formOk = _formKey.currentState?.validate() ?? false;

    // Every check runs before the early return, so a patient missing both the
    // date and the sex sees both errors at once instead of discovering the
    // second one only after fixing the first.
    setState(() {
      _birthdayMissing = _birthday == null;
      _genderMissing = _gender == null;
    });

    if (!formOk || _birthday == null || _gender == null) return;

    context.read<RegistrationBloc>().add(
      RegistrationProfileSubmitted(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        birthday: _birthday!,
        password: _password.text,
        gender: _gender,
        phone: _text(_phone),
        address: _text(_address),
        emergencyContactName: _text(_emergencyName),
        emergencyContactPhone: _text(_emergencyPhone),
      ),
    );
  }

  /// Guards both ways out of step 3: the header's back arrow and the device's
  /// own back gesture.
  ///
  /// Leaving is not a normal `pop` here. The flash token, the email and the
  /// cedula all live in [RegistrationBloc], and step 3 is the only step whose
  /// work — a whole profile form — is lost by going back. So it asks first,
  /// and on confirmation it RESTARTS the flow rather than popping one screen:
  /// the OTP screen underneath is tied to a token that will not be reused, so
  /// returning to it would show a step that cannot be completed.
  Future<void> _confirmLeave() async {
    final bool leave =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text('Salir del registro?', style: AppTypography.h3),
            content: Text(
              'Vas a perder los datos que ya escribiste y tendras que '
              'empezar de nuevo desde tu correo y cedula.',
              style: AppTypography.body,
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(
                  'Seguir aqui',
                  style: AppTypography.cap.copyWith(
                    color: AppColors.ink2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  'Salir y empezar de nuevo',
                  style: AppTypography.cap.copyWith(
                    color: AppColors.emergency,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!leave || !mounted) return;

    // Reset BEFORE navigating. Step 1's listener only pushes forward when the
    // step is `verification`, so clearing to `identity` first guarantees the
    // flow cannot bounce straight back out to where we came from.
    //
    // The `go` below is deliberately redundant: resetting to `identity` also
    // trips this screen's own listener, which navigates to the same place. Two
    // `go` calls to one location are idempotent, and keeping the explicit one
    // means back-navigation does not silently break the day that listener
    // branch is refactored.
    context.read<RegistrationBloc>().add(const RegistrationRestarted());
    context.go(AppPath.registerScreen);
  }

  String? _text(TextEditingController controller) {
    final String value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    return RegistrationFlowListeners(
      onStepChanged: (BuildContext context, RegistrationState state) {
        // Registered and signed in. Hand the session up; the router navigates.
        final session = state.session;
        if (state.step == RegistrationStep.done && session != null) {
          context.read<AuthBloc>().add(AuthSessionGranted(session));
          return;
        }

        // The five-minute token expired. The bloc already walked the flow back
        // to step 1; this unwinds the navigation to match. Straight to the
        // first step rather than popping twice: the OTP screen underneath is
        // also stale.
        if (state.step == RegistrationStep.identity) {
          context.go(AppPath.registerScreen);
        }
      },
      child: BlocBuilder<RegistrationBloc, RegistrationState>(
        builder: (context, state) {
        // `done` is included on purpose, and it is the fix for the blank form.
        //
        // On success this screen hands the session to [AuthBloc], AuthBloc
        // refreshes the router, and the router rebuilds this subtree before the
        // redirect swaps the screen out. A rebuilt State means fresh, empty
        // `TextEditingController`s, so the patient watched their finished form
        // wipe itself and sat in front of a blank one until navigation caught
        // up. Covering `submitting` AND `done` means the form is off screen for
        // that whole window and the wipe is never visible.
        final bool busy =
            state.isSubmitting || state.step == RegistrationStep.done;

        if (busy) {
          // `canPop: false` with no handler: mid-request there is nothing to
          // confirm and nothing to go back to — leaving now would abandon a
          // patient record the server may already have created.
          return const PopScope(canPop: false, child: _CreatingAccount());
        }

        final Widget form = AuthFormShell(
          kicker: 'Paso 3 de 3',
          title: 'Cuéntanos quién eres.',
          subtitle: 'Con esto queda lista tu historia clínica.',
          onBack: _confirmLeave,
          children: <Widget>[
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.section,
                children: <Widget>[
                  AppTextField(
                    label: 'Nombres',
                    controller: _firstName,
                    hint: 'Cómo aparece en tu cédula',
                    prefixIcon: AppIcons.person,
                    keyboardType: TextInputType.name,
                    textInputAction: TextInputAction.next,
                    enabled: !state.isSubmitting,
                    autofillHints: const <String>[AutofillHints.givenName],
                    validator: Validators.fullName,
                  ),
                  AppTextField(
                    label: 'Apellidos',
                    controller: _lastName,
                    hint: 'Ambos apellidos',
                    prefixIcon: AppIcons.person,
                    keyboardType: TextInputType.name,
                    textInputAction: TextInputAction.next,
                    enabled: !state.isSubmitting,
                    autofillHints: const <String>[AutofillHints.familyName],
                    validator: Validators.fullName,
                  ),

                  _BirthdayField(
                    value: _birthday,
                    showError: _birthdayMissing,
                    enabled: !state.isSubmitting,
                    onTap: _pickBirthday,
                  ),

                  _GenderField(
                    value: _gender,
                    showError: _genderMissing,
                    enabled: !state.isSubmitting,
                    onChanged: (value) => setState(() {
                      _gender = value;
                      _genderMissing = false;
                    }),
                  ),

                  AppTextField(
                    label: 'Contraseña',
                    controller: _password,
                    hint: 'Minimo 8 caracteres',
                    prefixIcon: AppIcons.password,
                    obscure: true,
                    textInputAction: TextInputAction.next,
                    enabled: !state.isSubmitting,
                    autofillHints: const <String>[AutofillHints.newPassword],
                    validator: Validators.password,
                  ),
                  AppTextField(
                    label: 'Repite la contraseña',
                    controller: _confirm,
                    hint: 'La misma de arriba',
                    prefixIcon: AppIcons.password,
                    obscure: true,
                    textInputAction: TextInputAction.next,
                    enabled: !state.isSubmitting,
                    validator: (v) =>
                        Validators.confirmPassword(v, _password.text),
                  ),

                  const AppHairline(),
                  const AppKicker(text: 'Opcional', size: 11),

                  AppTextField(
                    label: 'Celular',
                    controller: _phone,
                    hint: '09XXXXXXXX',
                    prefixIcon: AppIcons.phone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    enabled: !state.isSubmitting,
                    maxLength: 10,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    // Optional, so an empty value passes. Only a value that IS
                    // there gets checked — validating an untouched optional
                    // field is how a form blocks on something nobody asked for.
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? null
                        : Validators.phone(value),
                  ),
                  AppTextField(
                    label: 'Dirección',
                    controller: _address,
                    hint: 'Calle y numero',
                    prefixIcon: AppIcons.location,
                    textInputAction: TextInputAction.next,
                    enabled: !state.isSubmitting,
                  ),
                  AppTextField(
                    label: 'Contacto de emergencia',
                    controller: _emergencyName,
                    hint: 'Nombre completo',
                    prefixIcon: AppIcons.person,
                    textInputAction: TextInputAction.next,
                    enabled: !state.isSubmitting,
                  ),
                  AppTextField(
                    label: 'Telefono de emergencia',
                    controller: _emergencyPhone,
                    hint: '09XXXXXXXX',
                    prefixIcon: AppIcons.phone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    enabled: !state.isSubmitting,
                    maxLength: 10,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? null
                        : Validators.phone(value),
                    onSubmitted: (_) => _submit(),
                  ),
                ],
              ),
            ),

            AppButton(
              label: 'Crear mi cuenta',
              size: AppButtonSize.lg,
              fullWidth: true,
              isLoading: state.isSubmitting,
              onPressed: _submit,
            ),
          ],
        );

        // The device's own back gesture gets the SAME confirmation as the
        // header arrow. Guarding only the arrow is the usual mistake: on
        // Android the system gesture is how most people go back, so it is the
        // path that would silently discard the form.
        return PopScope(
            canPop: false,
            onPopInvokedWithResult: (bool didPop, Object? result) {
              if (didPop) return;
              _confirmLeave();
            },
            child: form,
          );
        },
      ),
    );
  }
}

/// What step 3 shows while the account is being created.
///
/// A full screen rather than a spinner inside the button, because the button
/// is not the thing that needs covering: the form behind it blanks out when
/// the router rebuilds this subtree on success. See the `busy` note in
/// [RegisterProfileScreen].
class _CreatingAccount extends StatelessWidget {
  const _CreatingAccount();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.field,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.xxl,
          children: <Widget>[
            const AppBrandMark(size: 44),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.blue,
              ),
            ),
            Text(
              'Creando tu cuenta...',
              style: AppTypography.body.copyWith(
                color: AppColors.ink2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A read-only field that opens the date picker.
///
/// Not an [AppTextField] with a suffix icon: a free-text date invites
/// `12/03/78` and then has to guess whether that is March or December. The
/// picker returns a `DateTime` and there is nothing to parse.
class _BirthdayField extends StatelessWidget {
  const _BirthdayField({
    required this.value,
    required this.showError,
    required this.enabled,
    required this.onTap,
  });

  final DateTime? value;
  final bool showError;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // `es` explicitly, not the device locale: the app is Spanish, and a phone
    // set to English should not render a Spanish form's dates as "Mar 12".
    final String label = value == null
        ? 'Selecciona tu fecha'
        : DateFormat('d MMMM y', 'es').format(value!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.md,
      children: <Widget>[
        const AppKicker(text: 'Fecha de nacimiento', size: 11),
        Semantics(
          button: true,
          label: 'Fecha de nacimiento, $label',
          child: GestureDetector(
            onTap: enabled ? onTap : null,
            child: Container(
              constraints: const BoxConstraints(minHeight: 54),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadii.tileLgAll,
                border: Border.all(
                  color: showError ? AppColors.emergency : AppColors.line,
                  width: 1.5,
                ),
              ),
              child: Row(
                spacing: AppSpacing.lg,
                children: <Widget>[
                  const Icon(
                    AppIcons.appointments,
                    size: 20,
                    color: AppColors.ink3,
                  ),
                  Expanded(
                    child: Text(
                      label,
                      style: AppTypography.body.copyWith(
                        color: value == null ? AppColors.ink3 : AppColors.ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Icon(
                    AppIcons.chevronRight,
                    size: 16,
                    color: AppColors.ink3,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showError)
          Text(
            'La fecha de nacimiento es obligatoria',
            style: AppTypography.cap.copyWith(
              color: AppColors.emergency,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

/// Required, and offering only [Gender.selectable] — two options, not three.
///
/// Two consequences of being required, both deliberate:
///
/// * **Tapping the selected chip no longer clears it.** Un-selecting was the
///   way to un-answer an optional question; on a required field it is just a
///   way to make the form invalid by accident.
/// * **It carries its own error line**, like `_BirthdayField`, because it is
///   not a [TextFormField] and so `Form.validate()` never sees it. A required
///   field outside the `Form` needs the screen to check it by hand — which is
///   what `_submit` does.
class _GenderField extends StatelessWidget {
  const _GenderField({
    required this.value,
    required this.showError,
    required this.enabled,
    required this.onChanged,
  });

  final Gender? value;
  final bool showError;
  final bool enabled;
  final ValueChanged<Gender> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.md,
      children: <Widget>[
        const AppKicker(text: 'Sexo', size: 11),
        Row(
          spacing: AppSpacing.sm,
          children: <Widget>[
            for (final Gender gender in Gender.selectable)
              Expanded(
                child: AppChip(
                  label: gender.label,
                  selected: value == gender,
                  expand: true,
                  onTap: enabled ? () => onChanged(gender) : null,
                ),
              ),
          ],
        ),
        if (showError)
          Text(
            'Selecciona tu sexo',
            style: AppTypography.cap.copyWith(
              color: AppColors.emergency,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}
