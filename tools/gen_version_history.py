"""按 CHANGELOG.md 重新生成 version_history_screen.dart 的 _entries 列表。

用法（在仓库根目录）：
    python3 tools/gen_version_history.py

发版顺序：先在 CHANGELOG.md 顶部加 `## <tag>（<日期>）` 段 -> 运行本脚本 ->
把 pubspec.yaml 的 version 加到对应 build 号 -> git tag <tag> -> push tag 触发 CI。
"""
import io, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = '007chukong/PineVault1.2.0'
TARGET = os.path.join(ROOT, 'lib/ui/features/settings/version_history_screen.dart')


def parse(changelog):
    segs = re.split(r'^##\s+', changelog, flags=re.M)[1:]
    out = []
    for seg in segs:
        head, _, body = seg.partition('\n')
        m = re.match(r'^\s*([^\s（(]+)\s*[（(]([^）)]*)[）)]\s*$', head.strip())
        if not m:
            continue
        ver, date = m.group(1).lstrip('v'), m.group(2).strip()
        items, cur = [], None
        for l in body.split('\n'):
            if l.startswith('- '):
                if cur:
                    items.append(cur)
                cur = l[2:].strip()
            elif cur is not None and l.strip() and not l.startswith('#'):
                cur += l.strip()
            elif not l.strip() and cur:
                items.append(cur)
                cur = None
            if len(items) >= 2:
                break
        if cur and len(items) < 2:
            items.append(cur)
        summary = '；'.join(x.rstrip('。；;') for x in items[:2])
        if ver == '1.2.4':
            summary = '（已撤回，由 1.2.4-repair 取代）' + summary
        url = ('https://github.com/%s/releases' % REPO) if ver == '1.2.4' \
            else ('https://github.com/%s/releases/tag/%s' % (REPO, ver))
        out.append((ver, date, summary, url))
    return out


def esc(s):
    return s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$')


def main():
    entries = parse(io.open(os.path.join(ROOT, 'CHANGELOG.md'), encoding='utf-8').read())
    block = ''.join(
        "  const _VersionEntry(\n    version: '%s',\n    date: '%s',\n"
        "    log: '%s',\n    repoUrl: '%s',\n  ),\n"
        % (esc(v), esc(d), esc(g), esc(u)) for v, d, g, u in entries)
    src = io.open(TARGET, encoding='utf-8').read()
    new, n = re.subn(r'(?s)(const List<_VersionEntry> _entries = <_VersionEntry>\[\n)(.*?)(\];)',
                     lambda m: m.group(1) + block + m.group(3), src)
    if n != 1:
        raise SystemExit('未找到 _entries 列表，替换失败')
    io.open(TARGET, 'w', encoding='utf-8').write(new)
    print('已写入 %d 个版本：%s' % (len(entries), ', '.join(v for v, _, _, _ in entries)))


if __name__ == '__main__':
    main()
