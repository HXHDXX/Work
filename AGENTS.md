# AGENTS.md

> 车机导航工程知识库（Obsidian vault + git），非代码仓。主线：专利撰写、整机镜像、日报自动化。
> 文档系统索引：`./docs/agents/index.md`；行为准则详细：`./docs/agents/core/principles.md`

### 工作区性质
- 文档优先；可执行代码仅 `imagetool-v2/*.sh` 与 `scripts/` 两处
- 无构建/测试/lint 体系；脚本验证靠 `bash -n` 自检与实跑
- 根目录 `*.md` 为专利/环境/Git 流程/方案参考，保持原状不重构

### 目录结构
- 详细规范：`./docs/agents/core/structure.md`
- `daily/` 日报 `日报-YYYY-MM-DD.txt`；`INDEX.md` 为生成物勿手改
- `imagetool-v2/` 整盘镜像工具集（唯一破坏性操作区，有独立 AGENTS.md）
- `scripts/` 日报索引器 `daily-index.py` + `daily-report-cron.sh`
- `outputs/` 交付产物（gitignored：专利包、金镜像恢复记录）
- `docs/agents/` 文档系统 Layer 2/3；`.opencode/skills/` 项目级技能

### 日报工作流
- 详细：`./.opencode/skills/daily-report/SKILL.md`
- cron `0 22 * * *` 生成当日 `daily/日报-*.txt`；新旧两种格式并存
- 主题索引重建：`python3 scripts/daily-index.py`（覆盖 `daily/INDEX.md`）

### 整机镜像
- 详细：`./imagetool-v2/README.md`；工具内规约见 `./imagetool-v2/AGENTS.md`
- 全部脚本 `sudo bash` 运行；restore 默认仅写可移动盘
- 断点/阻塞看 `./outputs/golden-images/RESUME-*.md`

### 知识沉淀
- 详细：`./docs/agents/index.md`
- 非 trivial 变更经 `project-compound` ingest 更新 `./docs/agents/knowledge/`
- 经验追加 `knowledge/log.md`（append-only）；查询为空禁止编造

### Git 与语言
- 详细：`./docs/agents/writing-guide.md`
- commit 英文 Conventional Commits；文档正文中文为主
- `docs/` 外不新建 .md（技术参考除外）；表格优先于长列表
### Trivial 豁免验证
- 本仓无构建系统：Trivial 变更（≤1 文件 ≤20 行）以链接/引用验证替代构建验证

### 陷阱（XXX）
- 设备重启后 SSH host key 变化，恢复类任务需专用 ssh 参数
- 镜像脚本内 L1/L4/L6 编号注释对应历史事故，修改前先读勿删
- `daily/INDEX.md` 与 `outputs/` 为生成物/忽略物，手改必丢
- `.codegraph` 为符号链接、`.omo` 为运行状态，均不入版控
