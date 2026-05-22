part of 'leads_bloc.dart';

abstract class LeadsEvent extends Equatable {
  const LeadsEvent();
  @override
  List<Object?> get props => const [];
}

class LeadsRefreshRequested extends LeadsEvent {
  const LeadsRefreshRequested({this.q});
  final String? q;
  @override
  List<Object?> get props => [q];
}

class LeadsStatusFiltered extends LeadsEvent {
  const LeadsStatusFiltered({this.status});
  final String? status;
  @override
  List<Object?> get props => [status];
}

class LeadConvertRequested extends LeadsEvent {
  const LeadConvertRequested({required this.leadId, this.notes});
  final String leadId;
  final String? notes;
  @override
  List<Object?> get props => [leadId, notes];
}
