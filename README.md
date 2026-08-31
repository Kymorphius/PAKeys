# PAKeys

一个轻量的 macOS 菜单栏改键工具。目前只做一件事：

> 右 Command → 左 Command

它使用 macOS 自带的 `hidutil`，无需内核扩展或第三方驱动。程序只管理右 Command 这一项，并保留系统中已有的其他按键映射。

## 构建

需要 macOS 13 或更高版本，以及 Xcode Command Line Tools。

```bash
chmod +x build.sh
./build.sh
open dist/PAKeys.app
```

应用会出现在菜单栏。打开“启用按键映射”即可立即生效；如需重启或重新登录后自动恢复，请同时打开“登录时自动启动”。

## 卸载

先在菜单中关闭“启用按键映射”和“登录时自动启动”，退出应用，然后删除 `PAKeys.app`。
