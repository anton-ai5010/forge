---
name: ui-ux-design
description: "Use when creating UI layouts, choosing color palettes, selecting fonts, building design systems, or making any visual/UX decisions for web or mobile projects"
---

# UI/UX Design System Generator

Data-driven design decisions powered by a BM25 search engine over curated databases of styles, color palettes, typography pairings, UX guidelines, chart types, and landing page patterns.

## When to Use

- User asks to create a UI, page, or component and needs visual direction
- Choosing colors, fonts, or layout patterns for a project
- Building or updating a design system
- Making UX decisions (accessibility, interaction patterns, responsive design)
- Selecting chart types for data visualization
- **After** `forge:brainstorming` when the task involves frontend/visual work

## Workflow

### Step 1: Understand Requirements

Clarify with the user:
- **Product type** (SaaS, e-commerce, dashboard, mobile app, etc.)
- **Target audience** and platform (web, mobile, both)
- **Mood/vibe** (professional, playful, luxurious, minimal, etc.)
- **Tech stack** (React, Vue, Flutter, etc.) — for stack-specific guidelines

### Step 2: Search the Design Database

Run the search engine from the skill directory:

```bash
# Auto-detect domain from query
python3 {SKILL_DIR}/scripts/search.py "SaaS dashboard" --domain product

# Search specific domains
python3 {SKILL_DIR}/scripts/search.py "glassmorphism" --domain style
python3 {SKILL_DIR}/scripts/search.py "SaaS" --domain color
python3 {SKILL_DIR}/scripts/search.py "clean professional" --domain typography
python3 {SKILL_DIR}/scripts/search.py "trend over time" --domain chart
python3 {SKILL_DIR}/scripts/search.py "navigation" --domain ux
python3 {SKILL_DIR}/scripts/search.py "e-commerce" --domain landing

# Stack-specific guidelines
python3 {SKILL_DIR}/scripts/search.py "performance" --stack react
python3 {SKILL_DIR}/scripts/search.py "routing" --stack nextjs
```

Where `{SKILL_DIR}` = the directory containing this SKILL.md file. Use `dirname` of this file's path or the known path `forge-plugin/skills/ui-ux-design`.

**Available domains:** style, color, chart, landing, product, ux, typography, icons, react, web, google-fonts

**Available stacks:** react, nextjs, vue, svelte, astro, swiftui, react-native, flutter, nuxtjs, nuxt-ui, html-tailwind, shadcn, jetpack-compose, threejs, angular, laravel

### Step 3: Generate Complete Design System

For a full design system recommendation (aggregates all domains + applies reasoning rules):

```bash
python3 {SKILL_DIR}/scripts/search.py "SaaS dashboard" --design-system -p "My Project" --format markdown
```

This produces: pattern, style, colors (full 16-token palette), typography, key effects, anti-patterns, and a pre-delivery checklist.

### Step 4: Persist Design System (Optional)

Save as Master + Overrides pattern for the project:

```bash
# Create MASTER.md (global source of truth)
python3 {SKILL_DIR}/scripts/search.py "SaaS dashboard" --design-system --persist -p "My Project"

# Create page-specific override
python3 {SKILL_DIR}/scripts/search.py "SaaS dashboard" --design-system --persist -p "My Project" --page "pricing"
```

Output goes to `design-system/<project>/MASTER.md` and `design-system/<project>/pages/<page>.md`.

### Step 5: Save to Project Docs

Save the final design system spec to `docs/plans/design-system.md` (if FORGE project) so other skills and sessions can reference it.

## Search Domains Quick Reference

| Domain | Data | Rows | Use For |
|--------|------|------|---------|
| product | products.csv | 161 | Product type → style/pattern recommendations |
| style | styles.csv | 71 | UI style details, CSS keywords, effects |
| color | colors.csv | 161 | Full 16-token color palettes per product type |
| typography | typography.csv | 73 | Font pairings with Google Fonts URLs |
| landing | landing.csv | 34 | Landing page patterns, CTA strategies |
| chart | charts.csv | 25 | Chart type selection, accessibility grades |
| ux | ux-guidelines.csv | 99 | UX best practices across 14 categories |
| icons | icons.csv | 105 | Icon recommendations (Phosphor) |
| google-fonts | google-fonts.csv | 200+ | Google Fonts metadata search |
| react | react-performance.csv | 44 | React/Next.js performance patterns |
| web | app-interface.csv | 30 | Web accessibility & interface guidelines |

## Pre-Delivery Checklist

Every UI output MUST pass these checks:

- [ ] No emojis as icons — use SVG (Heroicons, Lucide)
- [ ] `cursor-pointer` on all clickable elements
- [ ] Hover states with smooth transitions (150-300ms)
- [ ] Text contrast 4.5:1 minimum (WCAG AA)
- [ ] Focus states visible for keyboard navigation
- [ ] `prefers-reduced-motion` respected
- [ ] Responsive: 375px, 768px, 1024px, 1440px

## Canva MCP Integration

If Canva MCP tools are available (`mcp__claude_ai_Canva__*`), use them to:
- Generate visual mockups from the design system
- Create brand assets using the selected palette and typography
- Export design previews for stakeholder review
