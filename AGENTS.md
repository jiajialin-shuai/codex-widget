# Codex Battery

原生 macOS Codex 额度菜单栏与 WidgetKit 小组件。用户要求：电池圆环样式；小号同时显示周额度、五小时额度；大号显示重置时间、重置卡等；尽量低占用。

- SwiftUI / AppKit / WidgetKit / Network，无第三方运行依赖、网页视图或常驻 Codex 子进程。
- 通过本机 `codex app-server` 的 `account/rateLimits/read` 读取真实数据。用 `windowDurationMins` 识别 300/10080 分钟窗口，不能依赖 primary/secondary 顺序。
- 剩余 = 100 - usedPercent。缺字段显示“未提供”，禁止填假数据。重置卡仅展示，不调用消耗接口。
- 主程序默认每 15 分钟查询，失败退避，睡眠暂停，唤醒刷新。查询完成或超时终止自建子进程。
- 用户要求隐藏顶部图标：默认不显示菜单栏图标，设置中可开启。没有图标时仍刷新；点击 Widget 或重新打开应用可进入设置。
- WidgetKit 从仅绑定 127.0.0.1 的只读快照服务读数据，自己保留离线缓存，不启动 CLI、不读凭据。系统决定最终刷新时间。
- 用户实测 WidgetKit 两种背景写法都呈现色块，因此另提供原生 AppKit 透明桌面组件。macOS 26+ 用 `NSGlassEffectView`（通透/柔和）；旧系统用 `NSVisualEffectView`。在桌面图标层、不盖普通应用窗口，无持续动画；不能把它称作 WidgetKit 卡片。
- 缓存、构建产物、真实账号响应不得进入 Git。只存展示需要的归一化字段，不保存账号 ID、邮箱、卡 ID 或 Token。
- `scripts/build.sh` 构建；`scripts/check.sh` 检查解析、进程生命周期和实时查询；`scripts/install.sh` 安装。
- 完整 Xcode 用 `DEVELOPER_DIR` 指定，禁止全局切换开发环境。
- 设计和取舍见 `docs/DESIGN.md`。运行验收见 `docs/VERIFICATION.md`，编译通过不等于桌面小组件已验证。
- GitHub 仓库先私有，后续开源需要用户明确要求。开源前检查源码、截图与说明无本机敏感信息。
