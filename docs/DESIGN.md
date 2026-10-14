# Codex Battery 设计

## 产品

在桌面一眼看清两种 Codex 剩余额度。参考苹果“电池”小组件的设备圆环：灰色完整轨道、绿色剩余弧线、中央 SF Symbol、环下百分比和标签。五小时用 `clock`，每周用 `calendar`，不用设备图标暗示真实键盘电量。

- 小号：两个圆环，周额度 / 五小时，两项百分比；无重复标题、无图表。
- 中号：两个更大圆环，加各自重置日期。
- 大号：双环、两种重置时间、可用重置卡、最近到期、订阅方案、更新时间。
- 菜单栏：默认隐藏。设置开关可显示简洁电池符号，点击打开当前数据、刷新与设置。没有 Dock 图标；从应用程序重新打开或点击 Widget 进入设置。
- 设置窗口：真实数据和三种尺寸预览、15/30/60 分钟刷新、开机启动。
- 使用系统字体和语义前景颜色，低于等于 20% 用橙色、低于等于 10% 用红色；同时保留数字，不只依赖颜色。无持续动画。
- WidgetKit 背景留给系统；用户实测 `Color.clear` 与 `ultraThinMaterial` 都没有达到想要的半透明效果。保留 `Color.clear` 以适应系统渲染模式，不宣称全彩模式下能强制透明。
- 仅支持从系统小组件界面添加的 WidgetKit 卡片。独立 NSPanel/桌面面板已按用户要求移除，不用自制窗口替代组件。
- 应用内预览卡片也使用 `.ultraThinMaterial`；窗口背景使用标准 `NSVisualEffectView` 的 `.windowBackground` 材质，不用不透明卡片填充。关闭窗口后释放视图，材质不在后台常驻。

资料：[WidgetKit 背景](https://developer.apple.com/documentation/widgetkit/displaying-the-right-widget-background)、[渲染模式与玻璃](https://developer.apple.com/documentation/widgetkit/optimizing-your-widget-for-accented-rendering-mode-and-liquid-glass)。具体结论见 [透明效果研究](WIDGET_BACKGROUND_RESEARCH.md)；不从设置预览推断真实桌面效果。

## 数据与资源

本机 CLI 的 JSON-RPC `initialize` → `initialized` → `account/rateLimits/read`。核对资料：

- [OpenAI App Server](https://learn.chatgpt.com/docs/app-server)
- [CodexBar](https://github.com/steipete/CodexBar)（信息层级参考）
- [Codex Usage Bar](https://github.com/CMMUU/codex-usage-bar)（本地 RPC 架构参考）
- [Apple Widgets HIG](https://developer.apple.com/design/human-interface-guidelines/widgets)

实现自行编写，不复制参考项目代码。

按窗口时长找额度。支持 `rateLimitsByLimitId.codex`，避免选到其他额度池。解析 `rateLimitResetCredits.availableCount` 与可用卡 `expiresAt`；只显示，不消耗。购买积分余额与重置卡分别命名。

查询每次启动一个短命 app-server，超时 25 秒并回收。空闲无 CLI、无磁盘扫描、无 JSONL 历史分析、无每秒刷新。菜单栏程序是唯一查询方；小组件按系统时间线读取缓存。

无需付费开发者账号的本机构建使用 ad-hoc 签名。为避免 App Group 授权问题，主程序开一个仅绑定 127.0.0.1 的只读快照端口（49763），只返回百分比、日期、方案、积分余额、重置卡数量/到期时间等归一化字段；不暴露 Token、账号 ID、邮箱、卡 ID，也无修改接口。Widget 保存副本；主程序退出时标记缓存离线。

默认查询 15 分钟（可选 30/60）；失败按 30/60 分钟退避；菜单打开或手动刷新可更新，重复调用合并；短时间打开菜单不反复查询。睡眠暂停，唤醒刷新。重置时可提前一次查询。WidgetKit 保留最终调度权，不承诺实时额度。

## 验收

必须分别验证：解析边界、实时 RPC、无残留子进程、Release 构建与签名、菜单 UI、三种尺寸真实渲染、桌面小组件注册和数据读取、空闲内存/CPU。无证据的项标为待验收。
