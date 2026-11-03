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

/// 包在 `/videoV` 外层：自建控制器驱动容器变换。
///
/// 不依赖路由过渡时长（GetX fork 的 `GetPage` 无法设置逐路由过渡，
/// 且 `noTransition` 下路由动画时长为 0），也不依赖 `Get.arguments`。
/// 进入 400ms / 返回 200ms 由本控制器自行控制。
class ContainerTransformPage extends StatefulWidget {
  const ContainerTransformPage({super.key, required this.child});

  final Widget child;

  @override
  State<ContainerTransformPage> createState() => _ContainerTransformPageState();
}

class _ContainerTransformPageState extends State<ContainerTransformPage>
    with SingleTickerProviderStateMixin {
  static const _enterDuration = Duration(milliseconds: 400);
  static const _exitDuration = Duration(milliseconds: 200);

  Rect? _sourceRect;
  late final AnimationController _controller;
  bool _popping = false;

  @override
  void initState() {
    super.initState();
    _sourceRect = ContainerTransformSource.pending;
    // 一次性消费，避免后续从历史/相关视频进入时误用旧矩形
    ContainerTransformSource.pending = null;
    _controller = AnimationController(
      vsync: this,
      duration: _enterDuration,
      reverseDuration: _exitDuration,
    );
    if (_sourceRect == null) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handlePop(Object? result) async {
    // 防止连按返回触发多次 pop（会连带退出首页）
    if (_popping) return;
    _popping = true;
    if (_sourceRect != null && _controller.value > 0) {
      await _controller.reverse();
    }
    if (mounted) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final sourceRect = _sourceRect;
    if (sourceRect == null) {
      return widget.child;
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handlePop(result);
      },
      child: ContainerTransform(
        animation: _controller,
        sourceRect: sourceRect,
        child: widget.child,
      ),
    );
  }
}

/// 记录本次点击的封面矩形（一次性）
abstract final class ContainerTransformSource {
  static Rect? pending;
}
