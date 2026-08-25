import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../../domain/entities/coverage.dart';
import '../../../domain/usecases/coverage_usecases.dart';

part 'coverage_event.dart';
part 'coverage_state.dart';

/// Owns the "Cobertura" group in `PersonalInfoScreen`.
///
/// A SEPARATE bloc from `ProfileBloc` on purpose, even though both back the
/// same screen: `ProfileBloc` is a lazy singleton shared with "Mi perfil",
/// which has no use for coverage at all. Folding this fetch into it would
/// mean visiting "Mi perfil" also asks the server for coverage data nobody
/// there is about to look at.
///
/// Registered as a **factory**, unlike `ProfileBloc`: only one screen ever
/// reads it, so there is no cross-screen fetch to share.
class CoverageBloc extends Bloc<CoverageEvent, CoverageState> {
  CoverageBloc({required this.getMyCoverages})
    : super(const CoverageState.initial()) {
    on<CoverageRequested>(_onRequested);
  }

  final GetMyCoverages getMyCoverages;

  Future<void> _onRequested(
    CoverageRequested event,
    Emitter<CoverageState> emit,
  ) async {
    emit(state.copyWith(status: CoverageStatus.loading, clearFailure: true));

    final result = await getMyCoverages(const NoParams());

    emit(
      result.fold(
        (Failure failure) =>
            state.copyWith(status: CoverageStatus.failure, failure: failure),
        (List<CoverageRecord> coverages) => state.copyWith(
          status: CoverageStatus.ready,
          coverages: coverages,
          clearFailure: true,
        ),
      ),
    );
  }
}
