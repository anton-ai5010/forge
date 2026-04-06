# Каталог агентов и субагентов для Claude Code
## Полная инвентаризация для сборки кастомного плагина

> Цель: собрать в одном месте ВСЕ найденные агенты, инструменты и системы оркестрации.
> Антон разберёт на компоненты и соберёт свой плагин из лучших частей.

---

## АРХИТЕКТУРА АГЕНТНОЙ ЭКОСИСТЕМЫ

```
┌─────────────────────────────────────────────────────┐
│                   ОРКЕСТРАЦИЯ                        │
│  Conductor · Agent Teams · Kanbaii · Ralph · cc-best │
├─────────────────────────────────────────────────────┤
│                   МЕТА-АГЕНТЫ                        │
│  agent-builder · agent-installer · workflow-orchestr │
│  claude-as-mcp · airis-mcp-gateway                   │
├────────────┬────────────┬───────────┬───────────────┤
│  РАЗРАБОТКА │    DATA/ML  │  ИНФРА    │   РЕСЁРЧ     │
│  python-pro │ data-scient │ devops    │ research-ana │
│  backend    │ data-analys │ docker    │ competitive  │
│  frontend   │ data-resear │ security  │ idea-validat │
│  api-design │ ml-engineer │ dba       │ trend-analys │
│  sql-pro    │ nlp-special │ network   │ market-resea │
│  nextjs     │ prompt-eng  │ incident  │ search-spec  │
├────────────┴────────────┴───────────┴───────────────┤
│                КАЧЕСТВО И КОНТРОЛЬ                    │
│  code-reviewer · test-engineer · systematic-debugger │
│  security-auditor · claude-devtools · auto-context   │
└─────────────────────────────────────────────────────┘
```

---

## 1. АВТОНОМНЫЕ СИСТЕМЫ РАЗРАБОТКИ

### Kanbaii
- **Суть**: AI-native kanban доска интегрированная с Claude Code
- **Что делает**: Визуальное планирование задач → AI автономно выполняет каждую. Два режима: Sequential (Ralph engine — задачи по очереди) и Parallel (Agent Teams — несколько агентов одновременно). Real-time дашборд с трекингом стоимости токенов.
- **Запуск**: `npx kanbaii start`
- **Применение**: Любой проект где есть набор задач — вместо списка в голове получаешь визуальную доску где AI сам двигает карточки.

### Ralph
- **Суть**: Автономная петля — получает PRD, работает пока не сделает ВСЁ
- **Что делает**: Берёт описание продукта (PRD), декомпозирует на задачи, выполняет одну за другой. Если задача падает — анализирует ошибку, чинит, продолжает. Работает пока список не пустой.
- **Применение**: "Запустил и ушёл" — описал фичу на 2 страницы, ушёл на 4 часа, вернулся к готовому коду.

### cc-best
- **Суть**: Полная команда разработки в одном плагине
- **Что делает**: PM создаёт спецификацию → Lead декомпозирует → Dev реализует → QA проверяет. Автономный workflow с auto-learning pipeline — каждая ошибка записывается и учитывается в будущем. 40 команд, 17 скиллов, 8 агентов, 33 правила, 21 хук.
- **GitHub**: Тег `claude-code-agents` на GitHub
- **Применение**: Автономная разработка фичей без постоянного контроля.

### Conductor (wshobson/agents)
- **Суть**: Система управления разработкой с сохранением состояния
- **Что делает**: `/conductor:setup` — описываешь проект (vision, стек, правила). `/conductor:new-track` — Claude создаёт спецификацию и план по фазам. `/conductor:implement` — реализация с TDD и checkpoint-ами. `/conductor:revert` — откат по логической единице. Состояние сохраняется между сессиями.
- **Установка**: `/plugin marketplace add wshobson/agents` → `/plugin install conductor@claude-code-workflows`
- **Применение**: Решение проблемы "теряю контекст проекта". Conductor помнит где ты остановился.

---

## 2. МЕТА-АГЕНТЫ (создают/управляют другими агентами)

### agent-builder
- **Суть**: Генератор агентов из natural language
- **Что делает**: Описываешь проблему → он анализирует, исследует best practices, генерирует: субагента (.md), скиллы, хуки, команды, MCP-конфиги. Production-ready.
- **GitHub**: Тег `claude-code-agents`, 29 звёзд
- **Применение**: Вместо поиска готового агента — создаёшь кастомного под задачу. "Мне нужен агент который мониторит остатки ключей в CAME BOT и алертит когда < 10".

### agent-installer (VoltAgent)
- **Суть**: Браузер/установщик агентов из каталога VoltAgent
- **Что делает**: Через Claude Code ищет агентов по категориям, показывает описания, устанавливает глобально или в проект.
- **Установка**:
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/09-meta-orchestration/agent-installer.md \
  -o ~/.claude/agents/agent-installer.md
```
- **Применение**: Точка входа — через него ставишь всех остальных.

### workflow-orchestrator (VoltAgent)
- **Суть**: Координатор сложных workflow
- **Что делает**: Разбивает большую задачу на подзадачи, назначает каждую подходящему агенту, следит за выполнением, собирает результат.
- **Установка**:
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/09-meta-orchestration/workflow-orchestrator.md \
  -o ~/.claude/agents/workflow-orchestrator.md
```
- **Применение**: "Сделай новый модуль оплаты" → оркестратор назначает: api-designer → backend-developer → test-engineer → code-reviewer.

### claude-as-mcp (Peter Steinberger)
- **Суть**: Claude Code как MCP-сервер — агент внутри агента
- **Что делает**: Запускает Claude Code как one-shot MCP-сервер. Основная сессия вызывает вложенного Claude для подзадачи. Permissions обходятся автоматически.
- **GitHub**: 1100+ звёзд
- **Применение**: Глубокая вложенность — основной агент делегирует подзадачу другому Claude.

### airis-mcp-gateway
- **Суть**: Мультиплексер MCP-серверов
- **Что делает**: Агрегирует 60+ инструментов за 7 мета-инструментами. Сокращает использование токенов контекста на 97%. Одна команда Docker для запуска, автоматически включает серверы по запросу.
- **Применение**: Если у тебя 10+ MCP-серверов (Context7, hex-line, code-review-graph, GitHub, etc.) — они все жрут контекст. Gateway прячет их за фасадом.

---

## 3. РАЗРАБОТКА — ЯЗЫКИ И ФРЕЙМВОРКИ

### python-pro
- **Источник**: VoltAgent → 02-language-specialists
- **Экспертиза**: Python 3.11+, async/await, type hints, dataclasses, pattern matching. Web (FastAPI, Django), data science (pandas, numpy), автоматизация.
- **Инструменты**: Read, Write, Edit, Bash, Glob, Grep
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/02-language-specialists/python-pro.md \
  -o ~/.claude/agents/python-pro.md
```

### backend-developer
- **Источник**: VoltAgent → 01-core-development
- **Экспертиза**: Серверная архитектура, API, базы данных, аутентификация, очереди, кэширование. Масштабируемость и безопасность.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/01-core-development/backend-developer.md \
  -o ~/.claude/agents/backend-developer.md
```

### frontend-developer
- **Источник**: VoltAgent → 01-core-development
- **Экспертиза**: React, Vue, Angular. Компоненты, state management, адаптивность, доступность, performance.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/01-core-development/frontend-developer.md \
  -o ~/.claude/agents/frontend-developer.md
```

### fullstack-developer
- **Источник**: VoltAgent → 01-core-development
- **Экспертиза**: End-to-end разработка — от БД до UI. Понимает как слои взаимодействуют.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/01-core-development/fullstack-developer.md \
  -o ~/.claude/agents/fullstack-developer.md
```

### api-designer
- **Источник**: VoltAgent → 01-core-development
- **Экспертиза**: REST и GraphQL архитектура. Схемы, версионирование, пагинация, ошибки, OpenAPI/Swagger.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/01-core-development/api-designer.md \
  -o ~/.claude/agents/api-designer.md
```

### sql-pro
- **Источник**: VoltAgent → 02-language-specialists
- **Экспертиза**: Сложные запросы, оптимизация, индексирование, миграции, проектирование схем. PostgreSQL, MySQL, SQLite.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/02-language-specialists/sql-pro.md \
  -o ~/.claude/agents/sql-pro.md
```

### nextjs-developer
- **Источник**: VoltAgent → 02-language-specialists
- **Экспертиза**: Next.js 14+, App Router, Server Components, SSR/SSG/ISR, API Routes, middleware. Prisma, tRPC, NextAuth.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/02-language-specialists/nextjs-developer.md \
  -o ~/.claude/agents/nextjs-developer.md
```

### typescript-pro
- **Источник**: VoltAgent → 02-language-specialists
- **Экспертиза**: TypeScript advanced patterns, generics, conditional types, type guards, module augmentation.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/02-language-specialists/typescript-pro.md \
  -o ~/.claude/agents/typescript-pro.md
```

### react-specialist
- **Источник**: VoltAgent → 02-language-specialists
- **Экспертиза**: React 18+, Suspense, Server Components, hooks, concurrent features, performance optimization.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/02-language-specialists/react-specialist.md \
  -o ~/.claude/agents/react-specialist.md
```

### django-developer
- **Источник**: VoltAgent → 02-language-specialists
- **Экспертиза**: Django 4+, ORM, DRF, signals, middleware, caching, async views.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/02-language-specialists/django-developer.md \
  -o ~/.claude/agents/django-developer.md
```

### websocket-engineer
- **Источник**: VoltAgent → 01-core-development
- **Экспертиза**: Real-time коммуникация — WebSocket, SSE, long polling. Масштабирование, reconnection, heartbeat.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/01-core-development/websocket-engineer.md \
  -o ~/.claude/agents/websocket-engineer.md
```

### ui-designer
- **Источник**: VoltAgent → 01-core-development
- **Экспертиза**: Визуальный дизайн, interaction design, design systems, прототипирование.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/01-core-development/ui-designer.md \
  -o ~/.claude/agents/ui-designer.md
```

---

## 4. DATA / ML / AI

### data-scientist
- **Источник**: VoltAgent → 05-data-ai
- **Экспертиза**: Полный цикл DS — EDA, feature engineering, XGBoost/LightGBM, scikit-learn, walk-forward validation, Bayesian optimization, causal inference. Plotly/Seaborn.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/05-data-ai/data-scientist.md \
  -o ~/.claude/agents/data-scientist.md
```

### data-analyst
- **Источник**: VoltAgent → 05-data-ai
- **Экспертиза**: Business intelligence, SQL, дашборды, KPI, визуализация. Перевод данных в бизнес-инсайты.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/05-data-ai/data-analyst.md \
  -o ~/.claude/agents/data-analyst.md
```

### ai-engineer
- **Источник**: VoltAgent → 05-data-ai
- **Экспертиза**: AI-систем дизайн и деплой. Мост между research и production. Model serving, scaling, integration.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/05-data-ai/ai-engineer.md \
  -o ~/.claude/agents/ai-engineer.md
```

### ml-engineer (mlops-engineer)
- **Источник**: VoltAgent → 05-data-ai
- **Экспертиза**: ML pipelines, model monitoring, автоматизация workflow, model versioning, MLOps practices.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/05-data-ai/mlops-engineer.md \
  -o ~/.claude/agents/mlops-engineer.md
```

### nlp-specialist
- **Источник**: VoltAgent → 05-data-ai
- **Экспертиза**: Text processing, language models, sentiment analysis, NER, chatbots, linguistic analysis.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/05-data-ai/nlp-specialist.md \
  -o ~/.claude/agents/nlp-specialist.md
```

### prompt-engineer
- **Источник**: VoltAgent → 05-data-ai
- **Экспертиза**: Crafting effective prompts для AI моделей. Few-shot, chain-of-thought, system prompts, prompt optimization.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/05-data-ai/prompt-engineer.md \
  -o ~/.claude/agents/prompt-engineer.md
```

### postgresql-specialist
- **Источник**: VoltAgent → 05-data-ai
- **Экспертиза**: PostgreSQL advanced — JSONB, full-text search, partitioning, replication, PL/pgSQL, explain analyze.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/05-data-ai/postgresql-specialist.md \
  -o ~/.claude/agents/postgresql-specialist.md
```

---

## 5. ИНФРАСТРУКТУРА

### devops-engineer
- **Источник**: VoltAgent → 03-infrastructure
- **Экспертиза**: CI/CD, автоматизация деплоя, мониторинг, логирование. Docker, Nginx, systemd, GitHub Actions.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/03-infrastructure/devops-engineer.md \
  -o ~/.claude/agents/devops-engineer.md
```

### docker-expert
- **Источник**: VoltAgent → 03-infrastructure
- **Экспертиза**: Docker — оптимальные Dockerfile, multi-stage, docker-compose, сети, volumes, security. Минимизация образов.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/03-infrastructure/docker-expert.md \
  -o ~/.claude/agents/docker-expert.md
```

### database-administrator
- **Источник**: VoltAgent → 03-infrastructure
- **Экспертиза**: DBA — бэкапы, репликация, мониторинг, оптимизация, миграции, security. PostgreSQL, MySQL, Redis, MongoDB.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/03-infrastructure/database-administrator.md \
  -o ~/.claude/agents/database-administrator.md
```

### security-engineer
- **Источник**: VoltAgent → 03-infrastructure
- **Экспертиза**: OWASP Top 10, dependency scanning, secrets management, hardening, penetration testing.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/03-infrastructure/security-engineer.md \
  -o ~/.claude/agents/security-engineer.md
```

### deployment-engineer
- **Источник**: VoltAgent → 03-infrastructure
- **Экспертиза**: Автоматизация деплоя — blue/green, canary, rollback, zero-downtime.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/03-infrastructure/deployment-engineer.md \
  -o ~/.claude/agents/deployment-engineer.md
```

### network-engineer
- **Источник**: VoltAgent → 03-infrastructure
- **Экспертиза**: Сетевая инфраструктура — DNS, CDN, load balancing, VPN, firewall, SSL/TLS.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/03-infrastructure/network-engineer.md \
  -o ~/.claude/agents/network-engineer.md
```

### incident-responder
- **Источник**: VoltAgent → 03-infrastructure
- **Экспертиза**: Реагирование на инциденты — triage, root cause analysis, mitigation, post-mortem.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/03-infrastructure/incident-responder.md \
  -o ~/.claude/agents/incident-responder.md
```

---

## 6. КАЧЕСТВО И ТЕСТИРОВАНИЕ

### code-reviewer
- **Источник**: Несколько коллекций (VoltAgent 04-quality-security, wshobson, alirezarezvani)
- **Экспертиза**: Структурированный ревью — баги, безопасность, производительность, читаемость, соответствие конвенциям.
- **Фишка**: С agent memory запоминает паттерны проекта.

### systematic-debugger (obra)
- **Источник**: VoltAgent/awesome-agent-skills
- **Экспертиза**: Методичная отладка: воспроизвести → изолировать → root cause → починить → верифицировать.

### test-engineer
- **Источник**: wshobson/agents, alirezarezvani
- **Экспертиза**: Unit, integration, e2e тесты. pytest, jest, Playwright. Edge cases, error handling.

### root-cause-tracer (obra)
- **Источник**: VoltAgent/awesome-agent-skills
- **Экспертиза**: Расследование фундаментальных проблем — не симптомов, а причин.

---

## 7. РЕСЁРЧ И БИЗНЕС-АНАЛИЗ

### research-analyst
- **Источник**: VoltAgent → 10-research-analysis
- **Экспертиза**: Глубокий ресёрч, синтез информации, оценка достоверности, структурированные отчёты.
- **Инструменты**: Read, Grep, Glob, WebFetch, WebSearch
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/10-research-analysis/research-analyst.md \
  -o ~/.claude/agents/research-analyst.md
```

### competitive-analyst
- **Источник**: VoltAgent → 10-research-analysis
- **Экспертиза**: Конкурентная разведка — продукты, цены, позиционирование, SWOT.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/10-research-analysis/competitive-analyst.md \
  -o ~/.claude/agents/competitive-analyst.md
```

### market-researcher
- **Источник**: VoltAgent → 10-research-analysis
- **Экспертиза**: Рыночный анализ, потребительские инсайты, сегментация, sizing.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/10-research-analysis/market-researcher.md \
  -o ~/.claude/agents/market-researcher.md
```

### project-idea-validator
- **Источник**: VoltAgent → 10-research-analysis
- **Экспертиза**: Жёсткая оценка идей — рынок, конкуренция, unit-экономика, риски. Go/no-go.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/10-research-analysis/project-idea-validator.md \
  -o ~/.claude/agents/project-idea-validator.md
```

### trend-analyst
- **Источник**: VoltAgent → 10-research-analysis
- **Экспертиза**: Emerging technologies, рыночные тренды, прогнозирование.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/10-research-analysis/trend-analyst.md \
  -o ~/.claude/agents/trend-analyst.md
```

### data-researcher
- **Источник**: VoltAgent → 10-research-analysis
- **Экспертиза**: Data discovery, сбор из множества источников, чистка, паттерны, предиктивные модели.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/10-research-analysis/data-researcher.md \
  -o ~/.claude/agents/data-researcher.md
```

### search-specialist
- **Источник**: VoltAgent → 10-research-analysis
- **Экспертиза**: Advanced information retrieval — поиск по нестандартным источникам.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/10-research-analysis/search-specialist.md \
  -o ~/.claude/agents/search-specialist.md
```

### scientific-literature-researcher
- **Источник**: VoltAgent → 10-research-analysis
- **Экспертиза**: Поиск научных статей, evidence synthesis. PubMed, arXiv, Semantic Scholar.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/10-research-analysis/scientific-literature-researcher.md \
  -o ~/.claude/agents/scientific-literature-researcher.md
```

---

## 8. НАБЛЮДАЕМОСТЬ И КОНТРОЛЬ

### claude-devtools (matt1398)
- **Суть**: Desktop-приложение для observability Claude Code сессий
- **Что делает**: Turn-based данные контекста, визуализация compaction, деревья выполнения субагентов, триггеры уведомлений. Видишь что Claude делает, сколько токенов жрёт, где застревает.
- **GitHub**: https://github.com/matt1398/claude-devtools

### auto-context capture
- **Суть**: Автоматическое сохранение контекста между сессиями
- **Что делает**: Захватывает всё что Claude делает в сессии, сжимает AI-ом, инъектирует в будущие сессии. #1 trending GitHub Feb 2026.
- **Применение**: Решает проблему "Claude забыл что мы делали вчера".

### Agent Memory (встроенная фича Claude Code)
- **Суть**: Persistent memory для субагентов
- **Что делает**: Субагенты записывают обнаруженные паттерны, конвенции и проблемы в `.claude/memory/`. Memory шарится через git.
- **Применение**: @code-reviewer после 10 ревью проекта знает конвенции и не повторяет замечания.
- **Как включить**: Добавить `memory: project` в frontmatter агента.

---

## 9. ВНЕШНИЕ АГЕНТНЫЕ СИСТЕМЫ

### Claude Squad
- **Суть**: Терминальное приложение для параллельных Claude Code сессий
- **Что делает**: Управляет несколькими Claude Code + Codex + Aider сессиями в отдельных workspace-ах.
- **GitHub**: https://github.com/smtg-ai/claude-squad
- **Применение**: CAME BOT в одном workspace, YARICK в другом, VPN в третьем — параллельная работа.

### AgentSys (avifenesh)
- **Суть**: Workflow automation для Claude Code
- **Что делает**: Task-to-production пайплайны, PR management, code cleanup, drift detection, multi-agent code review. Включает agnix (линтер для CLAUDE.md, AGENTS.md, SKILL.md).
- **GitHub**: https://github.com/avifenesh/AgentSys

### Ruflo (ruvnet)
- **Суть**: Платформа оркестрации мульти-агентных swarm-ов
- **Что делает**: 100+ специализированных агентов в координированных роях. Self-learning — запоминает успешные паттерны в vector memory. WASM-ядро на Rust. Smart routing — простые задачи идут через дешёвые модели.
- **GitHub**: https://github.com/ruvnet/ruflo

### Agent Teams (встроенный в Claude Code)
- **Суть**: Экспериментальная мульти-агентная фича
- **Что делает**: Один лид + несколько тиммейтов, каждый в своём контексте. Общий task list, прямая коммуникация между агентами. Можно требовать план-аппрувал перед реализацией.
- **Включить**: `"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": true` в settings.json

---

## 10. СПЕЦИАЛИЗИРОВАННЫЕ СКИЛЛЫ-КОЛЛЕКЦИИ (дополнение к агентам)

### n8n workflow skills
- **Что**: 7 скиллов для production-ready n8n workflows. 525+ нод, 2653+ шаблонов.
- **Применение**: Автоматизация бизнес-процессов CAME BOT через n8n.

### Claude Scientific Skills (K-Dense-AI)
- **Что**: 125+ ML/data science скиллов — scikit-learn, PyTorch, time series, visualization.
- **Установка**: `git clone https://github.com/K-Dense-AI/claude-scientific-skills.git`

### AI-Research-Skills (Orchestra Research)
- **Что**: 70+ скиллов для AI research — архитектура моделей, файнтюнинг, mechanistic interpretability, MLOps.
- **Установка**: `npm i @orchestra-research/ai-research-skills`

### ClaudeKit web-dev-tools
- **Что**: Next.js, Tailwind, shadcn/ui, Puppeteer, Three.js скиллы.
- **Установка**: `/plugin marketplace add mrgoonie/claudekit-skills`

---

## 11. MCP-СЕРВЕРЫ (инфраструктура для агентов)

### Context7 — актуальная документация библиотек
```bash
claude mcp add context7 -- npx -y @upstash/context7-mcp@latest
```

### code-review-graph — knowledge graph кодбейза, экономия токенов
```bash
pip install code-review-graph --break-system-packages
code-review-graph install --platform claude-code
```

### hex-line — hash-verified editing, защита от stale edits
```bash
npm i -g @levnikolaevich/hex-line-mcp
claude mcp add -s user hex-line -- hex-line-mcp
```

### hex-graph — code knowledge graph через tree-sitter
```bash
npm i -g @levnikolaevich/hex-graph-mcp
claude mcp add -s user hex-graph -- hex-graph-mcp
```

### next-devtools-mcp — real-time отладка Next.js
```bash
claude mcp add next-devtools -- npx -y next-devtools-mcp@latest
```

### GitHub MCP — прямая работа с репозиториями, PR, issues
```bash
claude mcp add github -- docker run -i --rm -e GITHUB_PERSONAL_ACCESS_TOKEN ghcr.io/github/github-mcp-server
```

---

## 12. УСТАНОВОЧНЫЙ СКРИПТ — ВСЁ ОДНОЙ КОМАНДОЙ

```bash
#!/bin/bash
# ============================================
# Установка агентов для Claude Code
# ============================================

AGENTS_DIR="$HOME/.claude/agents"
mkdir -p "$AGENTS_DIR"

BASE_URL="https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories"

echo "=== Мета-агенты ==="
curl -s "$BASE_URL/09-meta-orchestration/agent-installer.md" -o "$AGENTS_DIR/agent-installer.md"
curl -s "$BASE_URL/09-meta-orchestration/workflow-orchestrator.md" -o "$AGENTS_DIR/workflow-orchestrator.md"

echo "=== Разработка ==="
curl -s "$BASE_URL/02-language-specialists/python-pro.md" -o "$AGENTS_DIR/python-pro.md"
curl -s "$BASE_URL/02-language-specialists/typescript-pro.md" -o "$AGENTS_DIR/typescript-pro.md"
curl -s "$BASE_URL/02-language-specialists/sql-pro.md" -o "$AGENTS_DIR/sql-pro.md"
curl -s "$BASE_URL/02-language-specialists/nextjs-developer.md" -o "$AGENTS_DIR/nextjs-developer.md"
curl -s "$BASE_URL/02-language-specialists/react-specialist.md" -o "$AGENTS_DIR/react-specialist.md"
curl -s "$BASE_URL/01-core-development/backend-developer.md" -o "$AGENTS_DIR/backend-developer.md"
curl -s "$BASE_URL/01-core-development/frontend-developer.md" -o "$AGENTS_DIR/frontend-developer.md"
curl -s "$BASE_URL/01-core-development/fullstack-developer.md" -o "$AGENTS_DIR/fullstack-developer.md"
curl -s "$BASE_URL/01-core-development/api-designer.md" -o "$AGENTS_DIR/api-designer.md"
curl -s "$BASE_URL/01-core-development/websocket-engineer.md" -o "$AGENTS_DIR/websocket-engineer.md"
curl -s "$BASE_URL/01-core-development/ui-designer.md" -o "$AGENTS_DIR/ui-designer.md"

echo "=== Data / ML ==="
curl -s "$BASE_URL/05-data-ai/data-scientist.md" -o "$AGENTS_DIR/data-scientist.md"
curl -s "$BASE_URL/05-data-ai/data-analyst.md" -o "$AGENTS_DIR/data-analyst.md"
curl -s "$BASE_URL/05-data-ai/ai-engineer.md" -o "$AGENTS_DIR/ai-engineer.md"
curl -s "$BASE_URL/05-data-ai/nlp-specialist.md" -o "$AGENTS_DIR/nlp-specialist.md"
curl -s "$BASE_URL/05-data-ai/prompt-engineer.md" -o "$AGENTS_DIR/prompt-engineer.md"
curl -s "$BASE_URL/05-data-ai/postgresql-specialist.md" -o "$AGENTS_DIR/postgresql-specialist.md"

echo "=== Инфраструктура ==="
curl -s "$BASE_URL/03-infrastructure/devops-engineer.md" -o "$AGENTS_DIR/devops-engineer.md"
curl -s "$BASE_URL/03-infrastructure/docker-expert.md" -o "$AGENTS_DIR/docker-expert.md"
curl -s "$BASE_URL/03-infrastructure/database-administrator.md" -o "$AGENTS_DIR/database-administrator.md"
curl -s "$BASE_URL/03-infrastructure/security-engineer.md" -o "$AGENTS_DIR/security-engineer.md"
curl -s "$BASE_URL/03-infrastructure/deployment-engineer.md" -o "$AGENTS_DIR/deployment-engineer.md"
curl -s "$BASE_URL/03-infrastructure/network-engineer.md" -o "$AGENTS_DIR/network-engineer.md"

echo "=== Ресёрч ==="
curl -s "$BASE_URL/10-research-analysis/research-analyst.md" -o "$AGENTS_DIR/research-analyst.md"
curl -s "$BASE_URL/10-research-analysis/competitive-analyst.md" -o "$AGENTS_DIR/competitive-analyst.md"
curl -s "$BASE_URL/10-research-analysis/market-researcher.md" -o "$AGENTS_DIR/market-researcher.md"
curl -s "$BASE_URL/10-research-analysis/project-idea-validator.md" -o "$AGENTS_DIR/project-idea-validator.md"
curl -s "$BASE_URL/10-research-analysis/trend-analyst.md" -o "$AGENTS_DIR/trend-analyst.md"
curl -s "$BASE_URL/10-research-analysis/data-researcher.md" -o "$AGENTS_DIR/data-researcher.md"
curl -s "$BASE_URL/10-research-analysis/search-specialist.md" -o "$AGENTS_DIR/search-specialist.md"

echo "=== MCP-серверы ==="
claude mcp add context7 -- npx -y @upstash/context7-mcp@latest 2>/dev/null || echo "Context7: установи вручную"
npm i -g @levnikolaevich/hex-line-mcp 2>/dev/null && claude mcp add -s user hex-line -- hex-line-mcp || echo "hex-line: установи вручную"

echo ""
echo "✅ Установлено $(ls $AGENTS_DIR/*.md 2>/dev/null | wc -l) агентов в $AGENTS_DIR"
echo ""
echo "Следующие шаги:"
echo "  1. В Claude Code: /plugin marketplace add wshobson/agents"
echo "  2. /plugin install conductor@claude-code-workflows"
echo "  3. Попробуй: 'Используй @python-pro чтобы...'"
```

---

## ПРЕДУПРЕЖДЕНИЯ

1. **Не ставь 30 агентов сразу**. Claude сканирует все .md в `~/.claude/agents/` при старте. 30 файлов = дополнительная нагрузка на каждый запуск. Ставь 5-10 которые нужны прямо сейчас.

2. **Конфликты имён**: Если есть агент с одинаковым именем в `~/.claude/agents/` (глобально) и `.claude/agents/` (в проекте) — проектный побеждает.

3. **Стоимость**: Каждый вызов агента = отдельная API-сессия (10K-500K токенов). Используй `model: sonnet` для экономии.

4. **Agent Memory**: Включай для агентов которые вызываются регулярно на одном проекте (code-reviewer, test-engineer). Не включай для одноразовых (project-idea-validator).

5. **Проверяй перед использованием**: Некоторые агенты из коллекций написаны кое-как. Открой .md файл, посмотри — если инструкция на 20 строк без деталей, толку мало. Хорошие агенты — 200-500 строк с чеклистами, фазами, примерами.
