import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ion_sales_app/shared.dart';
import 'package:ion_sales_app/features/crm/domain/lead.dart';
import 'package:ion_sales_app/features/crm/domain/lead_repository.dart';
import 'package:ion_sales_app/features/crm/presentation/bloc/leads_bloc.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements LeadRepository {}

void main() {
  group('LeadsBloc', () {
    late _MockRepo repo;

    setUp(() {
      repo = _MockRepo();
    });

    final aLead = Lead(
      id: 'lead-1',
      leadNumber: 'LD-20260101-0001',
      fullName: 'Budi Santoso',
      phone: '08111',
      address: 'Jl. Sudirman 1',
      status: 'new',
      createdAt: DateTime.utc(2026, 1, 1),
    );

    blocTest<LeadsBloc, LeadsState>(
      'Refresh fills items and clears loading',
      build: () {
        when(() => repo.list(status: any(named: 'status'), q: any(named: 'q')))
            .thenAnswer((_) async => [aLead]);
        return LeadsBloc(repo);
      },
      act: (bloc) => bloc.add(const LeadsRefreshRequested()),
      expect: () => [
        isA<LeadsState>().having((s) => s.loading, 'loading', true),
        isA<LeadsState>()
            .having((s) => s.loading, 'loading', false)
            .having((s) => s.items.length, 'count', 1)
            .having((s) => s.items.first.id, 'id', 'lead-1'),
      ],
    );

    blocTest<LeadsBloc, LeadsState>(
      'Refresh surfaces ApiException as error',
      build: () {
        when(() => repo.list(status: any(named: 'status'), q: any(named: 'q')))
            .thenThrow(ApiException.network('boom'));
        return LeadsBloc(repo);
      },
      act: (bloc) => bloc.add(const LeadsRefreshRequested()),
      expect: () => [
        isA<LeadsState>().having((s) => s.loading, 'loading', true),
        isA<LeadsState>()
            .having((s) => s.loading, 'loading', false)
            .having((s) => s.error != null, 'has error', true),
      ],
    );

    blocTest<LeadsBloc, LeadsState>(
      'StatusFiltered re-queries with the new filter',
      build: () {
        when(() => repo.list(status: any(named: 'status'), q: any(named: 'q')))
            .thenAnswer((_) async => const <Lead>[]);
        return LeadsBloc(repo);
      },
      act: (bloc) => bloc.add(const LeadsStatusFiltered(status: 'qualified')),
      verify: (_) => verify(() => repo.list(status: 'qualified', q: null)).called(1),
    );
  });
}
