import 'package:PiliPlus/common/motion/container_transform.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
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
class VideoCardV extends StatefulWidget {
  final BaseRcmdVideoItemModel videoItem;
  final VoidCallback? onRemove;

  const VideoCardV({
    super.key,
    required this.videoItem,
    this.onRemove,
  });

  static final shortFormat = DateFormat('M-d');
  static final longFormat = DateFormat('yy-M-d');

  @override
  State<VideoCardV> createState() => _VideoCardVState();
}

class _VideoCardVState extends State<VideoCardV> {
  /// 文字区左右内边距（MD3 间距刻度：4/8/12/16/24）
  static const _hPad = 12.0;

  /// 隐藏的菜单锚点，长按时程序化唤起
  final _menuKey = GlobalKey<PopupMenuButtonState<dynamic>>();

  BaseRcmdVideoItemModel get videoItem => widget.videoItem;

  /// 与 /videoV 的 Hero tag 保持一致（bvid 优先，退化用 aid 换算）
  Object? get _heroId {
    final bvid = videoItem.bvid;
    if (bvid != null && bvid.isNotEmpty) return bvid;
    final aid = videoItem.aid;
    return aid == null ? null : IdUtils.av2bv(aid);
  }

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

  void _openMenu() => _menuKey.currentState?.showButtonMenu();

  @override
  Widget build(BuildContext context) {
    final badges = _coverBadges();
    return InkWell(
      onTap: onPushDetail,
      onLongPress: _openMenu,
      onSecondaryTap: PlatformUtils.isMobile ? null : _openMenu,
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
                    Hero(
                      tag: videoCoverHeroTag(_heroId),
                      flightShuttleBuilder: videoCoverShuttle,
                      child: NetworkImgLayer(
                        src: videoItem.cover,
                        width: boxConstraints.maxWidth,
                        height: boxConstraints.maxHeight,
                        borderRadius: BorderRadius.zero,
                      ),
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
                        text: DurationUtils.formatDuration(videoItem.duration),
                      ),
                    // 零视觉的菜单锚点：不可见、不拦截点击，仅提供弹出位置
                    if (videoItem.goto == 'av')
                      Positioned(
                        top: 0,
                        right: 0,
                        width: 29,
                        height: 29,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: 0,
                            child: VideoPopupMenu(
                              menuKey: _menuKey,
                              iconSize: 17,
                              videoItem: videoItem,
                              onRemove: widget.onRemove,
                            ),
                          ),
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
        mainAxisSize: .min,
        children: [
          Text(
            videoItem.title,
            maxLines: 2,
            overflow: .ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
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

  /// UP名 · 播放量 · 弹幕数 · 发布日期
  List<InlineSpan> _byline() {
    final spans = <InlineSpan>[
      TextSpan(text: videoItem.owner.name),
      TextSpan(text: ' · ${NumUtils.numFormat(videoItem.stat.view)}播放'),
    ];
    if (videoItem.stat.danmu case final danmu?) {
      spans.add(TextSpan(text: ' · ${NumUtils.numFormat(danmu)}弹幕'));
    }
    if (videoItem.pubdate case final pubdate?) {
      spans.add(
        TextSpan(
          text:
              ' · ${DateFormatUtils.dateFormat(pubdate, short: VideoCardV.shortFormat, long: VideoCardV.longFormat)}',
        ),
      );
    }
    return spans;
  }
}
