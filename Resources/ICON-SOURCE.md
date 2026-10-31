# 应用图标来源

`WeRead.png` 使用微信读书在 Apple App Store 上的官方 1024 × 1024 图标。

- 应用：[微信读书](https://apps.apple.com/cn/app/id952059546)
- 开发者：Tencent Technology (Shenzhen) Company Limited
- [原始图像](https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/03/8e/f6/038ef6ec-c9cc-47db-a0f3-f29e4394cf8f/AppIcon-0-0-1x_U007epad-0-11-0-85-220.png/1024x1024bb.png)
- 获取日期：2026-10-31

图标权利归原权利人所有。本项目为独立阅读工具，与腾讯无隶属关系。

`scripts/make-app-icon.m` 使用 AppKit 将原始图标置于透明的 1024 × 1024 画布中，图案范围为 824 × 824，四周保留 100 像素留白，并添加圆角及轻微阴影，使启动台和 Dock 中的视觉尺寸与 macOS 原生图标一致。原始图像保持不变。

`scripts/create-icon.sh` 编译并运行此工具，再使用 macOS 自带的 `sips` 和 `iconutil` 生成各分辨率图标以及 `WeRead.icns`，本地构建和 GitHub Actions 均使用相同流程。
