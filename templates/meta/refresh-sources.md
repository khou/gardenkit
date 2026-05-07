---
type: meta
updated: YYYY-MM-DD
---

# Continuous-refresh sources

Read by the gardener's external-refresh phase on every scheduled run. Edit directly to add, remove, or rescope sources.

If this file has no "Active" entries (just comments don't count), the gardener skips its external-refresh phase and logs it. No source pulls happen until you populate it, either by running `garden-bootstrap` in `init` mode or by editing this file directly.

## Active

<!--
One bullet per source the gardener should refresh on every pass. Be specific:
the agent reads this verbatim and only does what's written here.

Example shape:
- **Gmail**: threads with contacts named in `meta/user.md`. Skip marketing, billing, calendar invites.
- **Slack**: `#<work-channel>`, `#<other-channel>`. Skip DMs unless I'm a participant.
- **Drive**: folders `<Project>/<Subfolder>`, `<Project>/<Other-subfolder>`. Skip drafts and trash.
-->

## Excluded (init-only, do not refresh)

<!--
Optional: sources you pulled from once during init but don't want refreshed
on the gardener cadence. Useful as a record so future-you knows why a source
isn't here. Example:
- **LinkedIn**: too noisy for ongoing refresh.
-->
