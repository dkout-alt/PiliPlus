import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/image/image_save.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/video_popup_menu.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/models/home/rcmd/result.dart';
import 'package:PiliPlus/models/model_rec_video_item.dart';
import 'package:PiliPlus/models_new/video/video_detail/dimension.dart';
import 'package:PiliPlus/utils/app_scheme.dart';
import 'package:PiliPlus/utils/date_utils.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/extension/dimension_ext.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/num_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

// 视频卡片 - 垂直布局（首页推荐流单列，无卡片容器）
class VideoCardV extends StatelessWidget {
  final BaseRcmdVideoItemModel videoItem;
  final VoidCallback? onRemove;

  const VideoCardV({
    super.key,
    required this.videoItem,
    this.onRemove,
  });

  /// 文字区左右内边距（MD3 8dp 间距系统）
  static const _hPad = 16.0;

  Future<void> onPushDetail() async {
    switch (videoItem.goto) {
      case 'bangumi':
        PageUtils.viewPgc(epId: videoItem.param!);
        break;
      case 'av':
        var bvid = videoItem.bvid ?? IdUtils.av2bv(videoItem.aid!);
        var cid = videoItem.cid;
        bool isVertical = false;
        Dimension? dimension;
        if (videoItem is RcmdVideoItemAppModel) {
          if (videoItem.uri case final uri?) {
            isVertical = uri.isVerticalFromUri;
          }
        }
        if (cid == null) {
          if (await SearchHttp.ab2cWithDimension(aid: videoItem.aid, bvid: bvid)
              case final res?) {
            cid = res.cid;
            dimension = res.dimension;
          }
        }
        if (cid != null) {
          PageUtils.toVideoPage(
            aid: videoItem.aid,
            bvid: bvid,
            cid: cid,
            cover: videoItem.cover,
            title: videoItem.title,
            isVertical: isVertical,
            dimension: dimension,
          );
        }
        break;
      // 动态
      case 'picture':
        try {
          PiliScheme.routePushFromUrl(videoItem.uri!);
        } catch (err) {
          SmartDialog.showToast(err.toString());
        }
        break;
      default:
        if (videoItem.uri?.isNotEmpty == true) {
          PiliScheme.routePushFromUrl(videoItem.uri!);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    void onLongPress() => imageSaveDialog(
      title: videoItem.title,
      cover: videoItem.cover,
      bvid: videoItem.bvid,
    );
    final badges = _coverBadges();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: onPushDetail,
          onLongPress: onLongPress,
          onSecondaryTap: PlatformUtils.isMobile ? null : onLongPress,
          child: Column(
            crossAxisAlignment: .start,
            children: [
              AspectRatio(
                aspectRatio: Style.aspectRatio16x9,
                child: LayoutBuilder(
                  builder: (context, boxConstraints) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        NetworkImgLayer(
                          src: videoItem.cover,
                          width: boxConstraints.maxWidth,
                          height: boxConstraints.maxHeight,
                          borderRadius: BorderRadius.zero,
                        ),
                        if (badges.isNotEmpty)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Row(
                              spacing: 4,
                              mainAxisSize: .min,
                              children: badges,
                            ),
                          ),
                        if (videoItem.duration > 0)
                          PBadge(
                            bottom: 6,
                            right: 8,
                            size: .small,
                            type: .gray,
                            text: DurationUtils.formatDuration(
                              videoItem.duration,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              Expanded(
                child: content(context),
              ),
            ],
          ),
        ),
        // 三点按钮暂置于封面右上角，下一步改为长按唤起后移除
        if (videoItem.goto == 'av')
          Positioned(
            top: 4,
            right: 4,
            width: 29,
            height: 29,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: ColorScheme.of(context).scrim.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: VideoPopupMenu(
                iconSize: 17,
                videoItem: videoItem,
                onRemove: onRemove,
              ),
            ),
          ),
      ],
    );
  }

  /// 覆盖在封面左上角的角标（无卡片容器后不再占用文字行）
  List<Widget> _coverBadges() {
    final badges = <Widget>[];
    if (videoItem.goto == 'bangumi' && videoItem.pgcBadge != null) {
      badges.add(
        PBadge(
          text: videoItem.pgcBadge,
          isStack: false,
          size: .small,
          type: .gray,
          fontSize: 9,
        ),
      );
    }
    if (videoItem.rcmdReason != null) {
      badges.add(
        PBadge(
          text: videoItem.rcmdReason,
          isStack: false,
          size: .small,
          type: .gray,
        ),
      );
    }
    if (videoItem.goto == 'picture') {
      badges.add(
        const PBadge(
          text: '动态',
          isStack: false,
          size: .small,
          type: .gray,
          fontSize: 9,
        ),
      );
    }
    if (videoItem.isFollowed) {
      badges.add(
        const PBadge(
          text: '已关注',
          isStack: false,
          size: .small,
          type: .gray,
        ),
      );
    }
    return badges;
  }

  Widget content(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const .fromLTRB(_hPad, 12, _hPad, 8),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Expanded(
            child: Text(
              videoItem.title,
              maxLines: 2,
              overflow: .ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.4,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          Text.rich(
            TextSpan(
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              children: _byline(),
            ),
            maxLines: 1,
            overflow: .ellipsis,
          ),
        ],
      ),
    );
  }

  /// UP名 · 播放量 · 发布日期
  List<InlineSpan> _byline() {
    final spans = <InlineSpan>[
      TextSpan(text: videoItem.owner.name),
      TextSpan(text: ' · ${NumUtils.numFormat(videoItem.stat.view)}播放'),
    ];
    if (videoItem.pubdate case final pubdate?) {
      spans.add(
        TextSpan(
          text:
              ' · ${DateFormatUtils.dateFormat(pubdate, short: shortFormat, long: longFormat)}',
        ),
      );
    }
    return spans;
  }

  static final shortFormat = DateFormat('M-d');
  static final longFormat = DateFormat('yy-M-d');
}
