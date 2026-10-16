# Crosshair Mac

一个 macOS 菜单栏外置准星，参考了 [liang-weixi/crosshair-tool](https://github.com/liang-weixi/crosshair-tool) 的功能设计，并使用 Swift、SwiftUI 和 AppKit 原生实现。

## 功能

- 在每台显示器的屏幕中心显示透明、鼠标穿透的置顶准星
- 标准十字、中心点十字、圆圈三种样式
- 调整线宽、长度、间隙、颜色、透明度和黑色描边
- 菜单栏快速显示/隐藏；设置自动保存
- 支持 macOS 13 或更新版本，通用版同时支持 Apple Silicon 和 Intel Mac

## 运行

需要安装 Xcode Command Line Tools。在本目录运行：

```sh
swift run
```

应用启动后会出现在菜单栏。点击准星图标打开菜单和设置。

## 打包为 `.app`

```sh
./package-app.sh
```

生成的通用版应用位于 `build/Crosshair Mac.app`，下载包位于 `build/Crosshair Mac.zip`。应用采用本机临时签名，未经过 Apple Developer ID 公证；首次打开时，macOS 可能会提示确认。

## 说明

准星窗口使用系统置顶窗口级别和全屏辅助行为。部分独占全屏游戏、受保护内容或启用了特殊反作弊限制的应用可能不允许第三方窗口叠加；这类游戏可尝试使用无边框窗口模式。
