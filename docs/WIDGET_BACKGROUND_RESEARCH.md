# 原生 WidgetKit 透明背景研究

核验日期：2026-10-14。目标只限于从系统“编辑小组件”界面添加的 WidgetKit 卡片；禁止独立窗口替代，禁止截图壁纸伪装透明。

## 已确认事实

1. 用户截图左侧是系统键盘电池组件：壁纸纹理能从背景透出、圆环保留绿色。右侧 Codex 卡片的文字和图标被绘制成灰色占位块。透明问题与占位问题必须分开排查。
2. 本机扩展日志确认 `account` 快照请求 HTTP 200、时间线生成 success，缓存存在；因此不是没有额度数据。
3. 2026-10-14 19:21 后排查时，扩展进程仍是 18:39:34 启动的旧进程。此前安装只重启主程序，替换文件不代表扩展已加载新代码。安装脚本现明确重启本项目扩展。
4. 重新安装后的实际扩展输出 `placeholder=false hasData=true redaction=0`，归档生成了 `fullColor` 和 `accented` 两种模式。这说明数据和正常视图条目已进入系统渲染链路，不等于已获得最终桌面视觉验收。

## 官方文档能支持什么

- [Apple：Displaying the right widget background](https://developer.apple.com/documentation/widgetkit/displaying-the-right-widget-background)：把背景放入 `containerBackground`，允许系统在相应环境移除或以半透明方式呈现。
- [Apple：Optimizing your widget for accented rendering mode and Liquid Glass](https://developer.apple.com/documentation/widgetkit/optimizing-your-widget-for-accented-rendering-mode-and-liquid-glass)：用户选择 Clear/Tinted 外观后，系统按 accented 模式渲染并用主题玻璃效果替换背景。需要按渲染模式适配内容。
- [Apple WWDC26：WidgetKit foundations](https://developer.apple.com/videos/play/wwdc2026/277/)，约 5:06、17:15：玻璃背景替换由系统自定义外观驱动；视图归档后由系统在相应时刻显示，不是主程序的实时窗口。
- [Apple：NSWidgetBackgroundColorName](https://developer.apple.com/documentation/bundleresources/information-property-list/nswidgetbackgroundcolorname)：该键控制配置界面的背景色，不能据此宣称它是桌面透明度开关。本机电池组件的同名颜色资源是 systemGreenColor，alpha=1，也不能由这个资源推断其实际玻璃实现。

## 当前实现与边界

Widget 使用可移除 `containerBackground { Color.clear }`，内容不额外填充不透明底色。主程序内的材质预览不作为 WidgetKit 透明效果证据；此前试用 Material 未达到用户期望，因此不重复叠加或把独立 NSGlassEffectView 当作组件方案。

公开文档确认的玻璃路径是系统 Clear/Tinted 外观。但目前没有找到、也没有在本机验证：保持其他图标与小组件外观不变，仅将这个第三方 Widget 强制变成截图中系统电池的背景。不能把“尚未找到公开接口”扩大成“所有第三方组件永远不支持”。

系统全局外观会影响其他图标/组件，本次没有修改。后续应只在用户明确同意改变该设置时验证 Clear 外观，并单独确认绿色圆环和文字的适配。

## 本次显示修复

真实条目显式移除遗留的 `.placeholder` redaction，真实占位条目保持原样；隐私 redaction 不移除。诊断日志仅记录状态布尔值、模式与遮罩标志，不记录额度值、账号 ID 或认证信息。不能用强制所有条目 `unredacted()` 伪造加载成功。
