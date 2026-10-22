# Sunlogin FusionFix

面向 Manjaro / Arch 上 **向日葵个人版 AweSun 16.6.0.32198** 的控制端兼容补丁。项目包含三个修复：

1. 保留[向日葵官方 Linux 包](https://sunlogin.oray.com/download/linux)的 `/usr/local/awesun` 路径，避免 AUR 重新定位程序文件后出现“识别码不存在或不在线”。
2. 为登录 WebView 固定已验证可用的 WebKitGTK 4.1 2.50.4 及其依赖，避免在测试机器的系统 WebKitGTK 2.52.6 上卡顿、崩溃。
3. 在 XWayland 会话中修正向日葵硬编码的 X11 `:0` display，并在用户选择启用时修正远控文字剪贴板的发送与接收方向。普通文字可通过 XWayland 与 Wayland 剪贴板桥接。

补丁只针对 **x86_64 / 16.6.0.32198**。`sources.lock` 对官方安装包和 Ubuntu 兼容库逐一校验 SHA-256。仓库不包含向日葵程序、Ubuntu 二进制包、账号信息或剪贴板内容。

## 安装

需要 `curl`、`ar`、`bsdtar`、`cc`、`pkg-config`、X11 开发头文件和 systemd。Manjaro / Arch 可安装 `base-devel libarchive libx11 curl`。安装脚本从[向日葵官方](https://dw.oray.com/sl/linux/awesun_16.6.0.32198_amd64.deb)和 [TUNA Ubuntu 镜像](https://mirrors.tuna.tsinghua.edu.cn/ubuntu/)下载约 170 MB 固定版本的包；已有校验通过的包可放入 `--cache-dir` 指定的目录。

```bash
git clone https://github.com/Xboxpig/sunlogin-fusionfix.git
cd sunlogin-fusionfix
sudo ./install.sh --enable-clipboard
```

安装会启动本次会话需要的向日葵 daemon，**不会启用开机自启**。安装后关闭并重新打开向日葵 GUI，再连接远端。安装脚本不会重启正在运行的远控窗口。

若暂时不需要文字剪贴板，在安装时省略 `--enable-clipboard`。已安装时可使用：

```bash
sudo sunlogin-fusionfix-clipboard on
sudo sunlogin-fusionfix-clipboard off
```

修改后重启向日葵 GUI 生效。也可在单次启动时设置 `SUNLOGIN_FUSIONFIX_CLIPBOARD_TEXT=0` 或 `1`。**本版本向日葵界面的“同步剪贴板文本”开关未可靠地传入 Linux 原生同步方向；开启 FusionFix 的文字同步后，请使用上面的命令关闭本机覆盖。**远端仍需允许剪贴板同步；补丁不修改远端授权或文件传输设置。

如果重启系统后需要再次使用控制端，可按需启动 daemon：

```bash
sudo systemctl start runsunloginclient.service
```

## 卸载

```bash
sudo ./uninstall.sh
```

卸载会恢复安装前的本机启动入口、WebKit helper 链接和 daemon 配置，然后移除本项目安装的文件。已运行的向日葵进程需重启才会切换回旧配置。

## 原理与范围

- `src/fusionfix.c` 通过 `LD_PRELOAD` 将向日葵显式打开的 X11 `:0` 映射到当前 `DISPLAY`。其他 display 请求原样转发。
- 同一 shim 只在明确启用时，把 `control_desktop_sync_clipboard_to_remote` 和 `control_desktop_sync_clipboard_from_remote` 的**文字**参数设为开启；文件参数原样转发。它不读取或记录剪贴板内容。
- WebKit 兼容库在专用目录加载，不覆盖系统的 WebKitGTK。Ubuntu 的 WebKit helper 入口需要一个 `/usr/lib/x86_64-linux-gnu/webkit2gtk-4.1` 链接；安装和卸载会备份并恢复该路径。
- 当前测试仅覆盖 KDE Wayland / XWayland、向日葵个人版 16.6.0.32198 的控制端。其他版本需要重新校验包和原生接口行为。

本仓库的脚本和 shim 按 MIT License 发布；向日葵及 Ubuntu 包遵循各自原有许可，安装时从对应发布方获取。
