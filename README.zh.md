# DagaDyn

[English](README.md) · [Italiano](README.it.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt.md) · [Nederlands](README.nl.md) · [Svenska](README.sv.md) · [Polski](README.pl.md) · [Čeština](README.cs.md) · [Русский](README.ru.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · **中文**

一个让物体动起来的 SketchUp 扩展程序。组、组件或剖切面的每个属性，都会在你选定的时间内，沿你自己画的曲线，从一个状态变为另一个状态，你能在场景中看到这一过程。打开的门、上升的电梯、点亮的灯、穿过建筑的剖切。

⬇ **下载**：[最新版本](https://github.com/Dagadam/dagadyn/releases/latest)（所有版本：[Releases](https://github.com/Dagadam/dagadyn/releases)）

## 功能

- **属性**：位移（相对物体当前位置）、位置、旋转、尺寸（宽度、深度、高度）、缩放、颜色、不透明度、可见性和标记。剖切面可以移动，也可以开启和关闭。
- **状态与曲线**：每个属性都有起始状态、结束状态和时长；更多状态组成一个序列。每次过渡都沿一条曲线进行：线性、加速、减速、越过回弹、弹跳、弹性、阶梯，或者在曲线编辑器中拖动各点画出你自己的曲线。
- **时间轴**：播放、暂停、停止，以及一条可查看任意时刻的滑条。播放一次、循环或往返，速度随你设定。
- **开始方式**：随时间轴开始，在另一个物体结束后开始（再加等待），或在**使用时**开始：用*使用*工具单击。可以每次都从头开始，也可以先前进、下次再后退（门、抽屉）。
- **项目不会改变**：动画移动物体，但不改动模型。*停止*让一切复位，文件始终保存静止状态；*保留*让物体保持现在的样子（Ctrl+Z 可撤销）。
- **保存在物体内部**：动画随 `.skp` 文件保存，并随物体一起复制。选中多个物体时，更改应用于全部，位置和尺寸按各自情况调整。
- **视图中的轨迹**：移动物体的路线，每个状态一个点（SketchUp 2023 及以上）。
- **编辑时预览**：修改某个状态的值时，物体会显示为该状态。
- **配合 [DagaWASD](https://github.com/Dagadam/dagawasd)**，在行走、探索、播放路线和导出视频时物体也会运动（按视频时间逐帧进行）。移动平台会带着你走，使用键可以启动“使用时”开始的物体。
- 面板支持 36 种语言，设置、主题和外观与 DagaWASD 相同。
- **无障碍**：见 [ACCESSIBILITY.md](.github/ACCESSIBILITY.md)。

系统要求：SketchUp 2023 或更高版本。在 Windows 上开发和测试；尚未在 Mac 上测试。

## 使用方法

1. *扩展程序 › DagaDyn › 动画面板…*（或工具栏）。
2. 选择一个组、组件或剖切面。在*动画 › 物体*中选择要添加动画的属性，然后按*添加*。
3. 填写起始状态和结束状态（*⌖ 当前*取物体现在的值）、时长，并选择一条曲线。单击小曲线可以自己画。
4. 按 **▶**（或在面板中按空格）。**⏹** 让一切复位。

对于“使用时”开始的物体，选择*使用*工具（工具栏或菜单），然后在模型中单击该物体；按 Esc 退出工具。

## 安装

从[最新版本](https://github.com/Dagadam/dagadyn/releases/latest)（*Assets* 下）下载 **`dagadyn-<版本>.rbz`**，然后通过*扩展程序 › 扩展程序管理器 › 安装扩展程序*安装。

设置保存在 `%APPDATA%\DagaDyn\settings.json` 中，更新不会清除它们。动画保存在模型中，而不是扩展程序中。

## 开发

代码、注释和更新日志使用意大利语；扩展程序的内部结构见 [SVILUPPO.md](SVILUPPO.md)。

- `installa.bat` 会把源代码复制到找到的每个 SketchUp 的 Plugins 文件夹。
- `tools\run_tests.bat` 运行测试（使用模拟 SketchUp 的 Ruby；曲线测试还需要 Node.js）。
- `ruby tools\crea_rbz.rb` 在 `dist\` 中生成安装包。
- 版本号只在 `dagadyn.rb`（`VERSION`）中；每个版本在 `CHANGELOG.md` 中都有自己的章节。
- 本 README 有多种语言（`README.md` 为英文，`README.it.md`、`.es`、`.fr`、`.de`、`.pt`、`.nl`、`.sv`、`.pl`、`.cs`、`.ru`、`.ja`、`.ko`、`.zh`）：修改需同步到所有版本。

欢迎贡献：见 [CONTRIBUTING.md](.github/CONTRIBUTING.md)。

## 联系

问题和想法最好提交为 [issue](https://github.com/Dagadam/dagadyn/issues)，方便其他人查看和跟进；安全问题请按照[安全政策](.github/SECURITY.md)报告。也可以发邮件到 [DagaWASD@icloud.com](mailto:DagaWASD@icloud.com)。

如果 DagaDyn 对你有帮助，可以在 [Ko-fi](https://ko-fi.com/dagadam) 上支持它的开发。

## 许可证

[MIT](LICENSE) © 2026 Dagadam。你可以自由使用、修改和再发布代码，包括商业用途，但每份副本都必须保留版权声明和许可证文本。
