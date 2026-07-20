import 'geofence.dart';
import 'policy.dart';
import 'telegram_config.dart';

class OfficeConfig {
  final String officeId;
  final String officeName;
  final String groupName;
  final List<String> departments;
  final Geofence geofence;
  final Policy policy;
  final TelegramConfig telegramConfig;

  OfficeConfig({
    required this.officeId,
    required this.officeName,
    required this.groupName,
    List<String> departments = const <String>[],
    required this.geofence,
    required this.policy,
    required this.telegramConfig,
  }) : departments = _normalizeDepartments(
         departments: departments,
         fallbackGroupName: groupName,
       );

  factory OfficeConfig.fromJson(Map<String, dynamic> json) {
    final rawGroupName = (json['group_name'] ?? '').toString().trim();
    final parsedDepartments = _parseDepartments(
      rawDepartments: json['departments'],
      fallbackGroupName: rawGroupName,
    );
    final resolvedGroupName = rawGroupName.isNotEmpty
        ? rawGroupName
        : (parsedDepartments.isNotEmpty ? parsedDepartments.first : '');

    return OfficeConfig(
      officeId: json['office_id'] ?? '',
      officeName: json['office_name'] ?? '',
      groupName: resolvedGroupName,
      departments: parsedDepartments,
      geofence: Geofence.fromJson(json['geofence'] ?? {}),
      policy: Policy.fromJson(json['policy'] ?? {}),
      telegramConfig: TelegramConfig.fromJson(json['telegram_config'] ?? {}),
    );
  }

  OfficeConfig copyWith({
    String? officeId,
    String? officeName,
    String? groupName,
    List<String>? departments,
    Geofence? geofence,
    Policy? policy,
    TelegramConfig? telegramConfig,
  }) {
    return OfficeConfig(
      officeId: officeId ?? this.officeId,
      officeName: officeName ?? this.officeName,
      groupName: groupName ?? this.groupName,
      departments: departments ?? this.departments,
      geofence: geofence ?? this.geofence,
      policy: policy ?? this.policy,
      telegramConfig: telegramConfig ?? this.telegramConfig,
    );
  }

  Map<String, dynamic> toJson() => {
    'office_id': officeId,
    'office_name': officeName,
    'group_name': groupName,
    'departments': departments,
    'geofence': geofence.toJson(),
    'policy': policy.toJson(),
    'telegram_config': telegramConfig.toJson(),
  };

  static List<String> _parseDepartments({
    required dynamic rawDepartments,
    required String fallbackGroupName,
  }) {
    final parsed = <String>[];
    if (rawDepartments is List) {
      for (final item in rawDepartments) {
        final value = item?.toString().trim() ?? '';
        if (value.isNotEmpty) {
          parsed.add(value);
        }
      }
    }

    return _normalizeDepartments(
      departments: parsed,
      fallbackGroupName: fallbackGroupName,
    );
  }

  static List<String> _normalizeDepartments({
    required List<String> departments,
    required String fallbackGroupName,
  }) {
    final normalized = <String>{
      for (final department in departments)
        if (department.trim().isNotEmpty) department.trim(),
    };

    final groupName = fallbackGroupName.trim();
    if (groupName.isNotEmpty) {
      normalized.add(groupName);
    }

    final list = normalized.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }
}
