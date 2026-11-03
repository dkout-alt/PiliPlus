import 'package:PiliPlus/common/skeleton/skeleton.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:material_ui/material_ui.dart';

class VideoCardVSkeleton extends StatelessWidget {
  const VideoCardVSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final color = ColorScheme.of(context).onInverseSurface;
    return Skeleton(
      child: Column(
        crossAxisAlignment: .start,
        children: [
          AspectRatio(
            aspectRatio: Style.aspectRatio16x9,
            child: ColoredBox(color: color),
          ),
          Expanded(
            child: Padding(
              padding: const .fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  _bar(color, height: 13),
                  _bar(color, height: 13, width: 140, top: 5),
                  const Spacer(),
                  _bar(color, height: 11, width: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
