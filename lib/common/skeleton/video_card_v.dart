import 'package:PiliPlus/common/skeleton/skeleton.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:material_ui/material_ui.dart';

class VideoCardVSkeleton extends StatelessWidget {
  const VideoCardVSkeleton({super.key, this.skeleton = true});

  /// 上游参数：颜色预览页需要无动画的静态骨架，故传 false
  final bool skeleton;

  @override
  Widget build(BuildContext context) {
    final color = ColorScheme.of(context).onInverseSurface;
    final child = Column(
      crossAxisAlignment: .start,
      children: [
        AspectRatio(
          aspectRatio: Style.aspectRatio16x9,
          child: ColoredBox(color: color),
        ),
        Expanded(
          child: Padding(
            padding: const .fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: .start,
              mainAxisSize: .min,
              children: [
                _bar(color, height: 13),
                _bar(color, height: 13, width: 140, top: 5),
                _bar(color, height: 11, width: 100, top: 6),
              ],
            ),
          ),
        ),
      ],
    );
    // 保留上游的 skeleton 开关：false 时输出静态骨架（颜色预览页用）
    if (skeleton) return Skeleton(child: child);
    return child;
  }

  static Widget _bar(
    Color color, {
    required double height,
    double? width,
    double top = 0,
  }) => Container(
    width: width,
    height: height,
    margin: EdgeInsets.only(top: top),
    color: color,
  );
}
