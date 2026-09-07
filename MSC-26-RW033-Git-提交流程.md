# MSC-26-RW033 Git 提交流程（团队约定）

> 适用范围：MSC-26-RW033 应用开发线。多仓管理使用 Google repo，manifest 由团队统一维护。

---

## 1. 分支拓扑与角色

```
master (基线, 团队维护)
|
+-- MSC-26-RW033 (应用集成, 多人共享)
|   |
|   +-- MSC-26-RW033-bak/<time> (变基前备份, 只读)
|   |
|   +-- MSC-26-RW033-<feature> (个人开发分支)
```

| 资源 | 维护者 |
|:---|:---|
| master 分支 | 基线团队 |
| MSC-26-RW033 分支 | 所有开发者 push |
| MSC-26-RW033.xml manifest | 团队统一维护 |
| 开发分支 / 备份分支 | 个人 |

---

## 2. 核心认知

1. **manifest 时序**：push 后必须等 manifest 维护者更新 xml，其他人 `repo sync` 才能拿到。Push 不等于立即可被同步。
2. **`-d -c` 行为**：`-d` 同步后处于 detached HEAD；`-c` 只拉当前分支，可能拉不到 MSC-26-RW033。
3. **变基是协作事件**：影响所有协作者，必须在全员在线时段执行，不能作为个人收尾动作。

---

## 3. sync 前自检（手动 5 步）

1. `git branch --show-current` → 必须是 MSC-26-RW033 族
2. `git status` → 必须 clean
3. `repo sync -m MSC-26-RW033.xml -d -c`
4. `git checkout MSC-26-RW033` → 脱离 detached HEAD（必做）
5. `git stash pop`（如步骤 2 stash 过）

### 步骤 2 处理未提交修改（三选一）

| 场景 | 命令 |
|:---|:---|
| 已完成的修改 | `git add <files> && git commit -m "..."` |
| 未完成的修改 | `git stash push -m "WIP:<描述>"` |
| 无用文件（谨慎） | `git clean -fd <path>` |

---

## 4. 日常流程

### A. 初始化版本库

```shell
# 建立版本库目录
mkdir HXAppPlatform && cd HXAppPlatform

# 初始化版本库
repo init -u ssh://git@192.168.1.100:2222/HXHDXX/app-platform-manifest.git -b master -m MSC-26-RW033.xml

# 同步版本库
repo sync -m MSC-26-RW033.xml -d -c

# 同步依赖库
repo forall -c 'git lfs pull'
```

### B. 每日上班同步

```bash
# 0. 进入版本库主程序目录
cd HXAppPlatform/HXNativeApp

# 1-3. 自检 + sync
repo sync -m MSC-26-RW033.xml -d -c

# 4. 同步依赖库
repo forall -c 'git lfs pull'

# 5. 切回集成分支
git checkout MSC-26-RW033

# 6. 继续未完成开发分支（若有）
git checkout MSC-26-RW033-<feature>
git rebase origin/MSC-26-RW033
```

### C. 日常开发

```bash
# 建分支（首次）
git checkout MSC-26-RW033
git checkout -b MSC-26-RW033-<feature>

# 开发循环
git add <files>
git commit -m "type(scope):desc"
git push origin MSC-26-RW033-<feature>
```

### D. 下班前合并回集成

```bash
# 1. 同步最新集成（自检 5 步）
repo sync -m MSC-26-RW033.xml -d -c
repo forall -c 'git lfs pull'
git checkout MSC-26-RW033

# 2. 开发分支 rebase 到最新集成
git checkout MSC-26-RW033-<feature>
git rebase origin/MSC-26-RW033

# 3. ff-only 合并（无 merge commit，符合线性历史铁律）
git checkout MSC-26-RW033
git merge --ff-only MSC-26-RW033-<feature>

# 4. 推送
git push origin MSC-26-RW033

# 5. 通知 / 等待 manifest 维护者更新
```

---

## 5. 变基到 master

### 时机策略

| 触发条件 | master 有重要更新（被动触发） |
|:---|:---|
| 执行窗口 | 下一个工作日上班第一时间 |
| 避免 | 下班前 / 周五 / 节假日前 |

### 执行步骤

```bash
# 0. 群通知（变基前 5 分钟）
# "今天<时间>我会对 MSC-26-RW033 变基到 master，期间请勿 push"

# 0.1 与 master 维护者确认 master 稳定

# 1. 同步当前 manifest 状态
repo sync -m MSC-26-RW033.xml -d -c
repo forall -c 'git lfs pull'
git checkout MSC-26-RW033

# 2. 备份（强推前必做）
git push origin MSC-26-RW033:MSC-26-RW033-bak/$(date +%Y%m%d-%H%M)

# 3. 补拉 master（-c 只拉当前分支）
git fetch origin master

# 4. 变基
git rebase origin/master
# 解决冲突 -> git add -> git rebase --continue

# 5. 强推（必须 --force-with-lease）
git push --force-with-lease origin MSC-26-RW033

# 6. 等 manifest 更新 + 在线值守协助冲突
```

### 协作者收到通知后

> 前置：工作区已干净（见 §3 自检）

```bash
# 1. 同步 manifest（此时 origin/MSC-26-RW033 已是变基后状态）
repo sync -m MSC-26-RW033.xml -d -c
repo forall -c 'git lfs pull'

# 2. 更新本地集成分支到变基后状态
# 若本地无此分支：git checkout -b MSC-26-RW033 origin/MSC-26-RW033
git checkout MSC-26-RW033
git reset --hard origin/MSC-26-RW033
# 变基重写了历史：--ff-only 走不通、merge 会留 merge commit（§8 红线），
# 故 reset --hard 采用新历史；本工作流禁止直接向集成分支提交，本地无丢失

# 3. 个人开发分支 rebase 到新集成，再强推
git checkout MSC-26-RW033-<feature>
git rebase origin/MSC-26-RW033
git push --force-with-lease origin MSC-26-RW033-<feature>
```

---

## 6. 为什么必须用 `--force-with-lease`

- `git push --force`：盲目覆盖远程
- `git push --force-with-lease`：只在远程是本地预期状态时才覆盖，否则拒绝

**场景**：T0 fetch 远程为 A，变基生成 A'，同事在 T2 push 了 B（远程 A→B），T3 强推：

| 方式 | 结果 |
|:---|:---|
| `--force` | 远程变成 A'，同事的 B 被永久销毁 |
| `--force-with-lease` | 检测远程不是预期的 A（已是 B），拒绝 push |

> 群通知是协作礼貌，`--force-with-lease` 是技术保险，两者叠加使用。

### 被拒后的处理

```bash
git fetch origin MSC-26-RW033
git log origin/MSC-26-RW033    # 看多了哪些 commit
git rebase origin/master       # 重做变基（含同事的新 commit）
git push --force-with-lease origin MSC-26-RW033
```

---

## 7. 异常处理

### 7.1 sync 后忘切分支就 commit（detached HEAD）

```bash
git refloc
git branch MSC-26-RW033-<feature> <sha>   # 找回 commit SHA
git checkout MSC-26-RW033-<feature>       # 绑回分支
```

### 7.2 sync 失败：本地有未提交修改

```bash
git status
git stash
repo sync -m MSC-26-RW033.xml -d -c
git stash pop
# 或 commit
```

### 7.3 变基冲突解不了，想回滚

```bash
git checkout MSC-26-RW033
git reset --hard origin/MSC-26-RW033-bak/<time>
git push --force-with-lease origin MSC-26-RW033
# 群通知：回滚完成，请大家重新 sync
```

### 7.4 `-c` 拉不到集成 / master 最新

```bash
git fetch origin MSC-26-RW033
git fetch origin master
```

---

## 8. 红线

| 错误 | 后果 | 正确 |
|:---|:---|:---|
| sync 后直接 commit | detached HEAD，切分支丢提交 | sync 后先 `git checkout` |
| `git push --force` | 覆盖他人推送 | `git push --force-with-lease` |
| `git merge --no-ff` | 产生 merge commit | `git merge --ff-only` |
| push 后假设他人能立即 sync | manifest 没更新就是旧代码 | 等 manifest 更新或主动通知 |
| 变基前不备份 | 出错无法回滚 | 先 push 到 `-bak/` |
| 下班前 / 周五变基 | 问题夜间发酵，全员阻塞 | 上班第一时间 + 群通知 |
| 变基不通知就强推 | 协作者本地分支全失效 | 群通知 + 在线值守 |

---

## 9. 命令速查

| 场景 | 命令 |
|:---|:---|
| sync | `repo sync -m MSC-26-RW033.xml -d -c` |
| sync 后脱离 detached HEAD | `git checkout MSC-26-RW033` |
| 建开发分支 | `git checkout -b MSC-26-RW033-<feature>` |
| 推送开发分支 | `git push origin MSC-26-RW033-<feature>` |
| 开发分支同步集成 | `git rebase origin/MSC-26-RW033` |
| 合并到集成 | `git merge --ff-only MSC-26-RW033-<feature>` |
| 推送集成 | `git push origin MSC-26-RW033` |
| 补拉其他分支 | `git fetch origin` |
| 变基备份 | `git push origin MSC-26-RW033:MSC-26-RW033-bak/$(date +%Y%m%d-%H%M)` |
| 变基强推 | `git push --force-with-lease origin MSC-26-RW033` |
