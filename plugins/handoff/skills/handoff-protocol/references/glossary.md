# Glossary

| Term | What it is | How it looks |
|---|---|---|
| **parent task** | the issue in the initiating repository where coordination lives | label `handoff:parent` |
| **result comment** | the comment carrying context for foreign agents | `<!-- handoff:result … -->`, heading "📦 Result" |
| **routing comment** | the single comment holding the repository/status table | `<!-- handoff:routing … -->`, heading "🔀 Delegation" |
| **question comment** | the comment holding a question, later extended with the answer | `<!-- handoff:question … -->`, 👍 means answered |
| **dependent task** | the issue in a neighbouring repository with a prompt for its agent | label `agent-task` |
| **chain** | identifier of one delegation wave | `hf-20260913-a1b2` |
| **path** | the delegation route, used for cycle protection | `owner/api>owner/web` |
| **key** | idempotency: one task per "chain + repository" pair | `7f3c9a21` |
| **orchestrator** | the agent handing out tasks and closing the chain | a role, not a repository |
| **assignee** | the agent picking a task up, doing it and closing it | a role, not a repository |

Roles are not fixed: the same repository is an orchestrator in one chain and an
assignee in another at the same time.
