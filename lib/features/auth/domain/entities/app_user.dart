import '../../../../core/constants/app_constants.dart';

/// A row from public.users.
///
/// Mirrors the server columns exactly. `email` and `fullName` are nullable there
/// — a user registered by phone has neither — so they are nullable here too.
/// Reading them as non-null was crashing profile loads for such accounts.
class AppUser {
  const AppUser({
    required this.id,
    required this.role,
    this.email,
    this.fullName,
    this.phone,
    this.agencyType,
    this.verifiedPercent = 0,
    this.badge = VerificationBadge.yellow,
    this.phoneVerified = false,
    this.emailVerified = false,
    this.idVerified = false,
    this.createdAt,
  });

  final String id;
  final String role;
  final String? email;
  final String? fullName;
  final String? phone;

  /// Only set for sub_admin and response_team (users_agency_consistency).
  final String? agencyType;

  /// Progressive verification: phone 40 + national ID 50 + email 10 (Section 2.1).
  final int verifiedPercent;

  /// Derived server-side from verifiedPercent; never computed on the client.
  final String badge;

  final bool phoneVerified;
  final bool emailVerified;
  final bool idVerified;
  final DateTime? createdAt;

  bool get isAdmin => role == UserRole.admin;
  bool get isSubAdmin => role == UserRole.subAdmin;
  bool get isResponseTeam => role == UserRole.responseTeam;
  bool get isGeneralUser => role == UserRole.generalUser;

  /// Staff see the operational console; citizens see the SOS flow.
  bool get isStaff => UserRole.isStaff(role);

  /// What the user can still do to raise their credibility.
  bool get canVerifyPhone => !phoneVerified;
  bool get canVerifyEmail => !emailVerified && (email?.isNotEmpty ?? false);
  bool get canVerifyId => !idVerified;

  String get displayName {
    final name = fullName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return email ?? phone ?? 'RepLiT user';
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      role: map['role'] as String? ?? UserRole.generalUser,
      email: map['email'] as String?,
      fullName: map['full_name'] as String?,
      phone: map['phone'] as String?,
      agencyType: map['agency_type'] as String?,
      verifiedPercent: (map['verified_percent'] as num?)?.toInt() ?? 0,
      badge: map['badge'] as String? ?? VerificationBadge.yellow,
      phoneVerified: map['phone_verified'] as bool? ?? false,
      emailVerified: map['email_verified'] as bool? ?? false,
      idVerified: map['id_verified'] as bool? ?? false,
      createdAt: switch (map['created_at']) {
        final String s => DateTime.tryParse(s),
        final DateTime d => d,
        _ => null,
      },
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'role': role,
        'email': email,
        'full_name': fullName,
        'phone': phone,
        'agency_type': agencyType,
        'verified_percent': verifiedPercent,
        'badge': badge,
        'phone_verified': phoneVerified,
        'email_verified': emailVerified,
        'id_verified': idVerified,
        'created_at': createdAt?.toIso8601String(),
      };

  AppUser copyWith({
    String? id,
    String? role,
    String? email,
    String? fullName,
    String? phone,
    String? agencyType,
    int? verifiedPercent,
    String? badge,
    bool? phoneVerified,
    bool? emailVerified,
    bool? idVerified,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      role: role ?? this.role,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      agencyType: agencyType ?? this.agencyType,
      verifiedPercent: verifiedPercent ?? this.verifiedPercent,
      badge: badge ?? this.badge,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      emailVerified: emailVerified ?? this.emailVerified,
      idVerified: idVerified ?? this.idVerified,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
