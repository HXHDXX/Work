# Qt 5.14.2 开发环境 备份与一键部署包（飞腾 ARM64 / 麒麟 V10 SP1）

> 本包 = `install_qt_env.sh` + `qt_backup.tar.gz`（174M）+ `debs/`（89 个,72M）
> 作用：在**全新同型号设备**上免编译恢复整套 Qt 开发环境（原环境源码编译耗时约 4 小时）

## 1. 备份内容清单

### qt_backup.tar.gz（预编译成品 + 源码）

| 内容 | 说明 |
|---|---|
| `/opt/Qt5.14.2`（157M） | 源码编译的 Qt 5.14.2（release），**内置两个自制插件**：`sqldrivers/libqsqldm.so`（达梦 QDM 驱动）、`platforminputcontexts/libfcitxplatforminputcontextplugin.so`（fcitx 中文输入法，针对 5.14.2 编译） |
| `/home/kylin/qt5`（589M→压缩） | 10 个模块源码树（qtbase/declarative/svg/tools/x11extras/translations/serialport/websockets/imageformats/charts），增量补模块时使用；注意各模块下带空 `.git` 目录（syncqt 检测用，勿删） |
| `/home/kylin/fcitx-qt5` | fcitx-qt5 1.2.7 插件源码（构建方法见本文 §4） |
| `/etc/profile.d/qt5142.sh` | PATH 注入（打包时位于归档 /tmp 下，脚本自动就位） |
| `/home/kylin/.config/QtProject/qtversion.xml` | QtCreator 的 Qt 版本注册（首启自动生成 Kit） |

### debs/（89 个离线包，2026-11-16 起按 GFB 基线换血 26 个）

> 版本锚定 V10-GFB-020 设备运行时（gf0/gf03/gf1.5 后缀）；旧基线（非 gf）包在 GFB 设备上严格依赖必失配，勿回退。详见 dm8/INSTALL.md「GFB 基线换血」条。

- QtCreator 4.11.0-3kylin6k0.4gf1.0（含 qtcreator-data、qbs 等依赖）
- Qt 编译依赖全套（libxcb*-dev / xkbcommon / icu / openssl / mesa 等）——新设备虽不必重编 Qt，保留它们以便现场重编任何组件
- gdb 9.2、cmake 3.16.3、extra-cmake-modules 5.68（fcitx-qt5 构建用）

> ⚠️ 2026-11-19 基线判例：镜像换血（gf0.2→gf0.4）时 dev 包严格依赖失配——脚本已加 dry-run 预检与 iU 残留即停；正解是 apt 隧道装当前基线版本（`206/dm8/apt-tunnel.sh on`），kit debs 仅兜底。

## 2. 部署方法（新设备）

```bash
# 新机若 KySec enabled（2503-update1 镜像默认）——先 ssh 内联关闭，否则 kit 脚本本身被拦（RC=126）：
sudo setstatus disable && sudo security-switch --set custom --list ""   # 以 getstatus 终态 disabled 为准（重启保持）
# 整个 qt-env-deploy 目录拷到设备后：
sudo bash install_qt_env.sh /path/to/qt-env-deploy

# 强制用备份包覆盖恢复现有 /opt/Qt5.14.2：
sudo env FORCE_UNTAR=1 bash install_qt_env.sh /path/to/qt-env-deploy
```

脚本幂等（Qt 已在则跳解包、deb 已装可重跑）；阶段：预检 → deb 安装 → 解包恢复 →
组件验证（qmake/QtC/两插件/PATH/Kit注册）→ 达梦联动检查（有 /dm8 则自动配 DPI 寻址，
无则提示先跑达梦部署包）→ 防休眠/防锁屏 → stage 6 完成形态终验（qmake 5.14.2 / dpkg --audit /
防休眠落位 dconf 锁+systemd mask 逐项只读复核，硬项任一不满足即报错退出；qtcreator 未装、
libqsqldm.so 缺失为软项仅 warn，2026-11-20 起）。

## 3. 前提与边界

- **仅限 arm64**（aarch64）：预编译库与 deb 均为 arm64，x86 设备不可用
- 假设设备默认用户 `kylin`（源码树/QtC 配置归档按此路径恢复；其他用户名需手工 mv + chown）
- 需要桌面环境（UKUI/X11）才能运行 QtCreator；纯命令行只有 qmake 编译能力
- QDM 驱动依赖达梦：先部署 DM8（`install_dm8_qt.sh`），或恢复本包后装 DM8 再跑一次本脚本做联动
- fcitx 输入法插件要求系统跑 **fcitx4**（麒麟默认）；若目标机为 ibus，输入法走 ibus 内置插件
- 防休眠/防锁屏固化：部署末段以 dconf 系统策略库锁死屏保/锁屏/关屏/睡眠 14 键（判例 2026-11-19：ukui-screensaver-backend 会被 ukui-session 拉活并回写 gsettings，普通 gsettings/dbus-launch 写入 25 分钟内被覆盖复现锁屏）＋ systemd mask 睡眠四 target＋logind 合盖/空闲 ignore；策略级锁死后手动锁屏亦失效——无人值守车机形态预期

## 4. 常用后续操作

```bash
# 增量补一个 Qt 模块（如 qtserialbus）：
cd /home/kylin/qt5 && git clone --depth 1 -b v5.14.2 https://github.com/qt/qtserialbus.git
mkdir qtserialbus/build && cd qtserialbus/build
/opt/Qt5.14.2/bin/qmake .. && make -j8 && sudo make install

# 重编 fcitx 输入法插件（需 cmake+ECM，debs 里已含）：
cd /home/kylin/fcitx-qt5 && mkdir -p build && cd build
cmake -DCMAKE_PREFIX_PATH=/opt/Qt5.14.2 \
      -DCMAKE_MODULE_PATH="/usr/share/ECM/modules;/home/kylin/fcitx-qt5/cmake" \
      -DCMAKE_INSTALL_PREFIX=/opt/Qt5.14.2 -DENABLE_LIBRARY=OFF -DENABLE_QT6=OFF ..
make -j8 && sudo make install    # 产物进 /opt/Qt5.14.2/plugins/platforminputcontexts/

# 达梦 QDM 驱动若需重编：见 dm8 部署包 INSTALL.md 第二节
```

## 5. 原设备组件全景（对照速查）

| 组件 | 版本 | 来源 |
|---|---|---|
| Qt SDK | 5.14.2（10模块） | 源码编译（GitHub v5.14.2 标签） |
| QDM 达梦驱动 | qt_src 1.2.7 | 源码编译，装于 /opt/Qt5.14.2/plugins/sqldrivers |
| fcitx 输入法插件 | fcitx-qt5 1.2.7 | 源码编译，同上 platforminputcontexts |
| QtCreator | 4.11.0 | 麒麟 deb |
| gdb / cmake / ECM | 9.2 / 3.16.3 / 5.68 | 麒麟 deb |
| DM8 | 20260324 FTarm | ISO 静默安装（配套 install_dm8_qt.sh） |
