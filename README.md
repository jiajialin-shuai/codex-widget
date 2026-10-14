# Codex Battery · Codex 电池

原生 macOS 菜单栏工具和桌面小组件，像看键盘电量一样看 Codex 剩余额度。

- 小号：周额度与五小时额度，双圆环、剩余百分比。
- 中号：双圆环和重置日期。
- 大号：额度、重置时间、重置卡数量/最近到期、积分余额和订阅方案。
- SwiftUI + WidgetKit，无第三方运行依赖。
- 默认隐藏菜单栏图标；点击小组件或重新打开应用进入设置，也可开启图标。
- 默认每 15 分钟查询，可改为 30 / 60 分钟；睡眠暂停、失败退避。
- 每次查询启动短命 Codex app-server，查询完退出，空闲不常驻 CLI。
- 小组件只读取归一化展示数据，不读取 Token 或浏览器 Cookie。

## 本地构建与安装

运行需要 macOS 14+。构建使用完整 Xcode 27（本机已验证，包含 macOS 27 SDK）、[XcodeGen](https://github.com/yonaskolb/XcodeGen)，以及已使用 ChatGPT 账号登录的 Codex CLI（或桌面应用内的 Codex 可执行程序）。仅 API Key 登录不一定提供订阅额度。

```bash
brew install xcodegen
./scripts/check.sh           # 离线边界和进程清理检查
./scripts/check.sh --live    # 使用本机登录实时验证，不写账号响应
./scripts/build.sh
./scripts/install.sh        # 默认装到 ~/Applications
./scripts/check-widget.sh   # 应用运行后，验证 Widget 沙盒读取与缓存
```

指定 Xcode：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/build.sh
```

打开应用后，右键桌面 → **编辑小组件** → 搜索 **Codex** → 选择小/中/大号。保持后台程序运行，以便刷新。点击小组件打开真实数据预览和设置，并更新额度；在应用程序中再次打开也会显示设置窗口。

仅提供从系统小组件界面添加的 WidgetKit 卡片，不创建独立桌面浮层。透明背景适配的研究和已确认限制见 [原生组件透明效果研究](docs/WIDGET_BACKGROUND_RESEARCH.md)。

本机构建使用 ad-hoc 签名，尚未提供经过 Developer ID 签名和公证的公开安装包。

## 数据的含义

圆环与百分比表示**剩余**，不是已用。使用 `windowDurationMins` 分辨五小时/每周窗口，不依赖响应字段位置。缺失数据显示“—”或“未提供”，不会用 0 或假数据代替。

到达重置时刻或获取失败后，旧数据标成缓存。小组件更新由 WidgetKit 调度，15 分钟是刷新请求间隔，不保证实时更新。重置卡只查看，不会使用或消耗。

加载占位状态与真实数据条目分开：真实条目不继承加载遮罩，保留系统隐私遮罩。更新安装会重启本项目扩展进程，避免继续运行旧二进制；不会删除桌面上的组件或用户的布局。

菜单栏程序通过本地 `codex app-server` 调用 `account/rateLimits/read`。它只保存百分比、日期、方案、积分余额、重置卡数量和到期时间，不保存账号 ID、邮箱、卡 ID 或认证信息。Codex 自己管理登录和 Token 刷新。

Widget 扩展通过只监听 `127.0.0.1:49763` 的只读服务读取快照；没有修改接口。此设计无需付费开发者账号或 App Group 配置。主程序退出后小组件保留离线副本，并标记缓存数据。

## 项目文件

- `Sources/Shared`：数据模型、缓存、电池 UI。
- `Sources/App`：菜单栏、设置、CLI 查询与只读快照服务。
- `Sources/Widget`：WidgetKit 时间线。
- `Tests`：解析、缺字段、额度池、过期、缓存往返、超时进程回收检查。
- [设计取舍](docs/DESIGN.md)、[验收记录](docs/VERIFICATION.md)。

本项目独立开发，非 OpenAI 官方产品。参考 [CodexBar](https://github.com/steipete/CodexBar) 和 [Codex Usage Bar](https://github.com/CMMUU/codex-usage-bar) 的信息展示与本地 RPC 思路，实现未复制其代码。

当前仓库私有；公开发布前继续核验桌面小组件体验、签名、公证和安装包。
