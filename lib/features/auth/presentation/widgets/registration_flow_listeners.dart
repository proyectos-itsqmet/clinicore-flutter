import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../blocs/registration/registration_bloc.dart';

/// Two listeners on [RegistrationBloc]. The twin of `RecoveryFlowListeners`,
/// and it exists for exactly the same bug.
///
/// ## The bug
///
/// All three registration screens share ONE bloc — it lives on the
/// `ShellRoute` — and all three stay MOUNTED, because each step is pushed on
/// top of the last. So every emission reaches all three listeners.
///
/// A single listener triggered by `previous.status != current.status` therefore
/// runs step 2's navigation branch whenever step 3 submits. At that moment
/// `state.step` is still `profile`, so the OTP screen pushes a SECOND copy of
/// the profile screen on top of the first — fresh State, empty controllers.
///
/// The patient watched a completed profile form wipe itself. It never wiped:
/// they were looking at a different screen. That is why chasing it through
/// `copyWith` and controller lifecycles finds nothing.
///
/// ## The rule
///
/// **Navigation reacts to step transitions. Feedback reacts to status
/// transitions.**
///
/// A loading screen over the in-flight window (see `RegisterProfileScreen`'s
/// `busy`) hides the symptom and is still worth having on its own merits — but
/// it does not fix this. The duplicate route stays on the stack.
class RegistrationFlowListeners extends StatelessWidget {
  const RegistrationFlowListeners({
    super.key,
    required this.onStepChanged,
    required this.child,
  });

  /// Called ONLY when [RegistrationState.step] actually changed.
  final void Function(BuildContext context, RegistrationState state)
  onStepChanged;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<RegistrationBloc, RegistrationState>(
      listenWhen: (RegistrationState previous, RegistrationState current) =>
          previous.step != current.step,
      listener: onStepChanged,
      child: BlocListener<RegistrationBloc, RegistrationState>(
        listenWhen: (RegistrationState previous, RegistrationState current) =>
            previous.status != current.status,
        listener: (BuildContext context, RegistrationState state) {
          final Failure? failure = state.failure;
          if (state.status != RegistrationStatus.failure || failure == null) {
            return;
          }

          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(failure.message)));
          context.read<RegistrationBloc>().add(
            const RegistrationFailureDismissed(),
          );
        },
        child: child,
      ),
    );
  }
}
