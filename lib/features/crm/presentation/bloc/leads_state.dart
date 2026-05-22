part of 'leads_bloc.dart';

class LeadsState extends Equatable {
  const LeadsState({
    this.loading = false,
    this.items = const <Lead>[],
    this.statusFilter,
    this.lastQuery,
    this.converting,
    this.error,
    this.lastConversion,
  });

  final bool loading;
  final List<Lead> items;
  final String? statusFilter;
  final String? lastQuery;
  final String? converting;
  final String? error;
  final LeadConversion? lastConversion;

  LeadsState copyWith({
    bool? loading,
    List<Lead>? items,
    Object? statusFilter = _noChange,
    Object? lastQuery = _noChange,
    Object? converting = _noChange,
    Object? error = _noChange,
    Object? lastConversion = _noChange,
  }) =>
      LeadsState(
        loading: loading ?? this.loading,
        items: items ?? this.items,
        statusFilter: statusFilter == _noChange ? this.statusFilter : statusFilter as String?,
        lastQuery: lastQuery == _noChange ? this.lastQuery : lastQuery as String?,
        converting: converting == _noChange ? this.converting : converting as String?,
        error: error == _noChange ? this.error : error as String?,
        lastConversion: lastConversion == _noChange ? this.lastConversion : lastConversion as LeadConversion?,
      );

  @override
  List<Object?> get props =>
      [loading, items, statusFilter, lastQuery, converting, error, lastConversion];
}

const _noChange = Object();
