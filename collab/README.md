# 双 Agent 协作协议（Trae Agent ⇄ WorkBuddy）

本目录是两个 agent 之间的通信黑板。**人可随时查看、修改、仲裁。**

## 目录结构

```
collab/
  README.md              本协议文档
  inbox-trae.md          WorkBuddy → Trae 的消息（Trae 只读）
  inbox-workbuddy.md     Trae → WorkBuddy 的消息（WorkBuddy 只读）
  tasks/                 每个任务一个 md 文件，frontmatter 带 status
  artifacts/             日志、报错输出、设计片段等大块附件
```

## 消息格式（inbox 与 tasks 通用）

```markdown
---
id: t-001            # 唯一 id，建议 t-001 / w-001 递增（tr=Trae 发起, wb=WorkBuddy 发起）
from: trae | workbuddy
to: workbuddy | trae
status: open         # open | in-progress | done | rejected
created: 2026-10-03 14:40
---
任务/消息正文。结论、文件路径、复现步骤写清楚。
```

## 核心规则

1. **文件所有权**
   - `inbox-trae.md`：只有 WorkBuddy 写入，Trae 只读。处理完的条目由 WorkBuddy 清理或归档。
   - `inbox-workbuddy.md`：只有 Trae 写入，WorkBuddy 只读。处理完的条目由 Trae 清理或归档。
   - `tasks/` 中任务文件：创建方负责写入与关闭（改 status），执行方只允许**追加**执行记录，不得改动原任务描述。
2. **代码变更只走 Git**
   - 消息里只写指令、结论、文件路径与 commit hash，不粘贴大段代码。
   - 执行方改完代码必须 commit，并在任务文件追加 commit hash。
   - 两侧不得同时修改同一文件；如有冲突风险，先在任务文件里声明锁定范围。
3. **触发约定（每轮必须执行）**
   - 每轮工作开始：读取自己的 inbox，处理所有 `status: open` 的条目。
   - 每轮工作结束：把给对方的新消息写入对方的 inbox（追加，不覆盖历史条目）。
   - 无新消息时也要在对方 inbox 末尾追加一行确认，例如 `<!-- t-001 done at 2026-10-03 15:00 -->`，证明本轮已检查。
4. **冲突仲裁**：规则未覆盖或双方结论矛盾时，任务 status 置为 `open` 并在正文标注 `NEED HUMAN`，等用户裁决。

## 双侧落地

- **Trae 侧**：在项目规则（`.trae/rules` 或项目级 AGENTS.md）中加入：
  > 每轮开始先读 `D:\zfy\collab\inbox-trae.md`，处理 open 条目；每轮结束把需要 WorkBuddy 处理的事项按协议格式追加到 `collab/inbox-workbuddy.md`。严格遵守 collab/README.md 协议。
- **WorkBuddy 侧**：已写入 workspace 长期记忆，每次会自动遵守。
