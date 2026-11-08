<p align="center"><img src="assets/banner.png" alt="Revive the Touchbar" width="100%"></p>

Read this in: **English** · [Español](README.es.md) · [Português (Brasil)](README.pt-BR.md) · [Français](README.fr.md) · [हिन्दी](README.hi.md) · [简体中文](README.zh-CN.md)

# Revive the Touchbar

**RGB lighting for the MacBook Pro Touch Bar. Free and open source.**

A menu bar app that turns your Touch Bar into a living light strip: 49 animations on six shelves, new animation drops every week, and your own text and GIFs.

<p align="center"><a href="https://revivethetouchbar.com"><b>Download for Mac</b></a> &nbsp;·&nbsp; <a href="https://revivethetouchbar.com">Website</a></p>

## See it move

<p align="center"><img src="assets/hero.gif" alt="" width="720"></p>

[Watch the full demo (MP4)](assets/demo-all-effects.mp4)

## What's inside

- 49 animations: ambient light, retro, gaming, productivity, memes, and your own.
- New animations every week, delivered to the app.
- Your Text and Your GIF on the bar.
- Speed, brightness, color, and a hardware-style knob for the corner shape. Save looks as presets.

## Get started

1. Download the app from [revivethetouchbar.com](https://revivethetouchbar.com).
2. Open the DMG and drag **Revive the Touchbar** to Applications.
3. Launch it. It lives in your menu bar; open Settings to pick an animation.

## Build from source

You need Xcode or the Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/IsaacM721/revive-the-touchbar.git
cd revive-the-touchbar
./build.sh
open "build/Revive the Touchbar.app"
```

The build is universal (Apple silicon and Intel) and ad-hoc signed. The animation engine is plain Swift; `tools/effectlab/run.sh` renders and benchmarks every animation without the app.

## Requirements

- A MacBook Pro with a Touch Bar
- macOS 13 Ventura or later

## Questions

**Why isn't it on the Mac App Store?**

It shows its own Touch Bar using a system feature Apple doesn't offer through its public developer tools, so it is distributed directly. The release on the website is signed and notarized by Apple.

**Can I turn it off?**

Yes. Use the Lighting switch in the menu bar item, and your Touch Bar goes back to normal.

## Contributing

Issues and pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) first.

## License

MIT. See [LICENSE](LICENSE). Revive the Touchbar is an independent project, not affiliated with or endorsed by Apple Inc. MacBook Pro and Touch Bar are trademarks of Apple Inc.

## Help

Bugs and ideas: [open an issue](../../issues/new/choose). Security problems: see [SECURITY.md](SECURITY.md).
