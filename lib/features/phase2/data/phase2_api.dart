import 'package:dio/dio.dart';

import 'package:ion_sales_app/shared.dart';
import '../domain/phase2_models.dart';

/// Wire-level client for the Phase 2 CRM surface (add-ons,
/// plan-changes, relocations) plus the small customer-list call
/// that wasn't exposed by [CrmApi] in Phase 1.
///
/// All endpoints live under the same JWT-authenticated /api/crm gate
/// — permissions are enforced server-side via the new role-permission
/// matrix (see migration 0036).
class Phase2Api {
  Phase2Api(this._client);
  final ApiClient _client;

  static final _post = Options(method: 'POST', contentType: 'application/json');

  // ---- Customers ----

  Future<List<CustomerSummary>> listCustomers({String? q, int limit = 50}) async {
    final res = await _client.request<Map<String, dynamic>>(
      '/api/crm/customers',
      queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        'page_size': limit,
      },
    );
    final items = (res.data?['items'] as List<dynamic>? ?? <dynamic>[]);
    return items
        .map((e) => CustomerSummary.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  // ---- Add-on catalog + customer add-ons ----

  Future<List<Addon>> listAddons() async {
    final res = await _client.request<Map<String, dynamic>>('/api/crm/addons');
    final items = (res.data?['items'] as List<dynamic>? ?? <dynamic>[]);
    return items
        .map((e) => Addon.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<CustomerAddon> sellAddon({
    required String customerId,
    required String addonId,
    int quantity = 1,
    String? notes,
  }) async {
    final res = await _client.request<Map<String, dynamic>>(
      '/api/crm/customers/$customerId/addons',
      data: {
        'addon_id': addonId,
        'quantity': quantity,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
      options: _post,
    );
    return CustomerAddon.fromJson(res.data ?? const <String, dynamic>{});
  }

  Future<List<CustomerAddon>> listCustomerAddons(String customerId) async {
    final res = await _client.request<Map<String, dynamic>>(
      '/api/crm/customers/$customerId/addons',
    );
    final items = (res.data?['items'] as List<dynamic>? ?? <dynamic>[]);
    return items
        .map((e) => CustomerAddon.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  // ---- Plan change ----

  Future<Map<String, dynamic>> requestPlanChange({
    required String customerId,
    required String toProductId,
    required String changeKind, // 'upgrade' | 'downgrade'
    String? reason,
    DateTime? effectiveAt,
  }) async {
    final res = await _client.request<Map<String, dynamic>>(
      '/api/crm/customers/$customerId/plan-change',
      data: {
        'to_product_id': toProductId,
        'change_kind': changeKind,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        if (effectiveAt != null) 'effective_at': effectiveAt.toUtc().toIso8601String(),
      },
      options: _post,
    );
    return res.data ?? const <String, dynamic>{};
  }

  // ---- Relocation ----

  // ---- Approvals queue + decisions ----

  Future<List<Map<String, dynamic>>> listPendingPlanChanges() async {
    final res = await _client.request<Map<String, dynamic>>(
      '/api/crm/plan-changes/pending',
    );
    final items = (res.data?['items'] as List<dynamic>? ?? <dynamic>[]);
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> listPendingRelocations() async {
    final res = await _client.request<Map<String, dynamic>>(
      '/api/crm/relocations/pending',
    );
    final items = (res.data?['items'] as List<dynamic>? ?? <dynamic>[]);
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Decision = approved | rejected | applied | cancelled
  Future<Map<String, dynamic>> decidePlanChange({
    required String id,
    required String decision,
    String? note,
  }) async {
    final res = await _client.request<Map<String, dynamic>>(
      '/api/crm/plan-changes/$id',
      data: {
        'decision': decision,
        if (note != null && note.isNotEmpty) 'note': note,
      },
      options: Options(method: 'PATCH', contentType: 'application/json'),
    );
    return res.data ?? const <String, dynamic>{};
  }

  /// Decision = approved | rejected | survey_failed | completed | cancelled
  Future<Map<String, dynamic>> decideRelocation({
    required String id,
    required String decision,
    String? surveyNote,
  }) async {
    final res = await _client.request<Map<String, dynamic>>(
      '/api/crm/relocations/$id',
      data: {
        'decision': decision,
        if (surveyNote != null && surveyNote.isNotEmpty) 'survey_note': surveyNote,
      },
      options: Options(method: 'PATCH', contentType: 'application/json'),
    );
    return res.data ?? const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> requestRelocation({
    required String customerId,
    required String toAddress,
    double? toGpsLat,
    double? toGpsLng,
    String? notes,
  }) async {
    final res = await _client.request<Map<String, dynamic>>(
      '/api/crm/customers/$customerId/relocation',
      data: {
        'to_address': toAddress,
        if (toGpsLat != null) 'to_gps_lat': toGpsLat,
        if (toGpsLng != null) 'to_gps_lng': toGpsLng,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
      options: _post,
    );
    return res.data ?? const <String, dynamic>{};
  }
}
