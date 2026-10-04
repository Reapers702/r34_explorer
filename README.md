# Rule34 Explorer

一个 Flutter 写的 Rule34 浏览客户端，覆盖**两个内容形态完全不同**的站点，App 内可切换：

| 站点 | 内容 | 数据获取方式 | 登录 |
|---|---|---|---|
| **rule34video.com** | 视频（影片站） | HTML 抓取 + 风控 cookie | 需要（站点有 Cloudflare / DDG 风控） |
| **rule34.xxx** | 图片（Booru 图站） | 公开 JSON 接口 | 不需要 |

首页顶部与「设置 → 数据源」都能切换站点，选择会持久化。两者内容与服务端完全独立，**各自一套页面**，只共享主题与通用组件。

---

## 一、rule34.xxx 的数据来源（重点）

**结论：不走 `r34.app`，也不走 `kurosearch.com`；直接用它们背后那条公开接口本身。**

```dart
// lib/repo/r34_xxx_repo.dart
static const String _baseUrl = 'https://rule34-api.netlify.app';
```

### 为什么不用官方 API

rule34.xxx 官方 API（`api.rule34.xxx/index.php?page=dapi...`）现在**强制要求 `user_id` + `api_key`**，
一人一 key、不可共用，没有凭据会直接返回：

```xml
<error>Missing authentication. Go to api.rule34.xxx for more information</error>
```

key 只能本人到 <https://rule34.xxx/index.php?page=account&s=options> 生成，因此不适合直接预置进客户端。

### 这条公开接口是怎么找到的

排查时用浏览器抓了 `kurosearch.com` 的实际网络请求，发现它请求的是：

```
GET https://rule34-api.netlify.app/posts?limit=20&pid=0&tags=sort:id:desc   → 200 JSON
GET https://rule34-api.netlify.app/count?tags=...                          → 200 XML
```

也就是说 kurosearch 前端 → `rule34-api.netlify.app`（`kurozenzen/kurosearch` 作者的公开托管），
它自己不是数据源。本 App 直接用了同一条接口 —— **没有经过 kurosearch 或 r34.app 的页面/前端**。

### 备选数据源（将来可能要换）

如果这条公开接口限流或下线，可考虑的替代：

| 来源 | 说明 | 备注 |
|---|---|---|
| **`rule34-api.netlify.app`** | **当前使用**。kurosearch 背后的公开聚合接口 | 无鉴权；`/posts`、`/count`、`/comments` |
| **`api.rule34.xxx`（官方）** | 官方 API，最稳 | **强制 `user_id` + `api_key`**，一人一 key；拿到后改 `_baseUrl` 即可切换 |
| [`r34.app`](https://r34.app/) | 同类的 Rule34 浏览站，自带 App | 其 [Rule-34/API](https://github.com/Rule-34/API) 文档写明「仅供 Rule 34 App 使用」、无公开文档，故未采用 |
| [`kurosearch.com`](https://kurosearch.com/) | 开源图站（[源码](https://github.com/kurozenzen/kurosearch)），无需登录 | 同上的接口来源方；站点本身可作参考实现 |
| `api-cdn.rule34.xxx` | 图片 CDN | 与接口无关，可直连 |

切换方式：改 `lib/repo/r34_xxx_repo.dart` 里的 `_baseUrl`，或按官方 API 的参数形态调整该方法。

### 用到的端点

| 端点 | 用途 | 备注 |
|---|---|---|
| `/posts?limit=&pid=&tags=` | 拉投稿 | `pid` 从 **0** 开始；返回 JSON 数组 |
| `/count?tags=` | 命中总数 | 返回 `<posts count="..." />` |
| `/comments?post_id=` | 评论 | 实测基本返回空数组，保留是为了将来换官方 API 时不用改调用方 |
| `api.rule34.xxx/autocomplete.php?q=` | **tag 联想** | **不需要鉴权**（与 `/dapi` 不同），站点自己用的就是它 |

单条投稿的字段：`preview_url` / `sample_url` / `file_url` / `width` / `height` /
`rating`（`explicit`·`questionable`·`safe`）/ `score` / `owner` / `tags`（空格分隔）/ `change`。

图片 CDN 是 `api-cdn.rule34.xxx`，可直连，不需要额外鉴权。

### tag 搜索的两个细节（容易踩）

1. **tag 内部用下划线，空格是 tag 之间的分隔符。**
   站点上的 `ada wong` 在数据里是 `ada_wong`；查询 `q=ada w` 会返回空
   （`q=ada_w` 才命中）。
   因此输入框会把用户打的空格/连字符规整为下划线
   （`R34XxxRepo.normalizeTagQuery`），所以「ada wong」这种带空格的 tag 可以直接打。

2. **已选 tag 可见 + 输入联想。**
   `lib/page/site/tag_search_bar.dart` 提供：
   * 选中/排除的 tag 以可删除 chip 列出，和站点一样一眼看清当前条件；
   * 输入时走官方 `autocomplete.php` 给候选，候选项带使用量
     （如 `ada wong (23076)`），展示时把下划线还原成空格；
   * `-tag` 表示排除，符合 booru 语法。

### 代价与将来替换

这是**第三方托管**，可能限流或下线。所以：

* `_baseUrl` 单独抽成常量：将来你拿到官方 key，**改这一行**即可切到官方 host；
* 所有失败都返回空列表 + 明确日志，**不会让页面崩**。

---

## 二、rule34video.com

* 列表/搜索/详情都是 HTML 解析（不依赖 JSON 接口）。
* 站点有 Cloudflare / DDG 风控，需要 cookie 才能访问，缺失时表现为请求失败或返回验证页。
* 登录：`GET /login/` 取 `remember_me_csrf_token`（顺带建立会话 cookie）→ 带 token POST。
  **登录名是邮箱**（页面 placeholder 即 "Please enter your email"）。
* 播放：内置 [media_kit](https://github.com/media-kit/media-kit)（libmpv 内核），
  支持清晰度切换 / 倍速 / 音量 / 全屏 / 双击快进退。
  播放地址需要带 `Referer` / `User-Agent`（站点 `get_file` 会 302 到 CDN 的
  `remote_control.php`，缺头会 403）。
* 不打算内置浏览器时，可在「设置 → Cookie 与登录」里**手动粘贴 cookie**。

---

## 三、快速开始

```powershell
flutter pub get
flutter run -d windows        # 或 -d <android device>
```

构建：

```powershell
flutter build windows --debug
flutter build apk --debug
```

### 环境要求（实测版本）

| 组件 | 版本 |
|---|---|
| Flutter | 3.44.x（本项目在 3.44.1 上验证） |
| Dart SDK | ^3.6.1 |
| Android | AGP **8.13.2** + Gradle **8.13** + KGP **2.2.20**，compileSdk 36 |
| Windows | Visual Studio 2022（C++ 桌面工作负载）+ **NuGet CLI**（WebView2 原生依赖需要） |

> ⚠️ **Android 请停留在 AGP 8.x。** AGP 9 移除了
> `getDefaultProguardFile('proguard-android.txt')`，而 `flutter_inappwebview_android`
> 仍在用它，升到 AGP 9 会在配置该插件时直接失败。

Windows 上 `flutter_inappwebview_windows` 构建时需要 NuGet CLI：

```powershell
winget install --id Microsoft.NuGet
```

---

## 四、项目结构

```
lib/
├── constant/           常量：路由、站点信息、筛选条件枚举（FilterSelection）
├── page/
│   ├── component/      可复用组件
│   │   └── common/     设计系统级通用件（状态视图/骨架屏/搜索框/筛选条/分页控制器…）
│   ├── site/           rule34.xxx 专属页面（图片站，独立一整套）
│   │   ├── r34_xxx_home_page      标签搜索 + 网格
│   │   ├── r34_xxx_detail_page    看图（sample/原图、缩放、沉浸）
│   │   └── tag_search_bar         已选 tag chip + 输入联想
│   ├── *.dart          rule34video 相关页面（首页/搜索/详情…）
│   └── settings_page   设置；cookie_settings_page  Cookie 与登录
├── player/             内置播放器（R34PlayerController 封装内核 + PlayerPage）
├── provider/           ChangeNotifier 状态（设置 / 登录 / 搜索编辑）
├── repo/
│   ├── entity/         数据模型
│   ├── cookie_store    cookie 统一管理（持久化 / 解析 / 合并）
│   ├── r34_client      统一网络入口：注入 cookie + 回写 Set-Cookie
│   ├── r34_xxx_repo    rule34.xxx 数据源（上文的公开接口）
│   └── r34_*_repo      rule34video 各数据源
├── theme/              配色 / 间距 / 全局 ThemeData
└── util/               日志、HTTP 错误映射、HTML 列表解析等
tool/
├── kill_app.ps1        Windows 编译被运行中实例锁住时用
└── fix_integrity.ps1   工程目录被打了低完整性标签时用（见「疑难排查」）
```

---

## 五、开发约定

* **不要 override 外部组件的默认行为。** 组件默认行为是经过验证的；出现异常先查环境，而不是给上游打补丁。
* 网络请求统一走 `R34Client`（自动注入/吸收 cookie），不要各自 `http.get` 并手写 header。
* 列表解析统一走 `R34VideoListParser`：单张卡片解析失败只跳过这一张，不让整页变空。
* 新增筛选条件请扩展 `FilterSelection`，首页与搜索页共用同一套模型与筛选面板。
* 播放内核只在 `R34PlayerController` 里碰；UI 不直接调用 `Player`。

---

## 六、疑难排查

### `PathAccessException ... (OS Error: 拒绝访问。, errno = 5)`

表现为 `%TEMP%` 或 `%APPDATA%` 写不进去，`flutter_cache_manager` / `media_kit` /
`shared_preferences` 一起报错，图片加载不出来。

**根因通常是工程目录被打上了 `Low Mandatory Level` 完整性标签**（多由沙箱类工具添加）。
Windows 的规则是「exe 带什么完整性标签，进程就以什么完整性运行」，低完整性写不了
`%TEMP%` / `%APPDATA%`（那两个位置只给 Medium 及以上写权限）；更麻烦的是标签**会遗传**，
每次重新编译的 exe 都自动继承，于是问题反复复现。

诊断与修复：

```powershell
# 体检 + 修复（正常时会明确报「无需处理」，可直接用于 CI 前置检查）
pwsh -File tool\fix_integrity.ps1

# 只体检，不改动
pwsh -File tool\fix_integrity.ps1 -DryRun
```

修复后建议 `flutter clean` 再编译，让产物继承修正后的目录。

### `MSB3026` / `LNK1168`：文件正由另一进程使用

Windows 不允许覆盖正在运行的 exe 及其占用的 dll。WebView2 的子进程
（`msedgewebview2`）在主进程退出后常仍持有句柄，表现为「明明关了 App 还是编不过」。

```powershell
pwsh -File tool\kill_app.ps1          # 只结束本项目的 r34_video
pwsh -File tool\kill_app.ps1 -Deep    # 连 msedgewebview2 一起（会波及 Teams/Outlook 等）
```

### 列表有内容但图片显示不出来

先跑 `tool\fix_integrity.ps1`。缓存目录不可写会连带影响图片加载。

### rule34video 请求失败 / 返回验证页

cookie 过期。到「设置 → Cookie 与登录」：

* **网页登录并自动抓取** —— 在内置浏览器里正常登录，自动保存；
* **手动粘贴 Cookie** —— 从浏览器复制 Cookie 整行；
* **测试连通性** —— 用当前 cookie 请求首页，确认是否被风控拦截。

---

## 七、依赖

| 依赖 | 用途 |
|---|---|
| `media_kit` / `media_kit_video` / `media_kit_libs_video` | 内置播放器（libmpv） |
| `cached_network_image` | 图片加载与磁盘缓存 |
| `flutter_inappwebview` | 内置浏览器登录抓 cookie |
| `provider` | 状态管理 |
| `html` | rule34video 的 HTML 解析 |
| `shared_preferences` | 设置 / cookie / 站点选择持久化 |
| `url_launcher`、`android_intent_plus` | 外部跳转兜底 |

---

## 八、免责声明

本项目仅供学习与个人使用。内容均来自第三方站点，与作者无关；
请遵守你所在地区的法律法规以及各站点的使用条款。
