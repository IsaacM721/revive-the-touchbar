<p align="center"><img src="assets/banner.png" alt="Revive the Touchbar" width="100%"></p>

阅读语言: [English](README.md) · [Español](README.es.md) · [Português (Brasil)](README.pt-BR.md) · [Français](README.fr.md) · [हिन्दी](README.hi.md) · **简体中文**

# Revive the Touchbar

**为 MacBook Pro 触控栏带来 RGB 灯光。免费且开源。**

一款菜单栏应用，把你的触控栏变成会动的灯带：六个分类共 49 种动画，每周上新动画，还能显示你自己的文字和 GIF。

<p align="center"><a href="https://revivethetouchbar.com"><b>下载 Mac 版</b></a> &nbsp;·&nbsp; <a href="https://revivethetouchbar.com">官网</a></p>

## 看它动起来

<p align="center"><img src="assets/hero.gif" alt="" width="720"></p>

[观看完整演示（MP4）](assets/demo-all-effects.mp4)

## 包含什么

- 49 种动画：氛围灯、复古、游戏、效率、梗图，以及你自己的。
- 每周上新动画，直接推送到应用。
- 在触控栏上显示你的文字和 GIF。
- **fn** 按钮可调出 F1–F12；还有隐形滑块：在灯光上左右滑动，左侧调节屏幕亮度，右侧调节音量。
- 速度、亮度、颜色，以及调节圆角形状的硬件风格旋钮。可将外观保存为预设。

## 开始使用

1. 从 [revivethetouchbar.com](https://revivethetouchbar.com) 下载应用。
2. 打开 DMG，将 **Revive the Touchbar** 拖到“应用程序”。
3. 打开它。它常驻菜单栏；打开“设置”选择动画。

## 从源码构建

需要 Xcode 或 Command Line Tools（`xcode-select --install`）。

```sh
git clone https://github.com/IsaacM721/revive-the-touchbar.git
cd revive-the-touchbar
./build.sh
open "build/Revive the Touchbar.app"
```

构建为通用版（Apple 芯片和 Intel），并使用临时签名。动画引擎是纯 Swift；`tools/effectlab/run.sh` 无需应用即可渲染并测试每种动画的性能。

## 系统要求

- 配备触控栏的 MacBook Pro
- macOS 13 Ventura 或更高版本

## 常见问题

**为什么不在 Mac App Store 上架？**

它借助一项 Apple 未在公开开发者工具中提供的系统功能来显示自己的触控栏，因此直接分发。官网上的版本已由 Apple 签名和公证。

**可以关闭吗？**

可以。在菜单栏项目中关闭“灯光”开关，触控栏就会恢复正常。

## 参与贡献

欢迎提交 issue 和 pull request。请先阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可证

MIT。参见 [LICENSE](LICENSE)。Revive the Touchbar 是独立项目，与 Apple Inc. 无关联，也未获其认可。MacBook Pro 和 Touch Bar 是 Apple Inc. 的商标。

## 帮助

问题和建议：[提交 issue](../../issues/new/choose)。安全问题：参见 [SECURITY.md](SECURITY.md)。
