import 'package:flutter_test/flutter_test.dart';
import 'package:ion_sales_app/features/crm/domain/lead.dart';

// Wave 80 — pin the new lead shape that consumes backend Wave 76.
// The wizard reads/writes these fields end-to-end; the model is the
// contract surface between mobile and backend.

void main() {
  group('Lead — Wave 80 additions', () {
    test('default constructor sets leadType=broadband', () {
      // The Wave 76 backend defaults lead_type to broadband; mobile
      // mirrors that to avoid sending null when the wizard skips
      // an explicit selector.
      final l = Lead(
        id: 'L1',
        leadNumber: 'LD-2026',
        fullName: 'Budi',
        phone: '0811',
        address: 'Jakarta',
        status: 'new',
        createdAt: DateTime.utc(2026, 5, 23),
      );
      expect(l.leadType, 'broadband');
      expect(l.referrerCustomerId, isNull);
      expect(l.referrerCustomerName, isNull);
    });

    test('enterprise lead type is preserved', () {
      final l = Lead(
        id: 'L2',
        leadNumber: 'LD-2026',
        fullName: 'PT Foo',
        phone: '02199',
        address: 'Jakarta',
        status: 'new',
        leadType: 'enterprise',
        createdAt: DateTime.utc(2026, 5, 23),
      );
      expect(l.leadType, 'enterprise');
    });

    test('referrer fields propagate when source=referral', () {
      // Wave 80 (TC-CRM-007/008/010): the wizard sets referrer_*; the
      // backend response echoes both id + joined name. The detail
      // page renders name when present.
      final l = Lead(
        id: 'L3',
        leadNumber: 'LD-2026',
        fullName: 'Sari',
        phone: '0812',
        address: 'Bandung',
        status: 'new',
        source: 'referral',
        referrerCustomerId: 'cust-123',
        referrerCustomerName: 'Pak Joko (existing customer)',
        createdAt: DateTime.utc(2026, 5, 23),
      );
      expect(l.source, 'referral');
      expect(l.referrerCustomerId, 'cust-123');
      expect(l.referrerCustomerName, 'Pak Joko (existing customer)');
    });
  });

  group('kLeadSourcesUserSelectable', () {
    test('contains the PRD-11 user-facing sources', () {
      // Wave 80 (TC-CRM-006): backend now accepts the full enum; the
      // dropdown surfaces the user-selectable ten (operational
      // sources like sales_app/self_order are inferred, not picked).
      expect(kLeadSourcesUserSelectable, contains('referral'));
      expect(kLeadSourcesUserSelectable, contains('cold_call'));
      expect(kLeadSourcesUserSelectable, contains('whatsapp'));
      expect(kLeadSourcesUserSelectable, contains('walk_in'));
      expect(kLeadSourcesUserSelectable, contains('event'));
      expect(kLeadSourcesUserSelectable, contains('partner'));
      // Operational sources are NOT user-selectable.
      expect(kLeadSourcesUserSelectable, isNot(contains('sales_app')));
      expect(kLeadSourcesUserSelectable, isNot(contains('manual')));
      expect(kLeadSourcesUserSelectable, isNot(contains('self_order')));
      expect(kLeadSourcesUserSelectable, isNot(contains('cs_referral')));
    });

    test('list is exactly the user-selectable 10', () {
      expect(kLeadSourcesUserSelectable.length, 10);
    });
  });

  group('kLeadTypes', () {
    test('exposes broadband + enterprise', () {
      expect(kLeadTypes, ['broadband', 'enterprise']);
    });
  });
}
