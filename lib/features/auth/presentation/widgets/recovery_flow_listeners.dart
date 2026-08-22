import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../blocs/recovery/recovery_bloc.dart';

/// Two listeners on [RecoveryBloc], and the split is load-bearing.
///
/// ## The bug this exists to prevent
///
/// All three recovery screens share ONE bloc — it lives on the `ShellRoute` —
/// and all three stay MOUNTED, because each step is pushed on top of the last.
/// So every emission is delivered to all three listeners.
///
/// A single listener triggered by `previous.status != current.status` therefore
/// runs step 1's navigation branch whenever step 2 submits. And at that moment
/// `state.step` is still `code`, so step 1 happily pushes a SECOND copy of the
/// code screen on top of the first — fresh State, empty field. The patient sees
/// the code they just typed disappear, and then the flow moves on.
///
/// It looks exactly like a form resetting itself. It is not: it is a different
/// screen. Chasing it as a state bug leads nowhere, which is why this note is
/// long.
///
/// ## The rule
///
/// **Navigation reacts to step transitions. Feedback reacts to status
/// transitions.** Different questions, different triggers. Every screen in the
/// flow wraps itself in this and supplies only its own [onStepChanged].
///
/// The failure snackbar is handled HERE rather than per screen because it is
/// identical in all three, and because it is the half that legitimately wants
/// status changes — so putting it next to the half that must not have them is
/// how the two stay told apart.
///
/// Nested [BlocListener]s rather than `MultiBlocListener` only to avoid
/// importing `nested`, which is a transitive dependency here and trips
/// `depend_on_referenced_packages`.
class RecoveryFlowListeners extends StatelessWidget {
  const RecoveryFlowListeners({
    super.key,
    required this.onStepChanged,
    required this.child,
  });

  /// Called ONLY when [RecoveryState.step] actually changed.
  final void Function(BuildContext context, RecoveryState state) onStepChanged;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<RecoveryBloc, RecoveryState>(
      listenWhen: (RecoveryState previous, RecoveryState current) =>
          previous.step != current.step,
      listener: onStepChanged,
      child: BlocListener<RecoveryBloc, RecoveryState>(
        listenWhen: (RecoveryState previous, RecoveryState current) =>
            previous.status != current.status,
        listener: (BuildContext context, RecoveryState state) {
          final Failure? failure = state.failure;
          if (state.status != RecoveryStatus.failure || failure == null) return;

          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(failure.message)));
          context.read<RecoveryBloc>().add(const RecoveryFailureDismissed());
        },
        child: child,
      ),
    );
  }
}
