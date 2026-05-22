import '../data/crm_api.dart';
import 'lead.dart';

abstract class LeadRepository {
  Future<List<Lead>> list({String? status, String? salesId, String? q});
  Future<Lead> get(String id);
  Future<LeadConversion> convert(String id, {String? notes});
  Future<Map<String, dynamic>> coverageCheck({required double lat, required double lng});
  Future<List<Product>> listProducts();
  Future<Lead> create({
    required String fullName,
    required String phone,
    String? email,
    String? nik,
    required String address,
    double? gpsLat,
    double? gpsLng,
    String? productId,
    bool acceptExcessCable,
    String? notes,
  });
  Future<void> updateDocument({
    required String documentId,
    bool? submitted,
    String? fileUrl,
    String? notes,
  });
  Future<List<LeadDocument>> listDocuments(String leadId);
}

class LeadRepositoryImpl implements LeadRepository {
  LeadRepositoryImpl(this._api);
  final CrmApi _api;

  @override
  Future<List<Lead>> list({String? status, String? salesId, String? q}) =>
      _api.listLeads(status: status, salesId: salesId, q: q);

  @override
  Future<Lead> get(String id) => _api.getLead(id);

  @override
  Future<LeadConversion> convert(String id, {String? notes}) =>
      _api.convertLead(id, notes: notes);

  @override
  Future<Map<String, dynamic>> coverageCheck({required double lat, required double lng}) =>
      _api.coverageCheck(lat: lat, lng: lng);

  @override
  Future<List<Product>> listProducts() => _api.listProducts();

  @override
  Future<Lead> create({
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
  }) =>
      _api.createLead(
        fullName: fullName,
        phone: phone,
        email: email,
        nik: nik,
        address: address,
        gpsLat: gpsLat,
        gpsLng: gpsLng,
        productId: productId,
        acceptExcessCable: acceptExcessCable,
        notes: notes,
      );

  @override
  Future<void> updateDocument({
    required String documentId,
    bool? submitted,
    String? fileUrl,
    String? notes,
  }) =>
      _api.updateDocument(
        documentId: documentId,
        submitted: submitted,
        fileUrl: fileUrl,
        notes: notes,
      );

  @override
  Future<List<LeadDocument>> listDocuments(String leadId) =>
      _api.listDocuments(leadId);
}
