---
name: doctor
description: Check that the handoff environment is ready — gh, authentication, token permissions for each neighbouring repository, labels and version agreement.
argument-hint: "[--repo owner/name]"
disable-model-invocation: true
allowed-tools: Bash(hf *), Bash(bash *hf.sh *), Bash(gh *)
---

Check that the environment is ready.

```bash
hf doctor $ARGUMENTS
```

Translate the output for the human: what is fine, what needs action.

- `FAIL gh` — install GitHub CLI (https://cli.github.com) or set `HANDOFF_GH`.
- `FAIL auth` — `gh auth login`.
- `FAIL peer: … 403` — the token lacks permissions (Issues and Pull requests:
  Read & Write, Contents: Read & Write) or needs SAML SSO authorisation for the org.
- `FAIL peer: … 404` — the repository is outside the token's reach.
- `WARN labels` — run `hf labels-ensure` (only two labels are needed: `agent-task`
  and `handoff:parent`; statuses are reactions).
- `WARN config` — run `/handoff:init`.

The full token requirements live in `docs/en/setup.md` of the plugin repository.
