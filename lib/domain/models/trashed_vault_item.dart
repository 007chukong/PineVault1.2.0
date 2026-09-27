import 'vault_item.dart';

/// 回收站条目：被删除的 [VaultItem] 与删除时间（1.2.6 新增）。
///
/// 说明：
/// 1. 本记录随主密码库一起加密保存在 `vault.pvlt` 内，不额外落明文文件，
///    因此云同步时同样是密文，不会泄露条目内容；
/// 2. 默认保留 [retentionDays] 天，可在「设置 → 数据 → 回收站」中找回或
///    彻底删除；
/// 3. 与 [Vault.tombstones]（云端删除标记）语义不同：tombstones 表示
///    「删除」这个事实需要同步到云端，回收站只保留可找回的副本。
class TrashedVaultItem {
  const TrashedVaultItem({required this.item, required this.deletedAt});

  final VaultItem item;
  final DateTime deletedAt;

  /// 回收站保留天数。
  static const int retentionDays = 30;

  /// 是否为过期条目（已超过 [retentionDays] 未处理）。
  bool isExpiredAt(DateTime now) =>
      now.difference(deletedAt).inDays >= retentionDays;

  /// 距自动清理还剩几天（最小为 0）。
  int remainingDaysAt(DateTime now) {
    final used = now.difference(deletedAt).inDays;
    final left = retentionDays - used;
    return left < 0 ? 0 : left;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'deletedAt': deletedAt.toUtc().toIso8601String(),
    'item': item.toJson(),
  };

  factory TrashedVaultItem.fromJson(Map<String, dynamic> json) {
    return TrashedVaultItem(
      item: VaultItem.fromJson(json['item'] as Map<String, dynamic>),
      deletedAt: DateTime.parse(json['deletedAt'] as String).toUtc(),
    );
  }
}
