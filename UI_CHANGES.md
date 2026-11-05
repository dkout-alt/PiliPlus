# PiliPlus UI / 动效改造维护说明

> 本文档记录本 fork 相对于上游 `bggRGjQaUbCoE/PiliPlus` 的全部 UI 与动效改动，供后续维护与上游同步时参考。
>
> - 基线提交：`c805f0b5b`（上游 main）
> - 工作分支：`ui-polish`（`main` 保持与上游一致，仅做 fast-forward）
> - 改动范围：**仅 UI / 动效 / 构建配置**，未触碰网络、数据、播放器内核与业务逻辑

---

## 一、改动总览

| 类别 | 内容 | 可见效果 |
|---|---|---|
| 首页外观 | 单列布局、去 Card 容器、封面全宽 16:9、标题 w600、边距收紧 | YouTube 风格单列信息流 |
| 默认值 | 主页推荐流列宽上限 240 → **500dp** | 新装即单列 |
| 交互 | 三点按钮移除，改长按唤起菜单（含「保存封面」） | 卡片轮廓干净 |
| 交互 | 动态页「Live(N)」文案移除，只留折叠箭头 | 更简洁 |
| 主题 | `cardTheme` 改为 MD3 色调分层；底栏加分隔线 + 提升色调 | 卡片和底栏层次分明 |
| 动效 | **视频封面 Hero 过渡**，覆盖 16 个入口 | 封面飞入/飞回视频页 |
| 动效 | 页面过渡时长 300 → **400ms**（getx 补丁） | 不再"嗖一下" |
| 动效 | 底栏/侧栏切换 fade-through（90/210ms） | 切换柔和 |
| 细节 | 图片淡入 120 → 200ms；徽章底色 `black45` → `colorScheme.scrim` | 更柔和、符合规范 |
| 构建 | `.dev` 包名后缀 + 固定签名密钥 | 与官方版共存、可覆盖升级 |

提交历史：`git log --oneline c805f0b5b..HEAD`

---

## 二、逐项说明（改了什么 / 为什么）

### 2.1 首页单列布局

**文件**：`lib/pages/rcmd/view.dart`、`lib/common/widgets/video_card/video_card_v.dart`、`lib/common/skeleton/video_card_v.dart`、`lib/common/style.dart`

- 去掉页面级的 `Container`（原本有 12dp 水平外边距 + 圆角裁切），让封面真正贴屏幕左右边缘
- 卡片不再使用 `Card` 容器，改为 `InkWell + Column`：
  - 封面：`AspectRatio(16/9)` + `NetworkImgLayer(borderRadius: BorderRadius.zero)`
  - 文字区：标题（`bodyLarge` + w600 + 行高 1.3，最多 2 行）+ byline（`bodySmall` + `onSurfaceVariant`）
  - byline 内容：`UP名 · 播放量 · 弹幕数 · 发布日期`
- 网格间距 `Style.cardGap = 16`，文字区高度 `mainAxisExtent: scale(80)`
- 骨架屏同步改造，避免加载态与完成态布局跳变

**为什么**：原卡片为「有圆角的 Card + 16:10 封面 + 6dp 内边距」，信息层级扁平（标题与元数据同字重同颜色），与 YouTube 单列观感差距大。

**注意**：`mainAxisExtent` 是**固定值**。标题 1 行时，剩余空间会落到卡片底部，导致该行的卡片间距略大（2 行标题约 16dp，1 行标题约 33dp）。这是"固定高度网格"的固有限制，若要根治需把单列改成 `SliverList`（未做，见第五章）。

### 2.2 默认列宽 500dp

**文件**：`lib/utils/storage_pref.dart`、`lib/pages/setting/models/style_settings.dart`

```dart
static double get recommendCardWidth =>
    _setting.get(SettingBoxKey.recommendCardWidth, defaultValue: 500.0);
```

**为什么**：只有单列模式下，"无容器的全宽封面卡片"才成立；双列（240dp）下卡片失去分隔线，观感变差。

**注意**：默认值只对**从未写过该设置项**的安装生效。老用户需在「外观设置 → 列表宽度限制」手动调。

### 2.3 长按菜单替代三点按钮

**文件**：`lib/common/widgets/video_card/video_card_v.dart`、`lib/common/widgets/video_popup_menu.dart`

- `VideoCardV` 由 `StatelessWidget` 改为 `StatefulWidget`，持有一个 `GlobalKey<PopupMenuButtonState>`
- `VideoPopupMenu` 新增可选参数 `menuKey`，透传给内部的 `PopupMenuButton`
- 卡片封面右上角放一个**零视觉**锚点（`IgnorePointer + Opacity(0)`），长按卡片时调用 `showButtonMenu()`

**为什么**：三点按钮破坏卡片矩形轮廓；长按是 YouTube 等客户端的通行做法。

**代价**：`VideoPopupMenu` 的激活方式从"点按钮"变成"长按外部触发"，菜单内容与顺序**一字未改**；「保存封面」被移入菜单（原本是长按卡片的动作）。

### 2.4 主题：卡片与底栏

**文件**：`lib/utils/theme_utils.dart`、`lib/pages/main/view.dart`

`cardTheme`（MD3 色调分层，不用阴影）：

| | 浅色 | 深色 | 纯黑主题 |
|---|---|---|---|
| 容器色 | `surfaceContainerLow` | `surface` | `Colors.black` |
| 区分手段 | 色阶差一档 | `outlineVariant` 60% 描边 | `outlineVariant` 50% 描边 |
| 海拔 | `elevation: 0`，`shadowColor`/`surfaceTintColor` 均透明 | 同 | 同 |

底栏（`NavigationBar`）：

- `navigationBarTheme.backgroundColor = surfaceContainerHigh`（规范 level 2 是 `surfaceContainer`，此处**有意提升一档**以获得足够的层次）
- 顶部加 1dp `outlineVariant` 装饰性分隔线（MD3 中 `outline-variant` 的官方用途包含 dividers）
- 分隔线只作用于 MD3 底栏；悬浮底栏与旧式 `BottomNavigationBar` 保持原样

**为什么**：原 `cardTheme` 设了 `elevation: 1` 却把 `shadowColor` 涂透明，等于没有海拔；深色下还用 `onSurfaceVariant`（前景色）做 `surfaceTint`，会让卡片发灰。底栏则因为 `surfaceContainer` 与页面 `surface` 只差一档，浅色下几乎看不出分层。

### 2.5 动效：视频封面 Hero 过渡

**文件**：`lib/common/motion/container_transform.dart`（新增）、`lib/pages/video/view.dart`、以及 6 个卡片组件

见第四章「Hero 复用指南」。

### 2.6 动效：页面过渡时长

**文件**：`lib/scripts/patch.ps1`

```powershell
$oldLine = "Duration get transitionDuration => const Duration(milliseconds: 300);"
$newLine = "Duration get transitionDuration => const Duration(milliseconds: 400);"
```

**为什么**：GetX 把过渡时长**硬编码**在 `get_transition_mixin.dart`，且该 fork 的 `GetPage` 删除了所有过渡参数、`GetMaterialApp` 也没有时长参数 —— 公开 API 无法修改，只能改依赖源码。

**做法**：在 `patch.ps1` 末尾用**字符串替换**（而不是 `.patch` 文件）改写 pub 缓存里的 getx 源码：

- 不依赖行号，GetX 源码位置变动不会导致失败
- 匹配不到时只 `Write-Warning` 并保留原始 300ms，**不会让构建失败**

**注意**：该 getter 同时控制**进入与返回**，所以返回也是 400ms（MD3 规范里"退出"是 200ms）。如果要更细的控制，需要额外插入 `reverseTransitionDuration` getter（未做）。

### 2.7 动效：底栏 fade-through

**文件**：`lib/pages/main/view.dart`

```dart
// MD3 fade through：淡出 90ms / 淡入 210ms
late final AnimationController _fadeController;   // duration: 210ms, reverseDuration: 90ms, value: 1

Future<void> _switchTab(int index) async {
  if (_switching || index == _mainController.selectedIndex.value) return;
  _switching = true;
  await _fadeController.reverse();   // 旧页淡出（此时仍可见）
  _mainController.setIndex(index);   // 不可见时切页
  await _fadeController.forward();   // 新页淡入
  _switching = false;
}
```

- 内容区用 `FadeTransition(opacity: _fadeController, child: child)` 包裹
- 底栏 / 悬浮底栏 / 侧栏 Drawer / 侧栏 Rail 四处 `onDestinationSelected` 都指向 `_switchTab`
- `MainController.setIndex` **一行未改**
- 返回首页（`onPopInvoked` 里的 `setIndex(0)`）**故意保持瞬时**，避免返回手势带上延迟

**为什么**：`jumpToPage` 是瞬时切换，没有任何过渡，观感突兀。MD3 规定"顶层目的地之间"用 fade through，而不是方向性滑动。

### 2.8 细节

| 改动 | 文件 | 说明 |
|---|---|---|
| 图片淡入 120 → 200ms | `network_img_layer.dart` | 只改 `fadeInDuration`，`fadeOutDuration` 保持 120ms |
| 徽章 `Colors.black45` → `colorScheme.scrim(0.6)` | `badge.dart` | MD3 禁止硬编码颜色 |
| 动态页「Live(N)」移除 | `dynamics/widgets/up_panel.dart` | 只留折叠箭头；高度 60 → 48（MD3 最小触摸目标） |
| 弹幕数回到 byline | `video_card_v.dart` | 带 null 守卫，数据缺失时不显示 |

---

## 三、MD3 偏离记录

以下是**有意偏离** Material 3 规范的地方，均已在改造过程中确认：

| # | 偏离 | 规范要求 | 我们的做法 | 原因 |
|---|---|---|---|---|
| 1 | 底栏容器色 | Level 2 = `surfaceContainer` | `surfaceContainerHigh`（Level 3） | 浅色下 level 2 与页面几乎同色，层次不足 |
| 2 | 视频详情过渡 | 应遵循用户的「页面过渡动画」设置 | **强制**使用 Hero 容器变换 | 用户明确要求；该过渡与"卡片→播放器"的共享元素强绑定 |
| 3 | 页面过渡时长 | "同屏起止"过渡 = 500ms | 400ms | 该时长同时驱动 Hero 飞行，500ms 会让卡片展开显得拖沓 |
| 4 | 首页单列 500dp | ≥600dp 建议多列 | 单列 | 不考虑平板；单列是该视觉设计的前提 |
| 5 | 卡片文字边距 | 8dp 系统（8/16/24…） | 12dp | 12 在 MD3 间距刻度内，且是媒体列表常用值 |

**已确认不做**（避免过度改动）：

- 点按缩放反馈（MD3 用 state layer，`InkWell` 已提供）
- 骨架屏 `setState` → `AnimatedBuilder`（纯性能，视觉零变化）
- 字体层级显式化、18 个组件主题补齐（影响面过大）
- 全局 fade-through / 自研页面过渡（GetX 限制，见下）

**已知技术限制**：

- 该 GetX fork 的 `GetPage` 删除了 `transition` / `customTransition` / `transitionDuration` 等全部过渡参数，无法实现逐路由自定义过渡；设置里的过渡选项是 GetX 自绘的，不是 MD3 实现
- GetX 的 `Transition.fade` 是同步交叉淡化，缺少 MD3 的 90/210ms 错时时序，观感发灰

---

## 四、Hero 复用指南（新增页面如何接入）

### 4.1 机制概述

视频详情页（`/videoV`）顶部有一个 Hero：

```dart
// lib/pages/video/view.dart
Hero(
  tag: 'videoCover-${Get.arguments?[kHeroKeyArg] ?? Get.arguments?['bvid']}',
  child: videoPlayer(...),
)
```

只要**来源卡片的封面**用同一个 tag 包一层 Hero，点击进入视频页时就会自动飞行（前进 + 返回都由 Flutter 的 `HeroController` 驱动）。

### 4.2 情况 A：来源页面是独立路由（绝大多数情况）

直接用 `videoCoverHero()`，**id 传 bvid 即可**：

```dart
import 'package:PiliPlus/common/motion/container_transform.dart';

// 把原来的封面替换成：
videoCoverHero(
  videoItem.bvid,               // String?；为 null 时自动不启用动画
  NetworkImgLayer(
    src: videoItem.cover,
    width: maxWidth,
    height: maxHeight,
  ),
),
```

**为什么不用传别的参数**：Hero 只在"当前路由 → 目标路由"两个子树之间匹配，独立页面之间不会互相干扰。

**已接入的 12+ 个页面**（都是这个写法）：

| 组件 | 覆盖页面 |
|---|---|
| `VideoCardH` | 热门 / 用户投稿(web) / 热门系列 / 热门珍贵 / 搜索-视频 / 分区排行 / 相关视频 |
| `FavVideoCardH` | 收藏夹详情 / 排序 / 搜索 |
| `VideoCardHLater` | 稍后再看 |
| `HistoryItem` | 观看记录（id 用 `item.history.bvid ?? IdUtils.av2bv(item.history.oid!)`，与 `onPushHistory` 里的算法一致） |
| `SubVideoCardH` | 订阅详情 |
| `VideoCardV` | 首页推荐流（早期实现，直接构造 Hero） |

### 4.3 情况 B：来源页面与首页同属一个路由（如动态页）

动态页与首页都在 `MainApp` 这个路由内，两个 tab 的页面同时存活。**同一条视频可能出现两次** → 两个相同 tag 的 Hero。

Flutter 的处理：debug 模式抛异常；**release 模式取"先遍历到的那个"**，表现为封面从错误位置飞出。所以这类页面必须让 tag 唯一：

```dart
// lib/pages/dynamics/widgets/video_panel.dart
item.type == 'DYNAMIC_TYPE_AV'
    ? videoCoverHero(dynVideoHeroId(item.idStr), coverImg)   // 'dyn-<动态id>'
    : coverImg,

// lib/utils/page_utils.dart —— pushDynDetail 的 AV 分支
extraArguments: {kHeroKeyArg: dynVideoHeroId(item.idStr)},
```

详情页通过 `arguments[kHeroKeyArg]` 读取，读不到就回退到 `bvid`。

### 4.4 检查清单（新增入口时）

1. 该页面点击后是否真的走 `PageUtils.toVideoPage(...)`？**如果跳的是别处（番剧页、动态详情），Hero 不会飞**（也无害）
2. `bvid` 是否与 `toVideoPage` 传入的一致？（history 那种"用 aid 换算 bvid"的场景，两边算法必须相同）
3. 同一个列表里，同一条视频会不会出现两次？（出现的话必须像动态页那样加唯一后缀）
4. 有没有忘记 `videoCoverHero` 的降级？（id 为 null 时它直接返回原 widget，所以对音频/番剧/直播条目是零副作用的）

---

## 五、同步上游指南

### 5.1 常规流程

```powershell
git fetch upstream
git switch main && git merge --ff-only upstream/main && git push origin main
git switch ui-polish && git merge main
```

`main` 永远保持上游镜像，所有改动只存在于 `ui-polish`。

### 5.2 冲突面（按风险排序）

| 风险 | 文件 | 我们的改动量 | 处理建议 |
|---|---|---|---|
| 🔴 高 | `video_card_v.dart` | **约 200 行重写**（表现层整体替换） | 冲突时保留我们的结构；**但要检查上游是否改了 `onPushDetail()`**（cid 获取、`ab2cWithDimension` 那段）—— 有 bug 修复需手工移植 |
| 🟡 中 | `up_panel.dart` | 约 30 行（主要是删除） | 保留"只留箭头"的版本 |
| 🟡 中 | `main/view.dart` | 约 40 行（fade-through + 底栏分隔线） | 保留我们的版本 |
| 🟡 中 | `patch.ps1` | 末尾 +28 行（getx 补丁） | 保留该段 |
| 🟡 中 | `theme_utils.dart` | 约 25 行（cardTheme / navigationBarTheme） | 保留我们的版本 |
| 🟡 中 | `rcmd/view.dart` | 约 35 行 | 保留（去 Container、16:9、extent 80） |
| 🟢 低 | 其余 8 个文件 | 1–13 行 | 逐个确认即可 |
| ⚪ 无 | `lib/common/motion/container_transform.dart` | 新增文件 | 上游没有此文件，永不冲突 |

### 5.3 需要特别留意的上游变化

1. **上游若在别处新增 `VideoCardV(...)` 调用点** → 那处会用回上游样式，与首页风格不一致。搜索 `VideoCardV(` 检查。
2. **上游若升级 GetX** → 构建日志会出现 `getx transitionDuration not matched, keeping original value`，过渡时长退回 300ms，但**构建不会失败**。届时需按新的源码行重新确认替换文本。
3. **上游若调整 `NetworkImgLayer`** → 我们的 `fadeInDuration = 200ms` 默认值可能被覆盖，检查该字段。
4. **上游若改 `video/view.dart` 的播放器区域** → Hero 的包裹位置（`videoPlayer(...)` 外层那个 `SizedBox`）需要跟着调整。

### 5.4 构建相关改动

`.github/workflows/build.yml`：

- `flutter build apk` 增加 `--android-project-arg dev=1` → 包名变 `com.example.piliplus.dev`，可与官方版共存
- 固定签名密钥：`Write key` 步骤从 secrets 还原 `android/app/key.jks`，保证每次构建签名一致 → 可覆盖安装且保留登录数据。所需 secrets：

  | Secret | 说明 |
  |---|---|
  | `SIGN_KEYSTORE_BASE64` | JKS 密钥文件的 base64（必须由 `keytool -genkeypair -alias` 生成） |
  | `KEYSTORE_PASSWORD` / `KEY_PASSWORD` | 密钥库 / 密钥密码 |
  | `KEY_ALIAS` | 例：`pili` |

  还原时用 `tr -d ' \t\r\n'` 剔除粘贴带入的空白与换行，避免 `base64: invalid input`。

> 两种不可靠方案已废弃，勿再使用：
> 1. **缓存 AGP 自动生成的 debug keystore** —— 该文件并不是 AGP 实际签名所用的密钥（实测它的 SHA256 恒定，构建签名却每次不同），签名仍会变化；
> 2. **.NET `Export-PfxCertificate` 导出的 PKCS12** —— 文件里不保留 FriendlyName，Java 读到的 alias 与配置不符，报 `No key with alias`；而且 `keytool` 会因 `.jks` 后缀误按 JKS 解析该文件，连 alias 都列不出来。
>
> 结论：**签名密钥必须用 `keytool -genkeypair -alias <名字>` 显式生成（JKS），再以 base64 存进 secret 交给 CI。**

---

## 六、排错

| 症状 | 原因 | 处理 |
|---|---|---|
| 安装时提示"签名异常"/"应用未安装" | 构建签名与已装版本不同 | 首次需卸载重装；之后若仍失败，看 `Write key` 日志里 `keystore size=` 是否 ~2600 字节（只有几百字节说明密钥还原失败） |
| 构建日志出现 `getx transitionDuration not matched` | GetX 版本变更，替换文本没匹配上 | 过渡时长退回 300ms（不影响功能）；按新源码更新 `patch.ps1` 里的 `$oldLine` |
| 点视频卡片没有飞行动画 | tag 不一致：bvid 为 null、或动态页没传 `heroKey`、或目标不是 `/videoV` | 检查来源 id 与 `toVideoPage` 传入的 bvid 是否同源 |
| 封面从奇怪的位置飞出 | 同一路由内出现两个相同 tag 的 Hero | 按 4.3 加唯一后缀 |
| 视频页顶部有纯黑条 | 上游设计（顶部 `padding.top` 高度的黑色块） | 设置 →「播放页移除安全边距」开启即可 |
| 视频页封面短暂闪出黑底 + 小电视占位 | 缩略图 URL 由 `thumbnailUrl(src, quality)` 决定，`quality` 与列表卡片不一致会产生**另一个 URL**，缓存必然未命中 | 视频页封面不要传 `quality`（见 `lib/pages/video/view.dart` 中 `quality` 处的注释）。注意全局清晰度默认是 10，传 60 会覆盖成 `@60q` |
| 再次点击当前底部标签无反应 | 切换逻辑早退了 `setIndex()`，而「回顶部 / 双击刷新」挂在它的 `else` 分支里 | 同标签必须调用 `setIndex(index)`，只是跳过过渡动画 |

---

## 七、未做 / 已放弃

| 项 | 原因 |
|---|---|
| 单列改 `SliverList`（根治 1 行标题的间距偏大）、「上次看到这里」卡片缩小 | 会动列表结构 |
| 首页角标精简（推荐理由/已关注/番剧/动态） | 用户选择保留 |
| 时长徽章等宽数字 `tabularFigures` | 实际观感无差异，遵循最小改动 |
| 骨架屏动画驱动优化 | 纯性能 |
| 点按缩放反馈 | 不符合 MD3 |
| 自研页面过渡 / 全局 fade-through | GetX 删除逐路由过渡参数，无干净实现路径 |
| 字体层级显式化、组件主题补齐 | 影响面过大 |
| 非对称过渡时长（进入 400 / 退出 250） | 用户决定不做 |
| 把改动搬入 `lib/custom/` 以降低上游冲突面 | 用户选择维持现状 |

---

## 八、代码地图

```
lib/common/motion/container_transform.dart   ← 新增：Hero 共享逻辑
  ├─ videoCoverHeroTag(id)                   tag 约定 'videoCover-<id>'
  ├─ videoCoverShuttle(...)                  飞行期间始终显示源端封面
  ├─ videoCoverHero(id, child)               一行接入（id 为 null 时降级）
  ├─ kHeroKeyArg / dynVideoHeroId(...)       动态页唯一 tag 支持

lib/common/widgets/video_card/
  ├─ video_card_v.dart                      首页单列卡片（大改）
  └─ video_card_h.dart                      通用横向卡片（含 Hero）

lib/pages/main/view.dart                    fade-through + 底栏分隔线
lib/utils/theme_utils.dart                  cardTheme / navigationBarTheme
lib/scripts/patch.ps1                       getx 过渡时长补丁
```
