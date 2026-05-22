import 'package:dio/dio.dart';

import 'package:ion_sales_app/shared.dart';
import '../domain/lead.dart';

/// Wire-level CRM client. Knows JSON shapes for /api/crm/* — domain
/// objects come out, repositories don't touch Dio.
class CrmApi {
  CrmApi(this._client);

  final ApiClient _client;

  static final _post = Options(method: 'POST', contentType: 'application/json');

  Future<List<Lead>> listLeads({String? status, String? salesId, String? q}) async {
    final res = await _client.request<Map<String, dynamic>>(
      '/api/crm/leads',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (salesId != null && salesId.isNotEmpty) 'sales_id': salesId,
        if (q != null && q.isNotEmpty) 'q': q,
        'page_size': 100,
      },
    );
    final items = (res.data?['items'] as List<dynamic>? ?? <dynamic>[]);
    return items
        .map((e) => _leadFromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Lead> getLead(String id) async {
    final res = await _client.request<Map<String, dynamic>>('/api/crm/leads/$id');
    return _leadFromJson(res.data ?? const <String, dynamic>{});
  }

  Future<List<LeadDocument>> listDocuments(String leadId) async {
    final res = await _client.request<Map<String, dynamic>>('/api/crm/leads/$leadId');
    final list = (res.data?['documents'] as List<dynamic>? ?? <dynamic>[]);
    return list
        .map((e) => LeadDocument.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Convert a lead. Backend creates customer + order + (when configured)
  /// the auto-OTC invoice. Response shape: `{customer: {...}, order: {...}}`.
  Future<LeadConversion> convertLead(String id, {String? notes}) async {
    final res = await _client.request<Map<String, dynamic>>(
      '/api/crm/leads/$id/convert',
      data: {if (notes != null) 'notes': notes},
      options: _post,
    );
    final m = res.data ?? const <String, dynamic>{};
    final customer = (m['customer'] as Map<String, dynamic>?) ?? const {};
    final order = (m['order'] as Map<String, dynamic>?) ?? const {};
    return LeadConversion(
      customerId: customer['id'] as String? ?? '',
      orderId: order['id'] as String? ?? '',
      invoiceId: order['otc_invoice_id'] as String?,
    );
  }

  /// Coverage check against a (lat, lng). Mirrors the self-order /
  /// sales-assisted flow. Returns the raw map — the cable distance,
  /// nearest node id, and verdict are all surfaced via this single call.
  Future<Map<String, dynamic>> coverageCheck({required double lat, required double lng}) async {
    final res = await _client.request<Map<String, dynamic>>(
      '/api/network/coverage/check',
      data: {'gps_lat': lat, 'gps_lng': lng},
      options: _post,
    );
    return res.data ?? const <String, dynamic>{};
  }

  Future<List<Product>> listProducts() async {
    final res = await _client.request<Map<String, dynamic>>(
      '/api/crm/products',
      queryParameters: {'active_only': true, 'page_size': 100},
    );
    final items = (res.data?['items'] as List<dynamic>? ?? <dynamic>[]);
    return items
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Create a lead. The Sales App calls this after the wizard collects
  /// coverage + product + GPS + (optionally) KTP-parsed fields.
  ///
  /// Wave 80 (backend Wave 76): added [leadType] (default broadband)
  /// and [referrerCustomerId] (required when source=referral). The
  /// backend rejects referrer_customer_id pointing at non-active
  /// customers (TC-CRM-008), so callers should filter their dropdown
  /// to status=active before submitting.
  Future<Lead> createLead({
    required String fullName,
    required String phone,
    String? email,
    String? nik,
    required String address,
    double? gpsLat,
    double? gpsLng,
    String? productId,
    bool acceptExcessCable = false,
    String? notes,
    String source = 'sales_app',
    String leadType = 'broadband',
    String? referrerCustomerId,
  }) async {
    final res = await _client.request<Map<String, dynamic>>(
      '/api/crm/leads',
      data: {
        'full_name': fullName,
        'phone': phone,
        if (email != null) 'email': email,
        if (nik != null) 'nik': nik,
        'address': address,
        if (gpsLat != null) 'gps_lat': gpsLat,
        if (gpsLng != null) 'gps_lng': gpsLng,
        if (productId != null) 'product_id': productId,
        if (notes != null) 'notes': notes,
        'accept_excess_cable': acceptExcessCable,
        'source': source,
        'lead_type': leadType,
        if (referrerCustomerId != null) 'referrer_customer_id': referrerCustomerId,
      },
      options: _post,
    );
    return _leadFromJson(res.data ?? const <String, dynamic>{});
  }

  /// Update a single document-checklist row (mark submitted, attach a
  /// file URL). Used by the Sales App's document upload screen.
  Future<void> updateDocument({
    required String documentId,
    bool? submitted,
    String? fileUrl,
    String? notes,
  }) async {
    await _client.request<dynamic>(
      '/api/crm/documents/$documentId',
      data: {
        if (submitted != null) 'submitted': submitted,
        if (fileUrl != null) 'file_url': fileUrl,
        if (notes != null) 'notes': notes,
      },
      options: Options(method: 'PATCH', contentType: 'application/json'),
    );
  }
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.code,
    required this.monthlyPrice,
    required this.otcPrice,
    this.speedDown,
    this.speedUp,
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        code: j['code'] as String? ?? '',
        monthlyPrice: ((j['monthly_price'] as num?) ?? 0).toDouble(),
        otcPrice: ((j['otc_price'] as num?) ?? 0).toDouble(),
        speedDown: (j['speed_down_mbps'] as num?)?.toInt(),
        speedUp: (j['speed_up_mbps'] as num?)?.toInt(),
      );

  final String id;
  final String name;
  final String code;
  final double monthlyPrice;
  final double otcPrice;
  final int? speedDown;
  final int? speedUp;
}

Lead _leadFromJson(Map<String, dynamic> j) => Lead(
      id: j['id'] as String? ?? '',
      leadNumber: j['lead_number'] as String? ?? '',
      fullName: j['full_name'] as String? ?? '',
      phone: j['phone'] as String? ?? '',
      email: j['email'] as String?,
      address: j['address'] as String? ?? '',
      productId: j['product_id'] as String?,
      productName: j['product_name'] as String?,
      status: j['status'] as String? ?? 'new',
      // Wave 80 (backend Wave 76 — TC-CRM-002): lead_type from wire,
      // default to 'broadband' for back-compat with pre-Wave-76 rows.
      leadType: j['lead_type'] as String? ?? 'broadband',
      source: j['source'] as String?,
      salesId: j['sales_id'] as String?,
      notes: j['notes'] as String?,
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      convertedCustomerId: j['converted_customer_id'] as String?,
      convertedOrderId: j['converted_order_id'] as String?,
      onboardingSchemaId: j['onboarding_schema_id'] as String?,
      acceptExcessCable: j['accept_excess_cable'] as bool? ?? false,
      // Wave 80 (TC-CRM-007/008/010): referrer linkage + joined name.
      referrerCustomerId: j['referrer_customer_id'] as String?,
      referrerCustomerName: j['referrer_customer_name'] as String?,
    );
