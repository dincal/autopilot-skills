# Autopilot Todo

<!-- autopilot:todo schema v1

Each item is one top-level checklist entry:

- [ ] <ID> | P<0-3> | <user|agent> | <status>
  - story: As a <role>, I want <capability> so that <benefit>.
  - acceptance:
    - <observable behavior>
  - depends-on: <ID> (optional)
  - notes: <free text> (optional)

Rules:
- ID: AP-### — monotonically increasing, never reused (check the whole file AND
  .autopilot/branch/ + CHANGELOG for the highest ID before allocating).
- source: "user" items ALWAYS rank above "agent" items, regardless of priority.
- Ordering within the file: source (user first) → priority (P0 highest) → ID (lowest first).
- status: pending | selected | in-progress | in-review | blocked
- The story line is mandatory: every item must be at least user-story sized.
  Anything smaller gets batched with related items into one feature.
- acceptance bullets must be observable behaviors — the E2E review agent
  verifies exactly these.
- Completed items are REMOVED from this file. This file lists only what is
  NOT yet built; finished work lives in .autopilot/branch/ docs and CHANGELOG.md.
-->

## Items

<!-- No items yet. Add items with /autopilot-todo, or let /autopilot-sync
     and the autopilot dev loop populate them. -->
