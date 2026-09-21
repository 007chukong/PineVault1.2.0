import 'package:flutter/material.dart';

/// 全屏兜底背景层（1.2.4-1 起改为纯底色，不再渲染自定义图片）。
///
/// ============================ 维护说明（下次更新必看） ============================
/// 1. 1.2.4-repair 曾支持「背景设置」：本层读取 AppPreferences 的
///    backgroundPath / backgroundEnabled / backgroundOverlay / backgroundBlur 渲染自定义图片。
///    1.2.4-1 按用户反馈**移除「背景设置」功能**（设置页入口与 background_settings_screen.dart
///    均已删除），本层只保留「给透明 Scaffold 兜底」的职责，避免页面透明后露出黑色。
/// 2. 页面底色统一由本层绘制，所以：
///    - `app_theme.dart` 的 `scaffoldBackgroundColor` 必须保持 `Colors.transparent`；
///    - 各页 Scaffold / AppBar 不要再设不透明 `backgroundColor`（除底栏自带的磨砂玻璃），
///      否则会盖住本层底色。
/// 3. AppPreferences 里仍保留 background* 字段与 getter/setter（兼容历史数据、避免老用户
///    本地偏好解析出错），但已无任何 UI 入口、也不再被本层读取；将来若彻底清理，
///    需先确认全项目无引用（含 background_settings_screen.dart 已被删除这一点）。
/// ================================================================================
class PineVaultBackgroundLayer extends StatelessWidget {
  const PineVaultBackgroundLayer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // 兜底底色：跟随明暗主题（浅色 = 页面底色，深色 = 深色页面底色）。
        ColoredBox(color: Theme.of(context).colorScheme.surface),
        child,
      ],
    );
  }
}
