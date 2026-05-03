# garden (private vault)

Your LLM-tended second brain. Plain markdown, wiki-links, Obsidian-friendly, agent-maintained.

The framework lives at https://github.com/khou/gardenkit. This repo holds your data.

## Conventions

**Atomic notes.** One concept per file. Small.

**Link, don't nest.** If a note relates to a project, drop a `[[projects/project-name]]` link rather than putting it in a project folder.

**Frontmatter on every note:**

```yaml
---
type: note          # note | decision | person | project | daily | learning
tags: [topic1, topic2]
created: YYYY-MM-DD
updated: YYYY-MM-DD
---
```

## Folders

- `notes/`: atomic notes on any topic
- `projects/`: one MOC per project; links to relevant notes/decisions
- `people/`: one file per person worth tracking
- `decisions/`: ADR-style: why we decided X
- `daily/`: one file per day, append-as-you-go
- `learnings/`: TIL-style facts worth keeping
- `inbox/`: raw captures awaiting gardener processing
- `meta/`: vault config, identity files, gardener rules

## Entry point

[[00-index]] is the vault's root. Every session-start loads it.

## Maintenance

The vault is **LLM-tended.** Don't manually file or organize. Capture to `inbox/`; the gardener (scheduled) processes it into atomic notes and links them in.
