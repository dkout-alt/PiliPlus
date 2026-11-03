import 'package:material_ui/material_ui.dart';

/// 视频封面 → 播放器 的 Hero tag（同一视频唯一）
///
/// 注意：`/videoV` 页面里也内联了同样的格式，改动时需同步。
String videoCoverHeroTag(Object? id) => 'videoCover-$id';

/// 飞行期间始终渲染源端（卡片封面），使前进与返回都连续
Widget videoCoverShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromContext,
  BuildContext toContext,
) {
  final hero = direction == HeroFlightDirection.push
      ? fromContext.widget as Hero
      : toContext.widget as Hero;
  return hero.child;
}

/// 视频封面 → 播放器 的共享元素
///
/// [id] 为空时原样返回（该条目没有可跳转的视频详情，不启用动画）。
/// id 通常为 `bvid`；动态页需传 `dyn-<动态id>`，避免同一路由内 tag 冲突。
Widget videoCoverHero(String? id, Widget child) {
  if (id == null || id.isEmpty) return child;
  return Hero(
    tag: videoCoverHeroTag(id),
    flightShuttleBuilder: videoCoverShuttle,
    child: child,
  );
}

/// 历史遗留：`PageUtils.toVideoPage` 仍会写入，当前未使用
abstract final class ContainerTransformSource {
  static Rect? pending;
}
