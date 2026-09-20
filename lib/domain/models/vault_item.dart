import 'totp_config.dart';

enum VaultItemType { login, secureNote }

/// 条目适用范围：网站、应用，或两者皆可。
enum VaultItemScope {
  web,
  app,
  both;

  static VaultItemScope fromName(String? name) => VaultItemScope.values
      .firstWhere((value) => value.name == name, orElse: () => VaultItemScope.both);

  String get label => switch (this) {
        VaultItemScope.web => '网站',
        VaultItemScope.app => '应用',
        VaultItemScope.both => '应用及网站',
      };
}

class VaultItem {
  const VaultItem({
    required this.id,
    this.groupId = 'default',
    required this.type,
    required this.title,
    required this.username,
    required this.password,
    required this.urls,
    this.appPackages = const [],
    this.scope = VaultItemScope.both,
    required this.notes,
    this.tags = const [],
    this.totp,
    required this.favorite,
    required this.createdAt,
    required this.updatedAt,
    required this.revision,
  });

  final String id;
  final String groupId;
  final VaultItemType type;
  final String title;
  final String username;
  final String password;
  final List<String> urls;
  final List<String> appPackages;
  final VaultItemScope scope;
  final String notes;
  final List<String> tags;
  final TotpConfig? totp;
  final bool favorite;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revision;

  factory VaultItem.fromJson(Map<String, dynamic> json) {
    return VaultItem(
      id: json['id'] as String,
      groupId: json['groupId'] as String? ?? 'default',
      type: VaultItemType.values.byName(json['type'] as String),
      title: json['title'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
      urls: List.unmodifiable(
        (json['urls'] as List<dynamic>? ?? const []).cast<String>(),
      ),
      appPackages: List.unmodifiable(
        (json['appPackages'] as List<dynamic>? ?? const []).cast<String>(),
      ),
      scope: VaultItemScope.fromName(json['scope'] as String?),
      notes: json['notes'] as String,
      tags: List.unmodifiable(
        (json['tags'] as List<dynamic>? ?? const []).cast<String>(),
      ),
      totp: json['totp'] == null
          ? null
          : TotpConfig.fromJson(json['totp'] as Map<String, dynamic>),
      favorite: json['favorite'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      revision: json['revision'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'groupId': groupId,
    'type': type.name,
    'title': title,
    'username': username,
    'password': password,
    'urls': urls,
    'appPackages': appPackages,
    'scope': scope.name,
    'notes': notes,
    'tags': tags,
    if (totp case final value?) 'totp': value.toJson(),
    'favorite': favorite,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'revision': revision,
  };

  VaultItem copyWith({
    String? groupId,
    String? title,
    String? username,
    String? password,
    List<String>? urls,
    List<String>? appPackages,
    VaultItemScope? scope,
    String? notes,
    List<String>? tags,
    TotpConfig? totp,
    bool clearTotp = false,
    bool? favorite,
    DateTime? updatedAt,
    int? revision,
  }) {
    return VaultItem(
      id: id,
      groupId: groupId ?? this.groupId,
      type: type,
      title: title ?? this.title,
      username: username ?? this.username,
      password: password ?? this.password,
      urls: List.unmodifiable(urls ?? this.urls),
      appPackages: List.unmodifiable(appPackages ?? this.appPackages),
      scope: scope ?? this.scope,
      notes: notes ?? this.notes,
      tags: List.unmodifiable(tags ?? this.tags),
      totp: clearTotp ? null : totp ?? this.totp,
      favorite: favorite ?? this.favorite,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      revision: revision ?? this.revision,
    );
  }
}