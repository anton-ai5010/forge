# FORGE Plugin — Consolidated Ideas & Improvements

> Источники: ads-plugin-architecture.md, claude-code-agents-catalog.md, claude-code-agents-guide.md,
> claude-code-agents-recommendations.md, claude-code-recommendations.md, repository-reviews.md,
> MEMORY-template.md, SKILL.md, setup-memory.sh
>
> Убрано: generic VoltAgent-агенты (ставятся отдельно), специфичные для CAME BOT/YARICK/VPN идеи,
> то что уже реализовано в forge-plugin v4.3.1

---

## A. Architecture — Foreman/Inspector Model

Главная архитектурная идея из ads-plugin-architecture: вместо набора скиллов — **три роли**:

```
Architect (user) → Foreman (orchestrator) → Specialists (agents)
                                          → Inspector (quality)
```

### A1. Foreman — Агент-оркестратор
Центральный агент, которому пользователь делегирует задачу целиком.

**Поведение:**
1. КОНТЕКСТ — всегда начинает с чтения docs/index.yml (не спрашивает "что за проект?")
2. ДЕКОМПОЗИЦИЯ — разбивает на подзадачи
3. МАРШРУТИЗАЦИЯ — выбирает подходящего специалиста для каждой
4. ИСПОЛНЕНИЕ — каждая подзадача = отдельный subagent (изолированный контекст)
5. ВЕРИФИКАЦИЯ — вызывает Inspector, обновляет docs/

**Отличие от текущего subagent-driven-development:**
- SDD — скилл, который учит КАК работать с субагентами
- Foreman — агент, который САМ является субагентом и управляет другими
- Пользователь говорит "сделай модуль оплаты", Foreman сам решает кого вызвать

**Принцип:** Пользователь общается только с Foreman. Foreman общается со специалистами. Сокращает когнитивную нагрузку.

**Экономия:** `model: sonnet` — для маршрутизации не нужен Opus.

---

### A2. Inspector — Агент контроля качества
Автоматический контролёр, НЕ пишет код — только анализирует.

**Чеклист:**
1. Безопасность — secrets в коде? SQL injection? XSS?
2. Баги — необработанные исключения? Race conditions? Off-by-one?
3. Конвенции — соответствие conventions.yml проекта
4. Тесты — есть ли для нового кода? Покрыты ли edge cases?
5. Производительность — N+1 запросы? Утечки памяти?

**Отличие от code-reviewer:**
- code-reviewer вызывается вручную или в конце этапа
- Inspector вызывается АВТОМАТИЧЕСКИ хуком после каждого Edit/Write
- Inspector read-only (tools: Read, Grep, Glob, Bash) — не может случайно сломать код

**Agent Memory:** С `memory: project` Inspector накапливает знания о паттернах проекта между сессиями.

---

### A3. Post-Edit Auto-Review Hook
```json
{
  "event": "PostToolUse",
  "filter": { "tool": ["Edit", "Write"] },
  "command": "Запусти @inspector на изменённых файлах. Кратко: только критические проблемы."
}
```
Автоматический ревью после каждого изменения. Inspector не тормозит workflow — отчёт краткий, только критичное.

---

## B. New Commands

### B1. `/forge:status` — Быстрый статус проекта
Показывает текущее состояние из docs/index.yml одной строкой.

```
/forge:status
→ "CAME BOT: фаза 2/4, бизнес-логика выдачи ключей. Блокер: нет."
```

Простая команда, не требует субагентов — просто читает и форматирует.

---

### B2. `/forge:switch [project]` — Переключение между проектами
Сохраняет текущий контекст, загружает контекст другого проекта.

```
/forge:switch yarick
→ Сохраняет session в docs/index.yml текущего проекта
→ cd /path/to/yarick
→ Загружает docs/index.yml YARICK
→ "YARICK: последняя сессия 3 дня назад. Walk-forward тест XGBoost. Продолжить?"
```

Решает проблему: 4 проекта параллельно, контекст-переключение убивает продуктивность.

---

### B3. `/forge:research [topic]` — Делегированный ресёрч
Запускает research-агент (WebSearch + WebFetch) на указанную тему, возвращает структурированный отчёт.

```
/forge:research Сравни комиссии FunPay vs GGSEL для цифровых товаров
→ Структурированный отчёт с go/no-go рекомендацией
```

**Отличие от обычного поиска:** Агент работает в изолированном контексте, не загрязняет основную сессию. Возвращает только результат.

---

### B4. `/forge:improve-skill` — Auto Research для скиллов
Автоматический цикл улучшения промпта скилла через eval-тестирование.

**Механика:**
1. Указываешь скилл + набор eval-кейсов (бинарные: Да/Нет)
2. Скилл запускается N раз на тестовых промптах
3. Каждый результат оценивается subagent-evaluator-ом автоматически
4. ИИ анализирует паттерны неудач и переписывает промпт
5. Повторяет до целевого показателя или лимита итераций

**Правила:**
- Только бинарные метрики (шкалы 1-7 дают мат. погрешность на дистанции)
- Не ставить слишком узкие рамки — ИИ начинает "читерить" ради теста
- Git diff между итерациями для истории

**Экономика:** ~$10 за 50 итераций → промпт с 95%+ pass rate.

---

### B5. `/forge:visualize` — Интерактивная диаграмма проекта
Генерирует HTML с React Flow — бизнес-логика проекта как n8n-схема.

**Алгоритм:**
1. Читает docs/ (НЕ исходный код, если не попросят)
2. Извлекает компоненты, потоки данных, условия
3. Показывает JSON-структуру на утверждение
4. Генерирует один HTML-файл

**Типы нод (цветовая кодировка):**
- external (синий) — API, внешние сервисы
- process (зелёный) — внутренние процессы
- decision (жёлтый) — условия, ветвления
- storage (фиолетовый) — БД, файлы, кэш
- user (оранжевый) — точка входа пользователя
- error (красный) — обработка ошибок
- background (серый) — фоновые задачи

**Фичи:** Автолейаут (dagre), кликабельные ноды с деталями, группировка по процессам, зум/пан, мини-карта, тёмная тема, русский язык.

**Полная спецификация:** ideas/SKILL.md (сохранить как reference).

---

## C. New Agents

### C1. Adversarial Reviewer — "Адвокат дьявола"
Агент, который целенаправленно пытается СЛОМАТЬ код.

**Отличие от code-reviewer:**
- code-reviewer ищет проблемы по чеклисту
- adversarial-reviewer активно атакует: edge cases, race conditions, неожиданный input, ресурсные лимиты, malformed data

**Реализация:** `agents/adversarial-reviewer.md`, опциональный шаг в subagent-driven-development (после code review, перед merge).

---

### C2. Agent Builder — Генератор агентов
Мета-агент: описываешь проблему на естественном языке → получаешь готового агента.

```
"Мне нужен агент который мониторит остатки ключей и алертит когда < 10"
→ Генерирует: agents/inventory-monitor.md + hooks + skill
```

Вместо поиска готового — создаёшь кастомного под задачу. Production-ready выход.

---

## D. New Skills

### D1. Quality Gate — Автоматические проверки
Скилл, объединяющий все проверки качества в один gate перед merge/completion:

- [ ] Тесты проходят
- [ ] Нет секретов в коде (regex scan)
- [ ] Type hints на новых функциях
- [ ] Нет TODO без issue-ссылки
- [ ] Documentation обновлена (если менялся public API)
- [ ] Нет N+1 запросов (если менялись ORM-запросы)

**Триггер:** Автоматически перед finishing-a-development-branch.

---

### D2. Self-Improving Agent — Учится на ошибках
Записывает свои ошибки и учится на них в рамках проекта.

**Как:** После каждого фейла (тест упал, ревью отклонил) — записывает в docs/failures/ что пошло не так. Перед следующей задачей — проверяет failures/ на похожие ситуации.

**Отличие от dead-ends:** dead-ends — ручной список "не делай X". Self-improving — автоматический цикл: фейл → запись → проверка → предотвращение.

---

### D3. Skill Analytics — Трекинг эффективности
Логирование использования скиллов и результатов.

**Что трекать:**
- Какой скилл, когда, контекст
- Результат: успех / откат / ручное вмешательство
- Категоризация: autofix (фейлит) → autoimprove (можно лучше) → autolearn (стабилен)

**Хранение:** `docs/skill-analytics.yml`

**Применение:** "Скилл X фейлит в 40% — рекомендуется /forge:improve-skill".

---

## E. Memory System Expansion

### E1. Structured Directories
Расширить текущую систему docs/ дополнительными директориями:

```
docs/
├── failures/                    ← что НЕ сработало и почему (богаче чем dead-ends)
│   └── YYYY-MM-DD-description.yml
├── learnings/                   ← инсайты, находки, API-лимиты
│   └── YYYY-MM-DD-topic.yml
└── blockers/                    ← что мешает прямо сейчас
    └── YYYY-MM-DD-description.yml
```

**failures/ формат:**
```yaml
context: "Что пытались сделать"
tried: "Какое решение применили"
why_failed: "Почему не сработало"
replacement: "Что сделали вместо"
lesson: "Урок на будущее"
tags: [performance, api, architecture]
```

**Отличие от dead-ends:**
- dead-ends = краткий индекс "не делай X" (L1, одна строка)
- failures = полный контекст для обучения (L2, отдельный файл с деталями)

**learnings/ формат:**
```yaml
category: API | Performance | Data | Infrastructure | Business
finding: "Яндекс Маркет API: лимит 100 req/min"
how_to_apply: "Добавлять rate limiter при работе с YM API"
```

**blockers/ формат:**
```yaml
blocks: "Что не может продвинуться"
severity: Critical | High | Medium
description: "Что мешает"
solutions: ["Вариант 1", "Вариант 2"]
status: Open | In Progress | Resolved
```

---

### E2. patterns.yml — Авто-обнаруженные паттерны
**Отличие от conventions.yml:**
- conventions = правила, установленные человеком ("используй snake_case")
- patterns = паттерны, обнаруженные в коде ("все API handlers возвращают `{ok: bool, data: ...}`")

**Кто пишет:** Inspector/code-reviewer при обнаружении повторяющегося паттерна. forge-documenter при sync.

---

### E3. Agent Lifecycle Protocol
Стандартизированный протокол для ВСЕХ агентов:

**При старте:**
1. Прочитай docs/index.yml
2. Просмотри docs/blockers/ — есть ли активные
3. Просмотри docs/failures/ — есть ли релевантные к задаче
4. Используй docs/conventions.yml как стандарт

**После завершения:**
1. Обнови docs/status.yml — что изменилось
2. Если решение не сработало → запиши в docs/failures/
3. Если обнаружил паттерн → запиши в docs/patterns.yml
4. Если узнал полезное → запиши в docs/learnings/

---

## F. Improvements to Existing Features

### F1. session-awareness: Context Overflow Prevention
**Проблема:** При контексте >50% модель деградирует — ломает архитектуру, дублирует код.

**Добавить правило:**
- При приближении к лимиту — принудительно сохранить состояние в docs/index.yml
- Рекомендовать /compact или новую сессию
- Перед compact — обязательно обновить session секцию

---

### F2. brainstorming: Обязательный Architecture Analysis
**Добавить чеклист перед предложением решения:**
- [ ] Какие модули затронуты?
- [ ] Какие зависимости между ними?
- [ ] Какие побочные эффекты возможны?
- [ ] Есть ли аналогичный паттерн в проекте? (conventions.yml)
- [ ] Есть ли в dead-ends/failures похожие попытки?

---

### F3. writing-skills: Security Checklist
**При создании скиллов с внешними интеграциями:**
- [ ] Минимальные необходимые права (no admin/delete без подтверждения)
- [ ] Токены/секреты в `.env`, не в коде
- [ ] Проверка стороннего кода перед запуском
- [ ] Rate limiting / backoff при работе с API
- [ ] Sandbox-режим для деструктивных операций

---

### F4. subagent-driven-development: Agent Memory
Добавить `memory: project` во frontmatter code-reviewer и forge-documenter.

**Эффект:** После 10+ ревью агент знает конвенции проекта без повторного чтения conventions.yml.

**Осторожность:** Только для регулярно используемых агентов на одном проекте.

---

### F5. executing-plans: Auto-test Hook
Автоматический запуск тестов после каждого изменения файла.

```json
{
  "event": "PostToolUse",
  "filter": { "tool": ["Edit", "Write"] },
  "command": "Если в проекте есть test runner — запусти тесты на изменённых модулях."
}
```

Агент сразу видит упавшие тесты и фиксит, не дожидаясь конца батча.

---

### F6. Экономия токенов по умолчанию
**Принцип из ADS-архитектуры:**
- Все субагенты на `model: sonnet` по умолчанию
- `model: opus` — только по явному запросу для сложной архитектуры
- Каждый вызов агента = отдельная API-сессия (10K-500K токенов)
- Простые задачи (<30 мин ручной работы) — в основной сессии, не через агента

---

## G. External Tools & Integrations (не часть плагина)

### G1. MCP-серверы для рекомендации в GUIDE
| MCP | Что делает | Установка |
|-----|-----------|-----------|
| Context7 | Актуальная документация библиотек | `claude mcp add context7 -- npx -y @upstash/context7-mcp@latest` |
| code-review-graph | Граф зависимостей, blast radius, dead code. Экономия 6-8x токенов | `pip install code-review-graph` |
| hex-line | Hash-verified editing — защита от stale edits | `npm i -g @levnikolaevich/hex-line-mcp` |
| hex-graph | Code knowledge graph через tree-sitter | `npm i -g @levnikolaevich/hex-graph-mcp` |
| airis-mcp-gateway | Мультиплексер MCP — 60+ тулов за 7 мета-тулами, -97% контекст | Docker |
| n8n-MCP | Управление n8n workflows из Claude Code | Когда нужна автоматизация |
| next-devtools-mcp | Real-time Next.js debugging | `npx -y next-devtools-mcp@latest` |

### G2. Skill Collections для рекомендации
| Коллекция | Что | Когда |
|-----------|-----|-------|
| Claude Scientific Skills (125+ ML) | ML best practices, walk-forward, XGBoost | ML-проекты |
| ClaudeKit web-dev-tools | Next.js, Tailwind, shadcn/ui, Puppeteer | Веб-проекты |
| HuggingFace Official Skills | Datasets, model training, experiment tracking | ML с HF |
| alirezarezvani/claude-skills | senior-architect, self-improving-agent | Архитектура |

### G3. External Systems
| Система | Что | Статус |
|---------|-----|--------|
| Claude Mem (39.6K stars) | SQLite memory + full-text search + auto-compress | Альтернатива session-awareness |
| Agent Teams | Параллельные сессии Claude Code как команда | Экспериментальная фича CC |
| Claude Squad | Терминал для управления параллельными сессиями | Внешний тул |
| AgentSys | Task-to-production pipelines, drift detection | Внешняя система |
| agnix | Линтер для CLAUDE.md, AGENTS.md, SKILL.md | Полезный тул |
| LightRAG (31.5K stars) | Knowledge graph + RAG для базы знаний | Когда нужен RAG |

---

## H. Practices & Principles

### H1. "Не ставь 40 агентов сразу"
Claude сканирует все .md в agents/ при старте. 30 файлов = лишние токены. Начинать с ядра, добавлять по необходимости.

### H2. "План ПЕРЕД выполнением"
Foreman ПОКАЗЫВАЕТ декомпозицию и ЖДЁТ подтверждения. Никогда не запускает выполнение без аппрува. Автоматизировать исполнение — да. Решения — нет.

### H3. "Память переживает сессии"
Всё в docs/ коммитится в git. Каждая сессия начинается с загрузки, заканчивается обновлением. Состояние проекта НИКОГДА не теряется.

### H4. "Один агент = одна роль"
Не дублировать: не нужны fullstack + backend + python-pro одновременно. Foreman выберет нужного.

### H5. "Не игнорируй Inspector"
Соблазнительно отключить ревью "для скорости". Именно в эти моменты появляются баги.

### H6. "Бинарные метрики для eval"
При тестировании скиллов — только Да/Нет. Шкалы (1-7) создают иллюзию точности и мат. погрешность.

### H7. "Скиллы могут конфликтовать"
Два скилла с противоположными инструкциями = Claude запутается. Не ставить два "frontend" скилла.

### H8. Backup конфигов перед экспериментами
```bash
cp -r ~/.claude ~/.claude.backup
```
