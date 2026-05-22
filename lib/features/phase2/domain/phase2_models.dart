import 'package:equatable/equatable.dart';

class CustomerSummary extends Equatable {
  const CustomerSummary({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.address,
    this.status,
    this.productName,
  });

  factory CustomerSummary.fromJson(Map<String, dynamic> j) => CustomerSummary(
        id: j['id'] as String? ?? '',
        fullName: j['full_name'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        address: j['address'] as String? ?? '',
        status: j['status'] as String?,
        productName: j['product_name'] as String?,
      );

  final String id;
  final String fullName;
  final String phone;
  final String address;
  final String? status;
  final String? productName;

  @override
  List<Object?> get props => [id, status];
}

class Addon extends Equatable {
  const Addon({
    required this.id,
    required this.code,
    required this.name,
    required this.addonType,
    required this.oneTimeFee,
    required this.monthlyFee,
    required this.requiresInstall,
    this.description,
  });

  factory Addon.fromJson(Map<String, dynamic> j) => Addon(
        id: j['id'] as String? ?? '',
        code: j['code'] as String? ?? '',
        name: j['name'] as String? ?? '',
        addonType: j['addon_type'] as String? ?? '',
        oneTimeFee: (j['one_time_fee'] as num?)?.toDouble() ?? 0,
        monthlyFee: (j['monthly_fee'] as num?)?.toDouble() ?? 0,
        requiresInstall: j['requires_install'] as bool? ?? false,
        description: j['description'] as String?,
      );

  final String id;
  final String code;
  final String name;
  final String addonType;
  final double oneTimeFee;
  final double monthlyFee;
  final bool requiresInstall;
  final String? description;

  @override
  List<Object?> get props => [id, code];
}

class CustomerAddon extends Equatable {
  const CustomerAddon({
    required this.id,
    required this.customerId,
    required this.addonCode,
    required this.addonName,
    required this.addonType,
    required this.status,
    required this.quantity,
    required this.oneTimeFee,
    required this.monthlyFee,
    this.requestedAt,
  });

  factory CustomerAddon.fromJson(Map<String, dynamic> j) => CustomerAddon(
        id: j['id'] as String? ?? '',
        customerId: j['customer_id'] as String? ?? '',
        addonCode: j['addon_code'] as String? ?? '',
        addonName: j['addon_name'] as String? ?? '',
        addonType: j['addon_type'] as String? ?? '',
        status: j['status'] as String? ?? 'unknown',
        quantity: (j['quantity'] as num?)?.toInt() ?? 1,
        oneTimeFee: (j['one_time_fee'] as num?)?.toDouble() ?? 0,
        monthlyFee: (j['monthly_fee'] as num?)?.toDouble() ?? 0,
        requestedAt: j['requested_at'] == null
            ? null
            : DateTime.tryParse(j['requested_at'] as String),
      );

  final String id;
  final String customerId;
  final String addonCode;
  final String addonName;
  final String addonType;
  final String status;
  final int quantity;
  final double oneTimeFee;
  final double monthlyFee;
  final DateTime? requestedAt;

  @override
  List<Object?> get props => [id, status];
}
