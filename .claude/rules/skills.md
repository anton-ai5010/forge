---
paths:
  - "forge-plugin/skills/**"
---

Every skill is a directory with SKILL.md inside.
SKILL.md must have YAML frontmatter: name (kebab-case), description (max 1024 chars, starts with "Use when").
Heavy reference material (100+ lines) goes into separate files, not inline.
Language-specific hints go into stack-hints/{language}.md.
