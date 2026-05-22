import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:ion_sales_app/shared.dart';
import '../../domain/lead.dart';
import '../../domain/lead_repository.dart';

part 'leads_event.dart';
part 'leads_state.dart';

/// Owns the lead-list view state for the Sales App.
///
/// Started with a Refresh; the StatusFiltered event narrows the same data
/// set; ConvertRequested fires a conversion + reloads. The bloc keeps the
/// most recent filter in-memory so a refresh after a convert reflects
/// the same scope.
class LeadsBloc extends Bloc<LeadsEvent, LeadsState> {
  LeadsBloc(this._repo) : super(const LeadsState()) {
    on<LeadsRefreshRequested>(_onRefresh);
    on<LeadsStatusFiltered>(_onStatusFilter);
    on<LeadConvertRequested>(_onConvert);
  }

  final LeadRepository _repo;

  Future<void> _onRefresh(LeadsRefreshRequested e, Emitter<LeadsState> emit) async {
    emit(state.copyWith(loading: true, error: null));
    try {
      final items = await _repo.list(status: state.statusFilter, q: e.q);
      emit(state.copyWith(loading: false, items: items, lastQuery: e.q));
    } on ApiException catch (err) {
      emit(state.copyWith(loading: false, error: err.message));
    }
  }

  Future<void> _onStatusFilter(LeadsStatusFiltered e, Emitter<LeadsState> emit) async {
    emit(state.copyWith(loading: true, statusFilter: e.status, error: null));
    try {
      final items = await _repo.list(status: e.status, q: state.lastQuery);
      emit(state.copyWith(loading: false, items: items));
    } on ApiException catch (err) {
      emit(state.copyWith(loading: false, error: err.message));
    }
  }

  Future<void> _onConvert(LeadConvertRequested e, Emitter<LeadsState> emit) async {
    emit(state.copyWith(converting: e.leadId, error: null));
    try {
      final conv = await _repo.convert(e.leadId, notes: e.notes);
      // Re-load to reflect status flip + converted ids.
      final items = await _repo.list(status: state.statusFilter, q: state.lastQuery);
      emit(state.copyWith(converting: null, items: items, lastConversion: conv));
    } on ApiException catch (err) {
      emit(state.copyWith(converting: null, error: err.message));
    }
  }
}
