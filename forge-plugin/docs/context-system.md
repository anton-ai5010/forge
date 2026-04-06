# FORGE Context System — L0/L1/L2

Система документации проекта с трёхуровневой загрузкой контекста.
Цель: Claude читает только то, что нужно для текущей задачи.

## Принцип

```
L0 (~200 токенов) — ВСЕГДА в контексте. Каталог всего что есть.
    ↓ Claude матчит теги с текущей задачей
L1 (~500-2K токенов) — загружается по совпадению тегов. Компактные обзоры.
    ↓ только если summary недостаточно (12% случаев)
L2 (без лимита) — полный документ. Загружается редко.
```

## Почему это работает

1. **Context Rot** (Chroma, 2026): точность падает с 89% (8K) до 25% (1M).
   Меньше контекста = лучше результат.
2. **Lost in the Middle**: LLM имеют U-образное внимание — середина теряется.
   Компактный L0 в начале промпта = максимум внимания.
3. **OpenViking** (ByteDance): L0/L1/L2 даёт 92.9% сокращение токенов.
4. **YAML** (бенчмарк): 62.1% точность vs 50.3% JSON на nested data.

## Формат файлов

Все структурированные файлы — YAML (не JSON, не Markdown).
Prose-инструкции (SKILL.md, CLAUDE.md) — остаются Markdown.
Табличные данные (CSV в скиллах) — остаются CSV.

## Уровень L0 — docs/index.yml

Загружается КАЖДЫЙ промпт через hook. Бюджет: ≤200 токенов.

```yaml
project: {name}
goal: {одно предложение}
stage: {init|active-dev|mvp|stable}
progress: 0%
blocked: нет
stack: [lang, framework, ...]

now:
  task: {текущая задача}
  branch: {git branch}

# КАТАЛОГ — карта всех ресурсов L1/L2
# Claude читает теги и решает что загружать
catalog:
  map:
    path: docs/map.yml
    tags: [structure, files, dirs, where, create, navigate, red-zone]

  conventions:
    path: docs/conventions.yml
    tags: [naming, format, style, commit, pattern, rules]

  status:
    path: docs/status.yml
    tags: [working, broken, blocked, health, state]

  decisions:
    path: docs/decisions.yml
    tags: [why, architecture, choice, tradeoff, rationale]

  dead-ends:
    path: docs/dead-ends.yml
    tags: [failed, tried, broken, doesnt-work, avoid, mistake]

  journal:
    path: docs/journal.yml
    tags: [history, last-session, previous, yesterday, when, resume]

  skills:
    path: docs/skills-catalog.yml
    tags: [skill, workflow, how-to, process, tool]

# Сессия (live) — обновляется session-awareness
session:
  started: {time}
  goal: {цель сессии}
  done: []
  now: {что делаем}
  next: {что дальше}
  errors: []

last_session: "{date} — {summary}"
```

### Как Claude использует catalog

1. Получает промпт пользователя
2. Сканирует catalog[].tags на совпадение с задачей
3. Загружает ТОЛЬКО совпавшие L1 файлы
4. Если L1 summary достаточно — не грузит L2
5. Если нужны детали — грузит конкретную L2 запись

Пример: пользователь спрашивает "почему мы не используем RAG?"
→ tags match: decisions [why, architecture], dead-ends [tried, avoid]
→ Claude загружает docs/decisions.yml и docs/dead-ends.yml
→ Находит ответ в L1 summary → НЕ грузит L2

## Уровень L1 — компактные обзоры

Каждый L1 файл содержит ВСЕ записи как one-liners с тегами.
Бюджет: ~30 токенов на запись.

### docs/dead-ends.yml (L1)

```yaml
entries:
  - id: rag-for-context
    date: 2026-04-06
    summary: "LightRAG для проектных знаний — overkill, BM25+grep достаточно"
    tags: [rag, search, retrieval, embeddings, lightrag, vector]
    detail: docs/dead-ends/rag-for-context.md  # L2

  - id: yaml-anchors
    summary: "YAML anchors в SKILL.md — Claude не парсит anchors"
    tags: [yaml, anchors, templating, dry]
    detail: docs/dead-ends/yaml-anchors.md
```

### docs/decisions.yml (L1)

```yaml
entries:
  - id: bm25-over-rag
    date: 2026-04-06
    decision: "BM25 вместо RAG для поиска по данным"
    why: "Zero-cost, детерминированный, не требует LLM для индексации"
    tags: [search, rag, bm25, architecture]
    detail: null  # L2 не нужен, summary достаточно

  - id: yaml-over-json
    date: 2026-04-06
    decision: "YAML вместо JSON для docs/ файлов"
    why: "20-30% меньше токенов, лучшее понимание LLM (62% vs 50%)"
    tags: [format, yaml, json, tokens]
```

### docs/status.yml (L1)

```yaml
working:
  - "FORGE documentation system"
  - "Hook-based context injection"
broken: []
blocked: []
```

### docs/map.yml (L1)

```yaml
directories:
  src/:
    files: 10
    red_zone_files: 2
    about: "main source code"
  tests/:
    files: 5
    about: "test suite"

red_zones:
  - path: src/critical.py
    why: "production payment logic"
```

### docs/conventions.yml (L1)

```yaml
language: python
naming:
  files: snake_case
  classes: PascalCase
  functions: snake_case
  constants: UPPER_SNAKE_CASE
structure:
  src: "source code"
  tests: "tests mirror src/"
patterns: {}
```

### docs/journal.yml (L1)

```yaml
entries:
  - date: 2026-04-06
    summary: "Интеграция ui-ux-design скилла"
    result: "BM25 search работает, 14 CSV баз данных"
    next: "Оптимизация context system"
    files: [skills/ui-ux-design/]

  - date: 2026-04-05
    summary: "Hook-based context injection"
    result: "Контекст инжектится автоматически"
    next: "Интеграция ui-ux-design"
```

### docs/skills-catalog.yml (L1)

```yaml
entries:
  - name: brainstorming
    trigger: "BEFORE any creative/feature work"
    gives: "requirements, constraints, scope"

  - name: ui-ux-design
    trigger: "WHEN building UI, choosing colors/fonts/layout"
    gives: "design system with palette, typography, UX rules"
    has_tools: true

  - name: systematic-debugging
    trigger: "WHEN bug, test failure, unexpected behavior"
    gives: "4-phase root cause analysis"

  - name: test-driven-development
    trigger: "WHEN implementing features or fixes"
    gives: "red-green-refactor cycle"

  - name: writing-plans
    trigger: "WHEN have spec, before coding"
    gives: "bite-sized implementation plan"

  - name: code-cleanup
    trigger: "WHEN code quality issues, dead code, naming"
    gives: "refactoring with quality checks"
```

## Уровень L2 — полные документы

Формат: Markdown (для prose) или YAML (для данных).
Загружаются ТОЛЬКО когда L1 summary недостаточно.

Примеры L2:
- `docs/dead-ends/rag-for-context.md` — полное описание почему RAG не подходит
- `docs/library/*/spec.yml` — детальные спецификации файлов
- `docs/plans/*.md` — полные планы реализации

### docs/library/*/spec.yml (L2)

```yaml
purpose: "what this directory is for"
files:
  search.py:
    intent: "BM25 search engine for UI/UX data"
    inputs: [query: str, domain: str]
    outputs: "ranked search results"
    depends_on: [core.py, data/*.csv]
    red_zone: false
```

## Hook: context-inject.sh

Инжектирует L0 в каждый промпт:

```bash
# Проверяет docs/index.yml (новый формат) или docs/index.md (legacy)
# Читает ТОЛЬКО index файл (~200 токенов)
# НЕ читает L1/L2 файлы — Claude решает сам
```

## Совместимость

Hook проверяет оба формата:
1. `docs/index.yml` — новый формат (приоритет)
2. `docs/index.md` — legacy формат (fallback)

`/forge:init` генерирует новый формат.
`/forge:sync` работает с обоими форматами.

## Правила для Claude

1. **L0 всегда в контексте** — не нужно читать index.yml вручную
2. **L1 загружай по тегам** — match catalog[].tags с текущей задачей
3. **L2 загружай редко** — только если L1 summary недостаточно
4. **Не грузи всё подряд** — каждый файл стоит токены
5. **Не читай source code** до чтения docs/library/spec.yml
6. **Position matters** — важное в начале/конце файла, не в середине

## Миграция с v2

| Было (v2) | Стало (v3) | Изменение |
|-----------|-----------|-----------|
| docs/index.md (~400 tok) | docs/index.yml (~200 tok) | YAML + catalog |
| docs/map.json | docs/map.yml | JSON → YAML |
| docs/conventions.json | docs/conventions.yml | JSON → YAML |
| docs/library/*/spec.json | docs/library/*/spec.yml | JSON → YAML |
| docs/status.md | docs/status.yml | MD → YAML |
| docs/dead-ends/*.md | docs/dead-ends.yml (L1) + *.md (L2) | Добавлен L1 индекс |
| docs/decisions.md | docs/decisions.yml (L1) + null (L2 optional) | YAML summaries |
| docs/journal.md | docs/journal.yml | MD → YAML |
| (не было) | docs/skills-catalog.yml | Новый: каталог скиллов |
