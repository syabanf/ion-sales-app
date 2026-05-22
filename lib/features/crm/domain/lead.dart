import 'package:equatable/equatable.dart';

/// Lead status mirrors the backend's CRM domain. We keep the strings as
/// the source of truth — the lifecycle is small enough that an enum
/// adds little value and the UI just renders the string anyway.
class Lead extends Equatable {
  const Lead({
    required this.id,
    required this.leadNumber,
    required this.fullName,
    required this.phone,
    this.email,
    required this.address,
    this.productId,
    this.productName,
    required this.status,
    this.source,
    this.salesId,
    this.notes,
    required this.createdAt,
    this.convertedCustomerId,
    this.convertedOrderId,
    this.onboardingSchemaId,
    this.acceptExcessCable = false,
  });

  final String id;
  final String leadNumber;
  final String fullName;
  final String phone;
  final String? email;
  final String address;
  final String? productId;
  final String? productName;
  final String status;
  final String? source;
  final String? salesId;
  final String? notes;
  final DateTime createdAt;
  final String? convertedCustomerId;
  final String? convertedOrderId;
  final String? onboardingSchemaId;
  final bool acceptExcessCable;

  bool get isConverted => convertedCustomerId != null;

  @override
  List<Object?> get props => [id, leadNumber, fullName, phone, status, createdAt];
}

class LeadConversion extends Equatable {
  const LeadConversion({required this.customerId, required this.orderId, this.invoiceId});
  final String customerId;
  final String orderId;
  final String? invoiceId;

  @override
  List<Object?> get props => [customerId, orderId, invoiceId];
}

class LeadDocument extends Equatable {
  const LeadDocument({
    required this.id,
    required this.leadId,
    required this.docKey,
    required this.label,
    required this.required,
    required this.submitted,
    this.fileUrl,
    this.notes,
  });

  factory LeadDocument.fromJson(Map<String, dynamic> j) => LeadDocument(
        id: j['id'] as String? ?? '',
        leadId: j['lead_id'] as String? ?? '',
        docKey: j['doc_key'] as String? ?? '',
        label: j['label'] as String? ?? '',
        required: j['required'] as bool? ?? false,
        submitted: j['submitted'] as bool? ?? false,
        fileUrl: j['file_url'] as String?,
        notes: j['notes'] as String?,
      );

  final String id;
  final String leadId;
  final String docKey;
  final String label;
  final bool required;
  final bool submitted;
  final String? fileUrl;
  final String? notes;

  @override
  List<Object?> get props => [id, submitted, fileUrl];
}
