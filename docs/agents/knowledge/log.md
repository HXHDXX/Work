# Knowledge Log

> Append-only chronological record of wiki operations.
> Parse: `grep "^## \[" log.md | tail -5` shows last 5 entries.

## Log

## [2026-08-07] ingest | agent-guidelines
- 对齐 HXProjectTemplate 56ac45d：移除 harness-reflection 系统，引入 agent-experience skill（跨项目经验记忆）
- Supersedes 2026-07-20 harness 反思决策
- Types: Decision

## [2026-07-20] ingest | agent-guidelines
- 新增 harness 反思与复利机制：AGENTS.md 新节 + core/harness-reflection.md 详情（适配 Work 文档项目，将"构建验证链"维度改为"文档验证链"）+ index.md 目录树更新 + writing-guide.md 维护规则
- 业务知识进 project-compound，元层提案进 harness-reflection.md，兑现后 ingest 入 agent-guidelines Decisions
- Cross-ref: [[infra]]
- Types: Decision

## [2026-06-08] ingest | infra
- AGENTS.md 完善：依赖路径恢复（`./cross-library-examples/`、`./libs/`）、Worktree 防冲突命名规范（物理拓扑对齐+时间戳+Hash）、新增跨项目静态检索规则、编译验证命令修正、Context-Mode 格式统一
- infra.md 决策记录：依赖路径恢复与 Worktree 命名规范扩展 (2026-06-08)，Supersedes 05-26 精简决策
- 新增策略：跨项目知识借鉴策略
- Types: Decision, Strategy, Module Info

## [2026-05-28] lint | 全局
- AGENTS.md：修复已删除目录引用（`./cross-library-examples/` → `/opt/cross-library/`、`./libs/` → CMake 结构组织、新增构建脚本位置说明）
- context-strategy.md：同步 `ctx_batch_execute` 工具路由和沙盒断言
- principles.md：同步 AGENTS.md 措辞（"验证贯穿始终"合并两条、"先理解再行动"拆分静态/动态、Trivial 豁免补充禁止连续拆分和构建验证）
- infra.md：路线图从 Phase 4-8 更新到 Phase 1-24（与 plan.md 同步）；旧路线图决策标记 Superseded
- Types: Module Info, Decision

## [2026-05-26] lint | infra, cpp-env, docs
- AGENTS.md 精简：移除"库"和"验证" section → 下沉至 structure.md
- 删除 container/, cross-library-examples/, libs/ 占位目录（无实际内容）
- principles.md: 移除 `./container/build.sh` 引用
- cpp-env.md: 静态分析引用改为待定描述
- infra.md: 旧决策标记 Superseded 并压缩；Directory Audit 压缩为一行摘要
- structure.md: 目录树/依赖表/布局检查同步清理
- Types: Decision, Module Info

## [2026-04-10] ingest | infra
- 路线图状态更新：Phase 5 (demo 应用) 从准备中升级为实施中；Phase 6 (HXPluginRuntime) 暂停，目标改为先在3588设备上运行测试地图
- Types: Decision, Module Info

## [2026-04-10] ingest | infra
- 路线图拆分：Phase 7 (GIS server 基于 HXPluginRuntime) 暂停，新增 Phase 8 单独引入跨平台 GIS server，直接在3588设备上实施
- Types: Decision, Module Info

## [2026-04-10] ingest | cpp-env
- QtCreator 下载链接改为 latest 通用地址，不再固定版本号
- Types: Module Info

## [2026-04-08] ingest | cpp-env
- 从 `C++开发环境配置.md` 提取知识：GCC9 兼容方案、Docker buildx 跨平台构建、ASAN+ASLR 调试策略、valgrind 工具链、Core Dump 分析流程、CH340 驱动 bug、Git 分支合并流程
- Types: Decision, Strategy, Bug Experience, Module Info

## [2026-04-07] ingest | infra
- 项目初始化完成：AGENTS.md 清单式配置、docs/agents/knowledge/ 知识库骨架、project-compound skill
- Types: Decision, Strategy, Module Info

## [2026-09-06] ingest | skills
- 新增 Decision: 知识闭环机制（Impact 回写 + Failed Approaches + Provenance 试水，复刻自 HXProjectTemplate de30dbc）
- Types: Decision

## [2026-09-09] ingest | agent-guidelines
- 治理决策：AGENTS.md 去重——删除与全局 AGENTS.md（~/.config/opencode/AGENTS.md）重复的通用规则（题记/读写元规则/核心原则/行为准则/经验记忆/知识查询与沉淀），仅保留项目专属小节（标题 ### → ##）
- 依据：OpenCode 会话恒注入全局 AGENTS.md，通用规则以全局文件为唯一事实源，项目 AGENTS.md 仅留项目专有物（对齐 HXProjectTemplate 拆分标准）
- Cross-ref: [[agent-guidelines]]
- Types: Decision

## [2026-09-17] lint | 3 issues found, 0 auto-fixed
- Broken wiki-link: agent-guidelines -> [[context-mode]]
- Broken wiki-link: agent-guidelines -> [[ref]]
- Orphan modules (no inbound link): agent-guidelines

## [2026-09-24] remove | context-strategy.md
- 项目 AGENTS.md 删除「上下文与沙盒策略」章节并清理本文档：全局 AGENTS.md 已覆盖，项目级不再重复

## [2026-10-19] ingest | daily-report
- Work 目录迁移（/Workspace、/HXAppPlatform 双根消亡 → ~/Documents 各子目录、~/Documents/HXAppPlatform）断裂夜间日报链路三层：crontab 入口、cron 脚本内路径、skill 提示词（落盘/扫描根/会话 IN 清单）。教训：绝对路径散落「调度层+脚本层+提示词层」，迁移只改入口必漏，须全链 grep 写死路径逐层替换
- 收集根裁定：~/Documents 各子目录（find maxdepth 3）+ ~/.dotfiles（~ maxdepth 2 轨覆盖）；会话 SQLite IN 清单补 /home/guangbin/.dotfiles
- Types: Bug Experience, Decision

## [2026-10-19] refactor | 结构
- 根目录 11 个参考 md 经 git mv 归档至 docs/patents(3)/solutions(4)/reference(4)，根目录只留 AGENTS.md 与 plan.md；同步更新 AGENTS.md 合同、structure.md 目录树、cpp-env.md Key files、imagetool-v2/README.md 引用、Qt-Android 文档图片相对路径
- Types: Decision

## [2026-10-20] ingest | daily-report
- 仓扫描符号链接盲区：HXAppPlatform 的 repo 清单布局下子仓 .git 为符号链接（HXPRShell/.git -> ../.repo/projects/HXPRShell.git），daily-report 双轨遍历 `find -name .git -type d` 不跟随符号链接→漏仓（实证 2026-10-20：HXPRShell 当日 1 commit 漏扫，靠直查 git log 补回，日报计数幸免失真）。对策：遍历条件改 `( -type d -o -type l )` 或对已知 .repo 清单子仓直查兜底；.opencode/skills/daily-report/SKILL.md 待修（上报待确认）
- Types: Bug Experience

## [2026-10-21] ingest | daily-report
- opencode.db 会话表迁移 session→session_v2（schema 演进无兼容别名），skill 第 5 节 SQLite 模板 `FROM session` 直接报 no such table：session_list 工具不可信之外再添一层「表名漂移」——SQLite 直查前先查 sqlite_master/PRAGMA table_info 校表名再取数；.opencode/skills/daily-report/SKILL.md 查询模板待同步（上报待确认，与 2026-10-20 符号链接待修项合并处理）
- Types: Bug Experience
