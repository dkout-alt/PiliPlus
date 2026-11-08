# 更新日志

本文件记录本 fork 面向用户的版本变更。设计取舍、维护细节与上游同步说明见 [`UI_CHANGES.md`](UI_CHANGES.md)。

---

## 2026-11-07 · 修复返回时封面异常飞入

### 修复

- 修复在视频详情页下滑到封面完全不可见后返回时，封面会从屏幕外飞入视野的问题。现在这种情况改为普通页面过渡，画面不再突兀。

---

## 2026-11-04 · 视频封面过渡与底部标签交互修复

### 修复

- 修复偶发情况下，进入视频页时封面会短暂闪出加载图的问题。现在 Hero 过渡落地即可看到封面，衔接更自然。
- 修复切换页面过渡动画带来的回归：在首页 / 动态页再次点击当前底部标签时，「回到顶部 / 再次点击刷新」失效。现已恢复。
- 底部标签的行为现已与官方一致：点击当前标签，不在顶部时平滑回到顶部，已在顶部时刷新；500ms 内再次点击则强制刷新。

---

## 2026-11-04 · 双列布局适配 + 覆盖安装修复

### 一、双列布局适配

此前双列模式下卡片"没有背景 + 方角封面"，文字区与封面糊成一片；字号也沿用了单列的尺寸，在约 190dp 宽的窄列里显得过大。

#### 改动内容

| 项 | 单列（默认 500dp） | 多列（列宽上限 < 300dp） |
|---|---|---|
| 网格水平内边距 | **0**（封面贴屏幕边缘） | **12dp** |
| 列间距 | 16dp | **12dp** |
| 封面圆角 | **0（方角）** | **12dp** |
| 标题字号 | `bodyLarge` 16sp / w600 | **`bodyMedium` 14sp** / w600 |
| 副标题字号 | `bodySmall` 12sp | **`labelSmall` 11sp** |
| 文字左右内边距 | 12dp | **0**（与封面左右边缘对齐） |

判定方式：

```
网格是否加边距：Pref.recommendCardWidth < 300
封面是否圆角：  卡片实测宽度 < 280dp
```

两处独立判断，**单列路径零变化**。

#### 设计依据

1. **圆角与边距必须成对出现**：单列时封面全宽贴边，方角本身已划出边界；双列时每列仅约 190dp，缺少边距和圆角会让相邻卡片的文字区混在一起。而贴边状态下的圆角外侧是屏幕之外，视觉上等于没有圆角 —— 所以「网格加边距 + 封面加圆角」是同一决策的两半。
2. **字号按 MD3 type scale 降一档**：16sp → 14sp、12sp → 11sp 为相邻档位。窄列中 16sp 两行容纳字数过少，反而降低可读性。
3. **文字与封面左缘对齐**：双列时封面已有 12dp 网格边距，文字不再额外缩进，卡片形成紧凑整体。

> 修改设置后需重启生效（`gridDelegate` 为 `late final`）。

---

### 二、覆盖安装修复

#### 问题现象

```
adb install -r app.apk
Failure [INSTALL_FAILED_UPDATE_INCOMPATIBLE:
  Existing package com.example.piliplus.dev signatures do not match newer version]
```

vivo / OriginOS 安装器将其显示为「签名异常」。**卸载后重新安装一直正常，只有升级路径失败** —— 因为干净安装不校验签名，问题被掩盖了很久。

#### 根因

| | 官方构建 | 本仓库（修复前） |
|---|---|---|
| 签名密钥来源 | CI 中配置的 release keystore | **AGP 自动生成的 debug keystore** |
| 稳定性 | 固定 | 临时 runner 每次重建 → **每次不同** |

本仓库未配置签名 secrets，`build.gradle.kts` 的 `signingConfig = config ?: signingConfigs["debug"]` 因此退化为 debug 签名。**debug keystore 在 CI 上天生不稳定。**

#### 最终方案

1. 用 `keytool -genkeypair -alias pili` 生成 **JKS**（alias 由参数直接指定）
2. 转 base64 存入仓库 secret `SIGN_KEYSTORE_BASE64`
3. `Write key` 步骤还原密钥：

```bash
printf '%s' "$SIGN_KEYSTORE_BASE64" | tr -d ' \t\r\n' | base64 -d > android/app/key.jks
echo storeFile='key.jks' >> android/key.properties
echo keyAlias='pili' >> android/key.properties
echo "keystore size=$(stat -c%s android/app/key.jks) bytes"
```

关键细节：

- `tr -d ' \t\r\n'` 清洗粘贴带入的空白与换行（此前 `base64: invalid input` 即由此引发）
- `keystore size` 用于自检：正常约 2600 字节，只有几百字节说明密钥还原失败

#### 所需 Secrets

| Secret | 说明 |
|---|---|
| `SIGN_KEYSTORE_BASE64` | JKS 文件的 base64 |
| `KEYSTORE_PASSWORD` / `KEY_PASSWORD` | 密钥库 / 密钥密码 |
| `KEY_ALIAS` | `pili` |

#### 使用说明

- **本次需要卸载一次**（换成了全新密钥，与旧包签名不同）
- 从下一版起可直接覆盖安装，**登录状态、设置、本地数据全部保留**
- 包名仍为 `com.example.piliplus.dev`，与官方版互不影响

#### 已排除的错误方向（勿再尝试）

| 尝试 | 失败原因 |
|---|---|
| 缓存整个 `~/.android` 目录 | 只抓到 367 字节，keystore 未被包含 |
| 缓存单个 `~/.android/debug.keystore` + keytool 生成 | 该文件 SHA256 恒定，但构建签名仍每次不同 —— 它并非 AGP 实际签名所用 |
| .NET `Export-PfxCertificate` 导出 PKCS12 | 不保留 FriendlyName → Java 读到错误 alias（`No key with alias`）；且 `keytool` 因 `.jks` 后缀误按 JKS 解析，连 alias 都列不出 |
| 把 keystore 提交进仓库 | 私钥进入公开仓库，风险不可接受 |

---

### 三、涉及文件

| 文件 | 改动 |
|---|---|
| `lib/pages/rcmd/view.dart` | 多列判据、网格边距、列间距 |
| `lib/common/widgets/video_card/video_card_v.dart` | 封面圆角、字号降档、文字对齐 |
| `.github/workflows/build.yml` | `Write key` 容错解码 + 大小自检；`--android-project-arg dev=1` |

`build.yml` 相对上游最终仅差 **2 处**（16 增 / 7 删）：`Write key` 的实现、以及 `dev=1` 那一行。
