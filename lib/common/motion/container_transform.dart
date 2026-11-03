import 'dart:ui' show lerpDouble;

import 'package:material_ui/material_ui.dart';

/// 传给 `/videoV` 的 arguments key，值为被点击卡片封面的全局矩形
const kSourceRectKey = 'sourceRect';

/// 从路由 arguments 中安全取出封面矩形，取不到返回 null（退化为普通淡入）
Rect? containerTransformSource(Object? arguments) {
  if (arguments is Map) {
    final value = arguments[kSourceRectKey];
    if (value is Rect) return value;
  }
  return null;
}

/// 给定卡片宽度，返回封面（16:9）在屏幕上的矩形
Rect? coverRectOf(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) return null;
  final origin = renderObject.localToGlobal(Offset.zero);
  final width = renderObject.size.width;
  if (width <= 0) return null;
  return Rect.fromLTWH(origin.dx, origin.dy, width, width * 9 / 16);
}

/// MD3 container transform：整页从 [sourceRect]「长出」成全屏。
///
/// 进入 400ms emphasized-decelerate，返回 200ms emphasized-accelerate（反向播放），
/// 时长由路由的 transitionDuration / reverseTransitionDuration 控制。
class ContainerTransform extends StatelessWidget {
  const ContainerTransform({
    super.key,
    required this.animation,
    required this.sourceRect,
    required this.child,
  });

  final Animation<double> animation;
  final Rect sourceRect;
  final Widget child;

  /// MD3 emphasized-decelerate
  static const _enterCurve = Cubic(0.05, 0.7, 0.1, 1);

  /// MD3 emphasized-accelerate
  static const _exitCurve = Cubic(0.3, 0.0, 0.8, 0.15);

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: _enterCurve,
      reverseCurve: _exitCurve,
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, _) {
        final t = curved.value.clamp(0.0, 1.0);
        final screen = Offset.zero & MediaQuery.sizeOf(context);
        final rect = Rect.lerp(sourceRect, screen, t)!;
        return ClipRect(
          clipper: _RectClipper(rect),
          child: Transform.translate(
            // 页面整体下移 sourceRect.top，随进度归零
            offset: Offset(0, lerpDouble(sourceRect.top, 0, t)!),
            child: Opacity(
              // 前 40% 快速淡入，避免整页在裁剪窗口里发虚
              opacity: (t / 0.4).clamp(0.0, 1.0),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _RectClipper extends CustomClipper<Rect> {
  const _RectClipper(this.rect);

  final Rect rect;

  @override
  Rect getClip(Size size) => rect;

  @override
  bool shouldReclip(_RectClipper oldClipper) => oldClipper.rect != rect;
}
