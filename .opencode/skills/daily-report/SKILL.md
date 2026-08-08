---
name: daily-report
description: 生成工作日报并（可选）发送邮件。默认当天，可指定日期或日期范围。激活词：日报、工作日报、生成日报、daily report、发日报。触发：用户要求总结当天/某日工作、发工作邮件、整理日报。
---

# Daily Report

## Overview
从 git 提交记录自动生成工作日报（txt），提炼要点，可选发送到邮箱。覆盖 `/Workspace` 与 `/HXAppPlatform` 全部仓库。日报落盘到 `/Workspace/Work/daily/日报-YYYY-MM-DD.txt`。

## When to Use
- 「生成今天/昨天的日报」
- 「生成 X 月 X 日的日报」
- 「生成 X 月 X 日至 X 月 X 日的日报」（范围批量）
- 「发日报 / 发邮件」
- 用户要求总结某日工作

## When NOT to Use
- 周报/月报/里程碑汇总（粒度不同，单独处理）
- 单一仓库的状态查询（直接查 git 即可）

## 核心规则（必须遵守）

### 1. 遍历用双轨，杜绝漏仓（已踩坑）
zsh 不对未加引号变量分词，且 find|while-read 子 shell 会漏 `/HXAppPlatform` 仓。**必须双轨**：
```bash
# A. /Workspace — find|while-read（zsh 安全）
find /Workspace -maxdepth 3 -name ".git" -type d 2>/dev/null | while read g; do
  repo=$(dirname "$g"); git -C "$repo" log --since="$D 00:00" --until="$NEXT 00:00" \
    --pretty=format:"%h|%ad|%an|%s" --date=format:"%H:%M"
done
# B. /HXAppPlatform — 逐仓直连（find|while-read 漏读，必须显式列举）
for repo in HXNativeApp HXMapWidgetNative HXPRShell maplibre-native TTSPlayer \
  test-bridge lib-HXGISServer lib-HXNmeaParser lib-HXNavigation lib-HXRouteServer \
  lib-HXPluginRuntime lib-HXSpatialMeasure lib-HXRdssSendingQueue lib-maplibre-native \
  lib-sherpa-onnx lib-GammaRay lib-hxprshell-app lib-ZMQClient; do
  d="/HXAppPlatform/$repo"; [ -d "$d/.git" ] || continue
  git -C "$d" log --since="$D 00:00" --until="$NEXT 00:00" --pretty=format:"%h|%ad|%an|%s" --date=format:"%H:%M"
done
```
排除 `.repo/*`（repo 工具仓）。`lib-*` 二进制仓可选纳入（看是否当日有发布）。

### 2. 🔴 邮件标题 Base64 必须工具生成，禁止手敲
中文邮件标题走 MIME RFC 2047：`=?UTF-8?B?<base64>?=`。**手敲 Base64 必然算错字节**（曾把「工作日报」编码成「工坊攱话」）。必须：
```bash
SUBJ_B64=$(printf '%s' "工作日报 $D" | base64 | tr -d '\n')
printf 'Subject: =?UTF-8?B?%s?=\n' "$SUBJ_B64"
```
**绝对禁止**在 SKILL 或代码里硬编码 Base64 字符串字面量。

### 3. 邮件通过 msmtp（已配 icloud 账户）
```bash
{
  printf 'From: guangbin79@icloud.com\nTo: guangbin79@icloud.com\n'
  printf 'Subject: =?UTF-8?B?%s?=\n' "$(printf '%s' "工作日报 $D" | base64 | tr -d '\n')"
  printf 'MIME-Version: 1.0\nContent-Type: text/plain; charset=UTF-8\nContent-Transfer-Encoding: 8bit\n\n'
  cat "/Workspace/Work/daily/日报-$D.txt"
} | msmtp guangbin79@icloud.com
```
退出码 0 = 成功。临时邮件文件写 `/tmp/opencode/` 用完即删。

### 4. 日报格式（提炼要点）
```
工作日报 YYYY-MM-DD（周X）
================================================
【今日要点】共 N 次提交，涉及 M 仓：
主线：<repo>(n)、<repo>(n)…
------------------------------------------------
一、<主工作线>（仓库 | n commits）
- 提交要点（按主题聚类，非逐条罗列）
二、<次工作线>
...
================================================
数据来源：<仓库> git log（日期）、commit body、opencode 会话
```
- **提炼**：按工作线聚类，写要点不逐条抄 commit；跨仓同主题合并
- 中文星期用 case 映射（`cut -c` 切多字节会乱码）
- 提交计数、仓数、主线排序要准确（git 实查）

### 5. 默认与可选参数
- **默认**：当天日期，生成 txt + 发邮件
- **指定日期**：`生成 X 月 X 日的日报`
- **范围**：`生成 X 日至 X 日的日报`（逐日独立 txt，避免一份巨文件）
- **不发邮件**：用户明说不发，或只说「整理日报」

### 6. 落盘与去重
- 路径：`/Workspace/Work/daily/日报-YYYY-MM-DD.txt`
- 同日重生成：覆盖（以最新提交为准），重发邮件标注「刷新版」
- 批量追溯（多日）：逐日独立文件；4-03 起的补录已有档案式版本，勿覆盖手工深度版

## 已知失败模式（实战教训）
| 症状 | 根因 | 对策 |
|------|------|------|
| `/HXAppPlatform` 仓全漏 | find\|while-read 子 shell 漏读 | 双轨，B 轨逐仓直连 |
| 仓库列表不遍历 | zsh 不分词未引号变量 | 用 `while read` 或数组 |
| 邮件标题乱码（工坊攱话） | 手敲 Base64 算错字节 | `printf\|base64` 工具生成 |
| 星期显示「周�」 | `cut -c` 按字节切中文 | case 映射数字→中文 |
| 同日多封邮件混淆 | 刷新重发 | 主题标「刷新版/最终版」 |

## 验证清单（生成后自检）
- [ ] 邮件标题解码回中文正确（`echo <b64> \| base64 -d` 含「工作日报」）
- [ ] `/HXAppPlatform` 仓未漏（至少检查 HXNativeApp/HXMapWidgetNative）
- [ ] 提交计数与 git 实查一致
- [ ] 星期中文正确显示
- [ ] txt 已落盘 daily/ 目录
