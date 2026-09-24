# 项目目录结构

> AGENTS.md「项目目录结构」清单的详细说明。
> 新建/调整目录前必读。跨模块调用、引入第三方依赖前必读。提交代码前验证布局合规性必读。

## 当前结构

```
./
├── AGENTS.md                    ← Agent 入口清单（Layer 1）
├── daily/                       ← 工作日报（日报-*.txt；INDEX.md 为生成物）
├── imagetool-v2/                ← 整机镜像工具集（见其 AGENTS.md 与 README）
├── scripts/                     ← daily-index.py + daily-report-cron.sh
├── outputs/                     ← 交付产物（gitignored）
├── docs/
│   ├── agents/
│   │   ├── index.md             ← 文档索引与元规则（Layer 2）
│   │   ├── core/                ← principles / structure
│   │   ├── writing-guide.md     ← 文档编写规范
│   │   └── knowledge/           ← knowledge-index / log / modules（Layer 3）
│   └── superpowers/specs/       ← 设计文档
├── .opencode/                   ← opencode 配置与 skills（daily-report 等）
├── plan.md                      ← 项目路线图
├── pics/                        ← 图片资源
└── *.md（根目录）               ← 专利/环境/Git 流程/方案等参考文档
```

## 目录用途

### 核心目录

| 目录 | 用途 | 管理方式 |
|------|------|---------|
| `docs/agents/` | Agent 文档系统 | 手动维护 + project-compound |
| `docs/agents/knowledge/` | 知识库 | project-compound skill 管理 |
| `docs/agents/core/` | 核心规则 | 手动维护 |
| `.opencode/` | opencode 配置 | 版本控制（排除 node_modules） |
| `.worktrees/` | Git worktree | 按需创建，完成后清理 |
| `daily/` | 工作日报库 | cron 生成，勿手改 INDEX.md |
| `imagetool-v2/` | 整机镜像工具 | 手动维护（破坏性操作区） |
| `scripts/` | 日报工具链 | 手动维护 |
| `outputs/` | 交付产物 | 生成物，gitignored |

### 代码与依赖

> 当前项目无独立代码/依赖目录，业务代码结构待确定。

### 文档与资源

| 文件 | 用途 | 管理方式 |
|------|------|---------|
| `AGENTS.md` | Agent 入口 | 每次修改需同步更新知识库 |
| `plan.md` | 项目路线图 | 路线图变更需更新 infra.md |
| `*.md`（根目录） | 技术参考文档 | 保持原状，不重构 |

## 新增目录规则

1. **代码模块** → 放在根目录，遵循 CMake 项目结构
2. **第三方依赖** → 优先系统安装
3. **测试** → 与代码模块同目录的 `tests/` 子目录
4. **配置文件** → 与模块同目录，不集中管理

## 布局合规性检查

提交代码前检查：

- [ ] 新文件放在正确的目录
- [ ] 没有在 `docs/` 外创建新的 .md 文档（技术参考除外）
- [ ] 知识库已更新（非 trivial 变更）
