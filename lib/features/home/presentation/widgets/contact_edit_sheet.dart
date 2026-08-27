import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/theme.dart';
import '../../../../shared/helpers/validators.dart';
import '../../../../shared/ui/atoms/atoms.dart';
import '../../domain/entities/patient_profile.dart';
import '../blocs/profile/profile_bloc.dart';

/// The form behind "Editar datos de contacto".
///
/// ## Only the five fields the server honours
///
/// `PatientService.updatePatient` copies email, phone, address and the two
/// emergency-contact fields, and ignores everything else. This sheet shows
/// exactly those five — so a patient cannot type a new cedula, get a success
/// message, and discover next visit that nothing changed.
///
/// ## A bottom sheet, not a route
///
/// The patient is editing four lines while looking at the values they are
/// replacing. A pushed screen hides that context; a sheet keeps it a
/// thumb-scroll away. `isScrollControlled` plus the view-insets padding is what
/// keeps the last field above the keyboard instead of under it.
///
/// ## It closes on the bloc's confirmation, not on the tap
///
/// The listener waits for [ProfileStatus.saved]. Popping on tap would show a
/// success snackbar over a request that could still fail, and the patient would
/// walk away believing a number was updated when it was not.
class ContactEditSheet extends StatefulWidget {
  const ContactEditSheet._({required this.profile});

  final PatientProfile profile;

  static Future<void> show(BuildContext context, PatientProfile profile) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      // The bloc lives above this sheet, but a modal route gets its own
      // element tree — so the provider has to be handed across explicitly.
      builder: (_) => BlocProvider<ProfileBloc>.value(
        value: context.read<ProfileBloc>(),
        child: ContactEditSheet._(profile: profile),
      ),
    );
  }

  @override
  State<ContactEditSheet> createState() => _ContactEditSheetState();
}

class _ContactEditSheetState extends State<ContactEditSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _email = TextEditingController(
    text: widget.profile.email,
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.profile.phone ?? '',
  );
  late final TextEditingController _address = TextEditingController(
    text: widget.profile.address ?? '',
  );
  late final TextEditingController _contactName = TextEditingController(
    text: widget.profile.emergencyContactName ?? '',
  );
  late final TextEditingController _contactPhone = TextEditingController(
    text: widget.profile.emergencyContactPhone ?? '',
  );

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _contactName.dispose();
    _contactPhone.dispose();
    super.dispose();
  }

  /// An empty optional field is sent as null, not as `''`.
  ///
  /// The server stores what it receives, so a blank string would replace "no
  /// phone on file" with "the phone is the empty string" — a value that then
  /// renders as a blank row instead of "Sin registrar".
  String? _optional(TextEditingController controller) {
    final String value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;

    context.read<ProfileBloc>().add(
      ProfileContactSubmitted(
        PatientContactUpdate(
          email: _email.text.trim(),
          phone: _optional(_phone),
          address: _optional(_address),
          emergencyContactName: _optional(_contactName),
          emergencyContactPhone: _optional(_contactPhone),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileBloc, ProfileState>(
      listenWhen: (ProfileState previous, ProfileState current) =>
          previous.status != current.status &&
          current.status == ProfileStatus.saved,
      listener: (BuildContext context, ProfileState state) {
        Navigator.of(context).pop();
      },
      builder: (BuildContext context, ProfileState state) {
        final bool saving = state.status == ProfileStatus.saving;

        return Padding(
          // The keyboard's height. Without this the last field sits under it
          // and the patient types blind.
          padding: EdgeInsets.only(
            left: AppSpacing.pad,
            right: AppSpacing.pad,
            top: AppSpacing.xl,
            bottom: AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.lg,
                children: <Widget>[
                  Text('Datos de contacto', style: AppTypography.h3),
                  Text(
                    'Tu nombre, cedula y fecha de nacimiento no se editan '
                    'desde aca.',
                    style: AppTypography.cap,
                  ),

                  const SizedBox(height: AppSpacing.xs),

                  // A write that failed is reported HERE, inside the still-open
                  // sheet. On the screen behind it the patient would not see it
                  // — the sheet covers that area.
                  if (state.status == ProfileStatus.failure &&
                      state.failure != null)
                    Text(
                      state.failure!.message,
                      style: AppTypography.cap.copyWith(
                        color: AppColors.emergency,
                      ),
                    ),

                  AppTextField(
                    label: 'Correo',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !saving,
                    validator: Validators.email,
                  ),
                  AppTextField(
                    label: 'Celular',
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    enabled: !saving,
                  ),
                  AppTextField(
                    label: 'Dirección',
                    controller: _address,
                    enabled: !saving,
                  ),
                  AppTextField(
                    label: 'Contacto de emergencia',
                    controller: _contactName,
                    enabled: !saving,
                  ),
                  AppTextField(
                    label: 'Telefono de emergencia',
                    controller: _contactPhone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    enabled: !saving,
                    onSubmitted: (_) => _submit(),
                  ),

                  const SizedBox(height: AppSpacing.xs),

                  AppButton(
                    label: saving ? 'Guardando...' : 'Guardar cambios',
                    size: AppButtonSize.lg,
                    fullWidth: true,
                    onPressed: saving ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
