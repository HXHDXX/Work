# 项目目录结构

> AGENTS.md「项目目录结构」清单的详细说明。
> 新建/调整目录前必读。跨模块调用、引入第三方依赖前必读。提交代码前验证布局合规性必读。

## 当前结构

```
./
├── AGENTS.md                    ← Agent 入口清单（Layer 1）
├── docs/
│   └── agents/
│       ├── index.md             ← 文档索引与元规则（Layer 2）
│       ├── core/
│       │   ├── principles.md    ← 原则与行为准则
│       │   ├── context-strategy.md ← 上下文与沙盒策略
│       │   └── structure.md     ← 本文件：目录结构规范
│       ├── writing-guide.md     ← 文档编写规范
│       └── knowledge/
│           ├── knowledge-index.md ← 知识库索引
│           ├── log.md           ← 操作日志（append-only）
│           └── modules/         ← 模块知识页（Layer 3）
│               ├── infra.md
│               └── cpp-env.md
├── .opencode/                   ← opencode 配置与 skills
├── .worktrees/                  ← Git worktree 工作目录（按需创建）
├── plan.md                      ← 项目路线图
├── pics/                        ← 图片资源
├── C++开发环境配置.md            ← C++ 开发环境参考
├── Qt-Android开发环境配置.md    ← Qt Android 开发环境参考
├── gammaray_remote_debug.md     ← GammaRay 远程调试参考
├── 产品体系构想.md              ← 产品规划参考
└── 遥感地形图路线规划技术方案.md  ← 技术方案参考
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
