---
name: garden-recall
description: Search the garden vault for notes relevant to a query and surface them with citations. Use when the user asks about past decisions ("what did I decide about X"), past work ("what's the state of Y"), or anything where the vault might already hold the answer. Greps + reads files under ~/garden/.
---

# garden-recall

Pulls relevant notes from `~/garden/` for a query. Used by the SessionStart hook automatically; can also be invoked explicitly.

## How

1. **Identify search terms** from the query. Include synonyms and related concepts.

2. **Grep the vault** for matches:
   ```bash
   grep -ril "<term>" ~/garden --include="*.md" | head -20
   ```

3. **Rank candidates** by relevance:
   - Exact match in title (frontmatter or H1) > body match
   - Recent `updated:` > older
   - Files in `decisions/` and `projects/` > generic `notes/`

4. **Read the top 3–5 files.** For each, note timestamp and one-line gist.

5. **Follow wiki-links** one hop if the top hits reference unread notes that look on-topic.

6. **Synthesize for the user** with citations:
   ```
   From the vault:
   - [[<note-name>]] (updated YYYY-MM-DD): <one-line gist>
   - …
   
   <synthesized answer>
   ```

## When to use

- User asks "what did we decide about X"
- User asks about state of a project, person, or topic
- Before answering any question where the vault might already hold context: silent recall, then synthesize

## Don't

- Don't read every match: top-ranked few only.
- Don't guess if the vault has nothing: say so plainly: "Nothing in the vault on that yet."
- Don't write to the vault from this skill. Recall is read-only.

## Speed

For broad recall (many candidate files), use:
```bash
grep -ril "<term>" ~/garden --include="*.md" | xargs -I{} sh -c 'echo "=== {} ==="; head -20 "{}"' | head -200
```
to get a fast overview before deep-reading.
