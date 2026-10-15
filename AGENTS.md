# Codex Battery

原生 macOS Codex 额度菜单栏与 WidgetKit 小组件。用户要求：电池圆环样式；小号同时显示周额度、五小时额度；大号显示重置时间、重置卡等；尽量低占用。

- SwiftUI / AppKit / WidgetKit / Network，无第三方运行依赖、网页视图或常驻 Codex 子进程。
- 通过本机 `codex app-server` 的 `account/rateLimits/read` 读取真实数据。用 `windowDurationMins` 识别 300/10080 分钟窗口，不能依赖 primary/secondary 顺序。
- 剩余 = 100 - usedPercent。缺字段显示“未提供”，禁止填假数据。重置卡仅展示，不调用消耗接口。
- 主程序默认每 15 分钟查询，失败退避，睡眠暂停，唤醒刷新。查询完成或超时终止自建子进程。
- 用户要求隐藏顶部图标：默认不显示菜单栏图标，设置中可开启。没有图标时仍刷新；点击 Widget 或重新打开应用可进入设置。
- WidgetKit 从仅绑定 127.0.0.1 的只读快照服务读数据，自己保留离线缓存，不启动 CLI、不读凭据。系统决定最终刷新时间。
- 用户明确只要从系统组件界面添加的 WidgetKit 小组件；禁止使用独立 NSPanel、桌面浮层或自制桌面窗口替代。此前的独立桌面组件已移除。透明背景必须在真正的 WidgetKit 卡片上研究和验证。
- 安装更新时必须重启本项目的 Widget 扩展进程，避免系统继续运行旧二进制。实际数据条目移除遗留的 placeholder redaction，保留 privacy redaction。占位状态与真实条目必须分开。
- 缓存、构建产物、真实账号响应不得进入 Git。只存展示需要的归一化字段，不保存账号 ID、邮箱、卡 ID 或 Token。
- `scripts/build.sh` 构建；`scripts/check.sh` 检查解析、进程生命周期和实时查询；`scripts/install.sh` 安装。
- 完整 Xcode 用 `DEVELOPER_DIR` 指定，禁止全局切换开发环境。
- 设计和取舍见 `docs/DESIGN.md`。运行验收见 `docs/VERIFICATION.md`，编译通过不等于桌面小组件已验证。
- 用户已于 2026-10-15 授权隐私检查后开源，采用 MIT。发布源码前检查完整 Git 历史、截图、文档和提交元数据；不得发布真实缓存、账号响应、构建日志或含本机路径的二进制。用户另已授权发布安装包，使用 `scripts/package.sh` 检查并打包，明确 ad-hoc 未公证。
- 隐私边界以 `PRIVACY.md` 为准：loopback 桥拒绝网页来源但没有本机身份认证，不得宣称其他本机程序无法读取额度摘要。
