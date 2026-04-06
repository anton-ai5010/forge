---
name: ui-ux-design
description: "Use when creating UI layouts, choosing color palettes, selecting fonts, building design systems, implementing frontend components, or making any visual/UX decisions for web or mobile projects"
---

# UI/UX Design System Generator

Data-driven design decisions powered by a BM25 search engine over curated databases of styles, color palettes, typography pairings, UX guidelines, chart types, and landing page patterns. Combined with creative direction principles for distinctive, non-generic output.

## When to Use

- User asks to create a UI, page, or component and needs visual direction
- Building frontend interfaces — pages, components, applications
- Choosing colors, fonts, or layout patterns for a project
- Building or updating a design system
- Making UX decisions (accessibility, interaction patterns, responsive design)
- Selecting chart types for data visualization
- **After** `forge:brainstorming` when the task involves frontend/visual work

## Workflow

### Step 1: Design Thinking

Before touching data or code, understand the context and commit to a direction:

- **Product type** (SaaS, e-commerce, dashboard, mobile app, etc.)
- **Target audience** and platform (web, mobile, both)
- **Tech stack** (React, Vue, Flutter, etc.) — for stack-specific guidelines
- **Tone** — pick a clear aesthetic direction: brutally minimal, maximalist, retro-futuristic, organic/natural, luxury/refined, playful/toy-like, editorial/magazine, brutalist/raw, art deco/geometric, soft/pastel, industrial/utilitarian. Commit to one.
- **Differentiation** — what makes this UNFORGETTABLE? What's the one thing someone will remember?

**CRITICAL**: Choose a clear conceptual direction and execute it with precision. Bold maximalism and refined minimalism both work — the key is intentionality, not intensity.

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

### Step 3: Apply Creative Direction

Take the search results and elevate them through aesthetic lens from Step 1:

**Typography** — search results give you font pairings. Now push further:
- Pair a distinctive display font with a refined body font
- NEVER default to Inter, Roboto, Arial, or system fonts
- NEVER converge on common AI choices (Space Grotesk) across generations
- Each project gets unique typography that matches its personality

**Color & Theme** — search results give you 16-token palettes. Now make them sing:
- Dominant colors with sharp accents outperform timid, evenly-distributed palettes
- Use CSS variables for consistency
- Commit to a cohesive aesthetic — don't hedge with safe neutrals

**Spatial Composition** — go beyond standard layouts:
- Asymmetry, overlap, diagonal flow, grid-breaking elements
- Generous negative space OR controlled density — choose one
- Unexpected layouts that feel genuinely designed for the context

**Motion & Interaction** — high-impact moments over scattered micro-interactions:
- One well-orchestrated page load with staggered reveals (animation-delay) > many small animations
- Scroll-triggered reveals and hover states that surprise
- CSS-only solutions for HTML; Motion library for React
- Respect `prefers-reduced-motion`

**Backgrounds & Texture** — create atmosphere and depth:
- Gradient meshes, noise textures, geometric patterns, layered transparencies
- Dramatic shadows, decorative borders, grain overlays
- Never default to solid white/gray backgrounds without purpose

**Match complexity to vision.** Maximalist designs need elaborate code with extensive animations. Minimalist designs need restraint, precision, and careful spacing/typography. Elegance comes from executing the vision well.

### Step 4: Generate Complete Design System

For a full design system recommendation (aggregates all domains + applies reasoning rules):

```bash
python3 {SKILL_DIR}/scripts/search.py "SaaS dashboard" --design-system -p "My Project" --format markdown
```

This produces: pattern, style, colors (full 16-token palette), typography, key effects, anti-patterns, and a pre-delivery checklist.

### Step 5: Persist Design System (Optional)

Save as Master + Overrides pattern for the project:

```bash
# Create MASTER.md (global source of truth)
python3 {SKILL_DIR}/scripts/search.py "SaaS dashboard" --design-system --persist -p "My Project"

# Create page-specific override
python3 {SKILL_DIR}/scripts/search.py "SaaS dashboard" --design-system --persist -p "My Project" --page "pricing"
```

Output goes to `design-system/<project>/MASTER.md` and `design-system/<project>/pages/<page>.md`.

### Step 6: Save to Project Docs

Save the final design system spec to `.forge/plans/design-system.md` (if FORGE project) so other skills and sessions can reference it.

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

## Anti-Slop Checklist

NEVER produce generic AI aesthetics:

- [ ] No Inter, Roboto, Arial, system fonts — use distinctive typography from search results
- [ ] No purple gradients on white backgrounds
- [ ] No cookie-cutter layouts — each design has context-specific character
- [ ] No identical designs across projects — vary themes, fonts, aesthetics
- [ ] No flat solid-color backgrounds without texture or depth
- [ ] No scattered micro-animations without a cohesive motion strategy

## Pre-Delivery Checklist

Every UI output MUST pass these checks:

- [ ] No emojis as icons — use SVG (Heroicons, Lucide, Phosphor)
- [ ] `cursor-pointer` on all clickable elements
- [ ] Hover states with smooth transitions (150-300ms)
- [ ] Text contrast 4.5:1 minimum (WCAG AA)
- [ ] Focus states visible for keyboard navigation
- [ ] `prefers-reduced-motion` respected
- [ ] Responsive: 375px, 768px, 1024px, 1440px
- [ ] Design has a clear aesthetic point-of-view (not generic)
- [ ] Typography is distinctive and intentional
- [ ] Color palette is cohesive with sharp accents

## Canva MCP Integration

If Canva MCP tools are available (`mcp__claude_ai_Canva__*`), use them to:
- Generate visual mockups from the design system
- Create brand assets using the selected palette and typography
- Export design previews for stakeholder review
