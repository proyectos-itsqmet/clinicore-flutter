import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../auth/presentation/blocs/auth/auth_bloc.dart';
import '../blocs/profile/profile_bloc.dart';

/// Puts the shared [ProfileBloc] above a subtree and makes sure it has data.
///
/// Both "Mi perfil" and "Mi informacion" read the same record, and the bloc is
/// a lazy singleton so they share one instance and one fetch. This widget is
/// what keeps that from turning into two problems:
///
/// * **It fetches only when the bloc has never fetched.** A plain
///   `add(ProfileRequested())` in `build` would refire on every rebuild, and in
///   `initState` of each screen it would refire every time the patient
///   navigates between the two. The guard is `status == initial`.
/// * **It uses `BlocProvider.value`, which does NOT close the bloc.** That is
///   the correct pairing for a locator-owned singleton: a `BlocProvider` that
///   created it would close it on the first screen's dispose, and the second
///   screen would then be reading a closed bloc.
///
/// It also forwards a dead session to [AuthBloc] once, from one place, rather
/// than having each screen listen for it.
class ProfileScope extends StatefulWidget {
  const ProfileScope({super.key, required this.child});

  final Widget child;

  @override
  State<ProfileScope> createState() => _ProfileScopeState();
}

class _ProfileScopeState extends State<ProfileScope> {
  final ProfileBloc _bloc = sl<ProfileBloc>();

  @override
  void initState() {
    super.initState();
    if (_bloc.state.status == ProfileStatus.initial) {
      _bloc.add(const ProfileRequested());
    }
  }

  // No `dispose` that closes `_bloc`, on purpose. See the class doc.

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProfileBloc>.value(
      value: _bloc,
      child: BlocListener<ProfileBloc, ProfileState>(
        listenWhen: (ProfileState previous, ProfileState current) =>
            current.isSessionExpired && !previous.isSessionExpired,
        listener: (BuildContext context, ProfileState state) {
          context.read<AuthBloc>().add(const AuthSessionExpired());
        },
        child: widget.child,
      ),
    );
  }
}
