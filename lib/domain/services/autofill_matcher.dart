import '../models/vault_item.dart';

List<VaultItem> matchingAutofillItems({
  required List<VaultItem> items,
  required Iterable<String> domains,
  required Iterable<String> packageNames,
}) {
  final normalizedDomains = domains
      .map((value) => _host(value))
      .where((value) => value.isNotEmpty)
      .toSet();
  final normalizedPackages = packageNames
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .toSet();
  return [
    for (final item in items)
      if (_matches(item, normalizedDomains, normalizedPackages)) item,
  ];
}

bool _matches(
  VaultItem item,
  Set<String> normalizedDomains,
  Set<String> normalizedPackages,
) {
  // 适用范围为「应用」时不再按网站匹配，为「网站」时不再按应用匹配。
  final allowWeb = item.scope != VaultItemScope.app;
  final allowApp = item.scope != VaultItemScope.web;

  if (allowWeb &&
      item.urls.any((url) {
        final normalized = url.trim().toLowerCase();
        final host = _host(normalized);
        return normalizedDomains.any(
              (domain) => host == domain || host.endsWith('.$domain'),
            ) ||
            normalizedPackages.contains(normalized) ||
            normalizedPackages.contains(host);
      })) {
    return true;
  }

  if (allowApp &&
      item.appPackages.any(
        (packageName) => normalizedPackages.contains(
          packageName.trim().toLowerCase(),
        ),
      )) {
    return true;
  }

  return false;
}

String _host(String value) {
  if (value.trim().isEmpty) return '';
  final normalized = value.trim().toLowerCase();
  final uri = Uri.tryParse(
    normalized.contains('://') ? normalized : '//$normalized',
  );
  return (uri?.host ?? '').replaceFirst(RegExp(r'^www\.'), '');
}