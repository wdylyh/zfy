# 项目长期备忘

## 双 Agent 协作协议（Trae ⇄ WorkBuddy）
- 通信黑板：`D:\zfy\collab\`，协议见 `collab/README.md`（必读）。
- **每轮工作开始**：先读 `collab/inbox-workbuddy.md`（Trae 写给我，我只读），处理所有 `status: open` 条目。
- **每轮工作结束**：把需要 Trae 处理的事项按协议格式（frontmatter: id/from/to/status/created）追加到 `collab/inbox-trae.md`（我写，Trae 只读）；无消息也追加一行确认注释。
- 代码变更只走 Git 并在任务文件里回填 commit hash；消息里不贴大段代码。
- `tasks/` 任务文件：创建方写入与关闭，执行方只允许追加执行记录。
- 矛盾或未覆盖情形 → 任务标 `NEED HUMAN` 交用户仲裁。
