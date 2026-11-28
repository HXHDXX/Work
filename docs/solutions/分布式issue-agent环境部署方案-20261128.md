# 分布式 issue-agent 环境部署方案（2026-11-28）

> 目标：在任意 worker 机（首个目标 **192.168.1.107**）部署 issue-agent＋agora 全栈，对接 HXNativeApp / TitanNavi 两项目的 Gitea issue 自动解决，与现役机（**108**）构成双机认领。
> 性质：活文档——部署实践中的修正与增补直接改本文件，文末「修订记录」追加一行。
> 事实基线：本方案全部配置面经 2026-11-27/28 会话对 108 现役部署逐项核实（两实例 config.json、HXAppPlatform `.repo/` manifest、`/opt` 实存、docker-compose 声明）。

## 一、拓扑与形态

```
192.168.1.100 (Gitea 服务器, docker)          192.168.1.108 (现役 worker 机, guangbin-Feng7000)
  ├─ API :3000  + git SSH :2222                 ├─ issue-agent 实例×2 (agora 模式, max_parallel=3)
  └─ 仓托管：app-platform-manifest + 19 项目仓    ├─ agorad (plaza) + opencode workers
                                               └─ silicon-memory / harness 全家
                        ▲ 纯轮询 + 认领协议 v2（无 webhook，Gitea 侧零配置）
192.168.1.107 (新部署 worker 机) —— 与 108 对同项目双机认领，不双吃
```

- **agora 模式**：issue-agent 实例只做认领→Router→建单→派发→交付推送；修码 worker 面交**本机** agorad（agora 模式硬依赖同机 agorad）。
- **双机认领 v2**：认领评论（`<!--claim:machine=<id>-->`）id 最小者胜、最早认领终身有效（无过期无抢占）；败方记账不重试；满槽不认领；让位＝墙上出现更早认领即取消在飞任务停推送；一台永久死机＝人删其认领评论、他机下轮扫描接管。`machine_id` 由 install.sh 生成（8 位 hex，勿手改）。
- **注意**：2026-11-19 曾裁定「同项目双开必双吃」——该判定已被认领协议 v2 落地**推翻**（README「双机部署」节＋state.py claim 字段＋双实例 machine_id 实证），双机双开为正式支持形态。

## 二、基础层（X11 底座）

| 项 | 要求 |
|---|---|
| 系统 | Ubuntu 22.04 级＋systemd 用户会话；python3 ≥3.10、git、curl |
| 存活 | `loginctl enable-linger <user>`（daemon 登出存活） |
| 权限 | sudo 可用（各 install.sh 的 apt 依赖安装需要） |
| 网络 | →Gitea（100 的 API+SSH 2222）；→模型服务出网 |
| **X11** | **Xvfb 本身就是 X11 服务器**：GUI 验证约定（`:99` 起选号虚拟屏，`/tmp/.X11-unix/X<n>` 占用递增，并行回合不共用）天然满足；`xdotool` 触控/鼠标注入（XTEST）只在 X11 有效 |
| 物理桌面（可选） | 需人观察/接管时装 Xorg 会话并在 gdm3 `custom.conf` 置 `WaylandEnable=false`（禁 Wayland）；纯 headless worker 机不需要，Xvfb 顶 |
| 触控模拟口径 | 现役约定＝`xdotool`（X 级注入）；设备级真实触控再议 evdev/uinput |

## 三、worker 运行时与 harness 层

| 组件 | 安装 |
|---|---|
| opencode CLI | **v2.4.1 对齐**＋登录（provider 凭据覆盖 zai-coding-plan：glm-5.3＋flash）；shell 解释器已由 dotfiles 管理的 opencode.json 内置 `/usr/bin/bash`（根治 shell 工具 zsh 方言坑——echo 转义污染管道等判例在案） |
| `~/.dotfiles` | clone → `bash install.sh`（apt 基础包＋虚拟屏工具链 xvfb/x11vnc/tigervnc-viewer/x11-utils/imagemagick、zsh、`AGENTS.global.md` 自动 symlink） |
| `~/.config/opencode` | opencode.json（providers/models＋mcp 节）**随 dotfiles 走**（`install_repo_link` symlink，勿手工拼装/覆写该文件）＋`agents/`＋`commands/`＋`skills/`（review-loop／req-gate／agora-dispatch-gate 等门）＋目录内 `npm install`（node_modules 插件） |
| ocr | `npm i -g @alibaba-group/open-code-review`＋LLM 连接配置，装完自检连通 |

**MCP 面**（照抄 108 的 opencode.json mcp 节）：

| MCP | 依赖 |
|---|---|
| serena | `~/serena` clone＋uv（`uvx --from ~/serena serena start…`） |
| context7 / playwright | `npx @upstash/context7-mcp@4.4.2` / `npx @playwright/mcp@0.0.83`＋浏览器二进制 |
| shell | `uvx mcp-shell-server` |
| browse | `~/.local/bin/browse`（挂真实浏览器扩展——headless worker 机按需取舍） |
| agora | `python3 ~/opencode-agora/agora_mcp.py`（随源仓走） |

**经验库定案（共享＋分工模式，2026-11-28 勘误后定稿）**：本机与 107 **共享同一经验库**——`.agent-experiences` 随 dotfiles 仓经 origin 双向同步（post-commit 即时发布＋dotfiles-sync 兜底；`git-sync-dotfiles` 保守原语：不 rebase 不 force）。分工：**本机（108）＝宿主，负责提炼**（夜间 groom Wave 0-7＋judge 夜裁判＋practice，宿主单跑）；**107 只负责收集**（任务会话 capture/recorder 面落共享库，保持 draft 态、不经 107 侧确认——「本地经验不做宿主经验」即此义：收集态不自动升宿主经验，提炼与确认归宿主）。

**cron-dispatch 与每日 groom（宿主提炼模式，既有参数）**：`0,15,30 * * * * ~/.dotfiles/bin/cron-dispatch` 两机都装，新机以 **`CRON_DISPATCH_ROLE=local`** 运行——这正是该模式**此前已定义好的参数**：role=local 由 role_filter 滤除 maintain/practice/daily-report（宿主单跑、防语义双跑），仅保留 dotfiles-sync（＝共享同步通道）。**每日 groom（02:00 maintain）只在宿主 108 跑**——提炼归本机；107 的 role_filter **维持原样，勿放行 maintain**（2026-11-28 曾误派放行单，当日取消，零落地）。

## 四、silicon-memory GPU 面（新机装载策略）

| 组件 | 说明 |
|---|---|
| 源与 venv | `~/silicon-memory` clone → `server/venv`（python3.12＋**nvidia pip 轮**：cublas＋cuda_runtime） |
| CUDA 注册 | `sudo` 写 `/etc/ld.so.conf.d/semem-nvidia-venv.conf`（指向 venv 内 nvidia lib 目录）→ `ldconfig` |
| llama-cpp-python | 须 **CUDA 编译版**（判例：CPU 结论被当日 CUDA 重编＋device=cuda＋重启推翻） |
| GPU 硬件前置 | NVIDIA GPU＋驱动；**部署前核显存**——embedder 2.0G＋distiller（Qwen3-4B Q4）约 3G |
| **装载策略（显存条件判定）** | **embedder＋distiller 必上 GPU**（device=cuda＋n_gpu_layers=-1＋`_preload_cuda_libs`＋PID 显存校验判据）；**ranker 视显存**：部署时 `nvidia-smi` 空闲显存 **≥8G → 三模型全上**（reranker 1.0G 驻留；对齐 108 实测口径：空闲 8.8G 足三模型）；**不足 → 不部署 ranker**（省 1.0G，ranker 本就 lazy 链路，缺席走 BM25＋向量混合召回）。显存连两模型（约 5~6G）都不够时先报人再定（降 CPU 属待议） |
| 服务进程 | `~/.local/bin/semantic-memory`（server venv 直跑）；108 无 systemd 单元＝会话按需拉起形态，新机部署时定自启方式（待优化项） |
| 运维判例 | grep 再深再慢也别用 OCR 单元断言判绿（OCR 空响应坑已有判例） |

## 五、agora 服务层（agora 模式硬依赖，须与 issue-agent 同机）

| 步骤 | 命令/要点 |
|---|---|
| 源仓 | `~/opencode-agora` clone（github.com/guangbin79/opencode-agora） |
| 部署 | `bash install.sh` → 载荷拷贝入本机 AGORA_HOME（如 `~/.opencode-agora-plaza`）→ systemd `agorad.service` 自启 |
| 验证 | `doctor` 200 且 models 清单含 router_model（`zai-coding-plan/glm-5.3`） |
| 升级纪律 | 载荷是**拷贝不是引用**——git pull 后必须重跑 install.sh＋重启服务才生效（快照滞后判例在案） |

## 六、issue-agent 本体（每项目一实例）

| 步骤 | 要点 |
|---|---|
| 源仓 | `~/issue-agent` clone（github.com/guangbin79/issue-agent） |
| PAT | Gitea 网页生成（`write:repository`＋`write:issue`＋`read:user`）；可与现役实例共用——**共用即共命运，吊销同停** |
| 项目接入 | 每项目仓根写 `.issue-agent.json`（identity/out_of_scope），再跑 install.sh |
| 实例参数 | HXNativeApp：`ISSUE_AGENT_SERVICE_NAME=hxnativeapp-issue-agent`＋`DEFAULT_BRANCH=MSC-26-RW033`；TitanNavi：`titannavi-issue-agent`＋`master` |
| 实例配置（照抄 108 值） | `execution_mode=agora`、`router_model=zai-coding-plan/glm-5.3`、`agora_home=~/.opencode-agora-plaza`、`max_parallel=3`（合法域 1..16）、`review_cmd=agora-review-audit` |
| verify_command（门会真跑） | HXNativeApp：`./container/build.sh check`；TitanNavi：`bash ./build_linux.sh` |
| GUI 依赖 | install.sh **已内置自动安装**五包：`xvfb xdotool imagemagick libgl1-mesa-dri libegl-mesa0`（Xvfb＋llvmpipe GL/EGL 软渲染——2026-11 决策已落地） |
| 服务端 | **v2 纯轮询＝Gitea 侧零改动**（无 webhook、不碰 `ALLOWED_HOST_LIST`） |
| 验证 | `journalctl --user -u <svc> -f` 看认领日志；某 issue 评论一句数秒内出现 claim 即全通 |

## 七、项目仓与构建栈

| 项 | 说明 |
|---|---|
| repo 工具 | `apt install repo`（launcher 2.54 级） |
| SSH 通道 | 新机部署 SSH key 到 Gitea `git@192.168.1.100:2222`＋known_hosts（host key 变化坑判例在案） |
| 全家检出 | `repo init -u ssh://git@192.168.1.100:2222/HXHDXX/app-platform-manifest.git && repo sync` → **19 仓**：HXNativeApp、HXMapWidgetNative、HXPRShell、TTSPlayer＋14 个 `lib-*`（GStreamer/HXGISServer/HXGuidance/HXNavigation/HXNmeaParser/HXPluginRuntime/HXRdssSendingQueue/HXRouteServer/HXSpatialMeasure/ZMQClient/hxprshell-app/maplibre-native/sherpa-onnx）＋test-bridge |
| 布局注意 | 子仓 `.git`＝symlink→`.repo/projects/`（google repo 布局）；`find -name .git -type d` 会漏 symlink 仓（判例在案）；git fetch/worktree/push 全链路不受影响 |
| issue-agent 钉定 | `canonical_path`＝`HXAppPlatform/HXNativeApp`（symlink `.git` 不影响 gitop）；TitanNavi＝单仓 plain clone（不在 manifest 家族） |
| `/opt/cross-library` | android/linux/windows 三系交叉库（108 实存三目录）——照抄或源同步 |
| `/opt/qt5-x86_64-gl` | Qt5 SDK 全套（bin/doc/include/lib/mkspecs） |
| Qt 6.6.3 gcc_64 | TitanNavi verify 另需（默认 `~/Qt/6.6.3/gcc_64`，`QT_DIR` 可改指 /opt） |
| Docker 引擎 | HXNativeApp verify（`container/build.sh check`）经 docker 自举 ccache＋跑 checker |
| 构建镜像 | `qt_x86_64:v1.3`＋`qt_arm64:v1.3`（`container/docker-compose.yml` 声明）——`docker save` 导出→新机 `docker load`，或源重建 |
| 传输通道 | cross-library.tar/qt5 tar 内网经 frpc 取（108 有 `frpc.service` 现成形态可照抄；新机若即源主机则免） |

## 八、部署顺序与验证链

1. **基础层** → linger/网络/（可选 Xorg 桌面）｜验证：`loginctl show-user` Linger=yes、Gitea API `curl` 版本号
2. **opencode CLI＋登录** → harness（dotfiles install→`.config/opencode` npm install→ocr 自检）｜验证：opencode 会话起得来、ocr 连通
3. **silicon-memory GPU 面** → venv＋nvidia 轮＋ldconfig＋CUDA 版 llama-cpp｜验证：embedder/distiller 进程显存占用（PID 校验判据）、ranker 确认未占 GPU
4. **agora 服务层** → install＋systemd｜验证：doctor 200 含 router_model
5. **项目仓与构建栈** → repo sync 19 仓＋/opt＋Qt＋docker load｜验证：`repo status` 干净、两 verify_command 各真跑一次绿
6. **issue-agent 两实例** → PAT＋install×2｜验证：journalctl 认领日志、issue 评论秒级 claim、双机不双吃（108 在飞时新机让位记账）
7. **收尾** → 新机 crontab 装 cron-dispatch 但置 `CRON_DISPATCH_ROLE=local`（只收集不提炼）；dotfiles 接 origin（共享同步通道）

## 九、待核／待优化清单

| 项 | 状态 |
|---|---|
| 107 GPU 型号/显存 | 待核（按四节显存判据执行：空闲 ≥8G 三模型，不足去 ranker） |
| 镜像与 /opt 的传输通道（save/load vs frpc vs 源重建） | 待定 |
| browse MCP 面取舍（headless 无真实浏览器） | 待定 |
| semantic-memory 自启方式（现役＝会话按需拉起） | 待优化 |
| manifest `default` 分支与两实例基线（MSC-26-RW033/master）对齐 | 待核（repo sync 出的分支须能 checkout 到基线） |
| F160 僵死梯子 `dispatched` 态无自动重派边（worker 冻死只能人工取消重立） | 上游改进项（2026-11-28 判例 ag-c99eb2） |

## 修订记录

- 2026-11-28 初版：方案经 2026-11-27/28 会话逐轮收敛（X11 底座／harness gate 齐备／google repo 全家／GPU 装载策略／经验库本地化／MCP 面），全部配置面对 108 现役部署核实后落档。
- 2026-11-28 修订1：silicon-memory 装载策略由固定「去 ranker」改为显存条件判定（空闲 ≥8G 三模型，不足去 ranker；连两模型都不够先报人）。
- 2026-11-28 修订2（勘误后定稿）：经验库定为**共享＋分工**——本机提炼（夜 groom/judge/practice 宿主单跑）、107 只收集（既有参数 `CRON_DISPATCH_ROLE=local` 滤除 maintain/practice/daily-report；dotfiles 接 origin 双向同步共享库；capture 保持 draft，确认与升格归宿主）。初稿曾误读为「本地隔离不接 origin＋role_filter 放行 maintain」，同日发现即勘误（放行单已 force 取消，role_filter 原样零落地）。
- 2026-11-28 修订3：harness 面 opencode.json 收编 dotfiles 管理（`8e8b8e3`：仓内 `.config/opencode/opencode.json`＋install.sh `install_repo_link`，本机已 symlink）——`shell: /usr/bin/bash` 内置其中；新机勿手工拼装/覆写该文件（会砸掉 symlink 脱离管理）。
