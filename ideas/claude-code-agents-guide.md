# Агенты и субагенты для Claude Code — Полный гайд

---

## КАК РАБОТАЮТ АГЕНТЫ — ЧТОБЫ БЫЛО ПОНЯТНО

Агент — это .md файл в `~/.claude/agents/` (глобально) или `.claude/agents/` (в проекте).
Внутри файла: имя, описание когда вызывать, какие инструменты доступны, и длинная инструкция кто он и как работать.

Когда ты пишешь в Claude Code "используй @python-pro" — Claude запускает **отдельную сессию** со своим контекстом и инструкциями из этого файла. Агент работает, возвращает результат, и сессия закрывается.

**Ключевое отличие от скиллов**: скилл расширяет знания Claude внутри твоей сессии. Агент — это отдельный "работник" с отдельным контекстом. Он не видит твою переписку, получает только задачу.

**Три встроенных типа агентов** (уже есть в Claude Code):
- **Explore** — только читает файлы, ищет по кодбейзу. Не может ничего менять. Быстрый.
- **Plan** — анализирует и создаёт планы реализации. Не пишет код.
- **General-purpose** — полный доступ: читает, пишет, выполняет bash. Самый мощный и дорогой.

**Уровни доступа у кастомных агентов**:
- `Read, Grep, Glob` — только смотрит (ревьюеры, аудиторы)
- `+ WebFetch, WebSearch` — смотрит + ищет в интернете (исследователи)
- `+ Write, Edit, Bash` — полный доступ (разработчики)

---

## ГЛАВНЫЕ ИСТОЧНИКИ

### VoltAgent/awesome-claude-code-subagents
- 127+ агентов, 10 категорий
- 13K звёзд на GitHub
- Каждый агент — один .md файл, ставится за 2 секунды
- **Лучший выбор для начала**
- https://github.com/VoltAgent/awesome-claude-code-subagents

### wshobson/agents (claude-code-workflows)
- 182 агента + 16 оркестраторов + 75 плагинов
- Ставится через `/plugin marketplace`
- Включает Conductor — систему управления разработкой
- https://github.com/wshobson/agents

### avivl/claude-007-agents
- 112 агентов + Task Master
- Bootstrap-orchestrator автоматически настраивает агентов под проект
- https://github.com/avivl/claude-007-agents

### hesreallyhim/awesome-claude-code
- Курированный список с авторскими обзорами (не просто ссылки, а оценки)
- https://github.com/hesreallyhim/awesome-claude-code

---

## АГЕНТЫ ДЛЯ РАЗРАБОТКИ (универсальные)

### python-pro
**Источник**: VoltAgent → 02-language-specialists
**Что реально делает**: Senior Python-разработчик. Знает Python 3.11+, async/await, type hints, dataclasses, pattern matching. Пишет с типизацией, обработкой ошибок, тестами. Понимает web (FastAPI, Django), data science (pandas, numpy), и автоматизацию.
**Когда вызывать**: Нужно написать production-quality Python-код с правильной структурой, а не "лишь бы работало".
**Пример**: "Используй @python-pro — отрефакторь модуль обработки заказов CAME BOT: добавь типизацию, async, обработку ошибок API маркетплейса, retry-логику"
**Инструменты**: Read, Write, Edit, Bash, Glob, Grep
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/02-language-specialists/python-pro.md \
  -o ~/.claude/agents/python-pro.md
```

### backend-developer
**Источник**: VoltAgent → 01-core-development
**Что реально делает**: Проектирует и пишет серверную часть: API, базы данных, аутентификация, очереди задач, кэширование. Думает о масштабируемости, безопасности, производительности.
**Когда вызывать**: Когда создаёшь новый сервис или API с нуля, и нужно правильно спроектировать структуру.
**Пример**: "Используй @backend-developer — спроектируй и реализуй backend для CAME BOT: эндпоинты для получения заказов, управления ключами, интеграция с API Яндекс Маркета"
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/01-core-development/backend-developer.md \
  -o ~/.claude/agents/backend-developer.md
```

### frontend-developer
**Источник**: VoltAgent → 01-core-development
**Что реально делает**: UI/UX специалист — React, Vue, Angular. Знает компонентный подход, state management, адаптивный дизайн, доступность, оптимизацию производительности.
**Когда вызывать**: Лендинги для Upwork, дашборды для CAME BOT, любой фронтенд.
**Пример**: "Используй @frontend-developer — создай дашборд для мониторинга продаж CAME BOT: график продаж по дням, остатки ключей, статусы заказов"
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/01-core-development/frontend-developer.md \
  -o ~/.claude/agents/frontend-developer.md
```

### api-designer
**Источник**: VoltAgent → 01-core-development
**Что реально делает**: Проектирует API как продукт — REST и GraphQL. Схемы данных, версионирование, пагинация, обработка ошибок, документация OpenAPI/Swagger.
**Когда вызывать**: Перед тем как писать API — чтобы получить правильную спецификацию.
**Пример**: "Используй @api-designer — спроектируй REST API для VPN-сервиса: регистрация пользователей, управление подписками, генерация ключей Marzban"
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/01-core-development/api-designer.md \
  -o ~/.claude/agents/api-designer.md
```

### sql-pro
**Источник**: VoltAgent → 02-language-specialists
**Что реально делает**: Эксперт по SQL — сложные запросы, оптимизация, индексирование, миграции, проектирование схем. PostgreSQL, MySQL, SQLite.
**Когда вызывать**: Когда база тормозит, нужно спроектировать схему, или написать сложный аналитический запрос.
**Пример**: "Используй @sql-pro — спроектируй схему БД для YARICK: таблицы матчей, коэффициентов, предсказаний, результатов ставок. Оптимизируй под аналитические запросы."
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/02-language-specialists/sql-pro.md \
  -o ~/.claude/agents/sql-pro.md
```

### nextjs-developer
**Источник**: VoltAgent → 02-language-specialists
**Что реально делает**: Next.js 14+ специалист — App Router, Server Components, SSR/SSG/ISR, API Routes, middleware. Знает экосистему: Prisma, tRPC, NextAuth.
**Когда вызывать**: Любой проект на Next.js — Upwork задачи, сайт для КОДХАБ.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/02-language-specialists/nextjs-developer.md \
  -o ~/.claude/agents/nextjs-developer.md
```

---

## АГЕНТЫ ДЛЯ ML И ДАННЫХ (YARICK)

### data-scientist
**Источник**: VoltAgent → 05-data-ai
**Что реально делает**: Полный цикл data science. Знает XGBoost, LightGBM, scikit-learn, StatsModels. Умеет: EDA, feature engineering, кросс-валидация, Bayesian optimization гиперпараметров, causal inference, A/B тесты. Визуализация через Plotly/Seaborn.
**Когда вызывать**: Исследовательская работа с данными для YARICK — проверить гипотезу, попробовать фичи, оценить модель.
**Пример**: "Используй @data-scientist — проанализируй датасет OU2.5 за 2020-2024: корреляции между лигами, сезонность, стабильность коэффициентов. Предложи топ-10 фичей для XGBoost."
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/05-data-ai/data-scientist.md \
  -o ~/.claude/agents/data-scientist.md
```

### data-analyst
**Источник**: VoltAgent → 05-data-ai
**Что реально делает**: Бизнес-аналитик данных — SQL, дашборды, KPI, визуализация. Переводит данные в бизнес-инсайты. Менее "научный" чем data-scientist, более "прикладной".
**Когда вызывать**: Анализ продаж CAME BOT, unit-экономика, дашборды.
**Пример**: "Используй @data-analyst — проанализируй продажи за последний месяц: средний чек, конверсия по категориям, маржинальность с учётом комиссии маркетплейса"
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/05-data-ai/data-analyst.md \
  -o ~/.claude/agents/data-analyst.md
```

### data-researcher
**Источник**: VoltAgent → 10-research-analysis
**Что реально делает**: Ищет данные из множества источников, чистит, анализирует, находит паттерны. Строит предиктивные модели. Генерирует дашборды.
**Когда вызывать**: Нужно собрать и проанализировать данные из разных мест — парсинг + анализ.
**Пример**: "Используй @data-researcher — собери и сравни данные по покрытию лиг на football-data.co.uk vs Polymarket: какие лиги есть на обоих, где пробелы"
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/10-research-analysis/data-researcher.md \
  -o ~/.claude/agents/data-researcher.md
```

---

## АГЕНТЫ ДЛЯ КАЧЕСТВА КОДА

### code-reviewer (встроенный в несколько коллекций)
**Что реально делает**: Ревьюит код по чеклисту: баги, безопасность, производительность, читаемость, соответствие стандартам проекта. Не просто "выглядит ок", а структурированный анализ.
**Когда вызывать**: Перед коммитом — отправляешь изменения на ревью агенту.
**Пример**: "Используй @code-reviewer — проверь последние изменения в модуле оплаты на баги, уязвимости, и нарушения конвенций проекта"

### debugger / systematic-debugger
**Источник**: obra (VoltAgent/awesome-agent-skills)
**Что реально делает**: Методичная отладка по алгоритму: воспроизвести → изолировать → найти корневую причину → починить → верифицировать. Не "попробуем поменять строчку", а инженерный подход с гипотезами.
**Когда вызывать**: Что-то сломалось и непонятно почему. Особенно полезно для багов которые воспроизводятся нестабильно.
**Пример**: "Используй @systematic-debugger — бот иногда не получает уведомления о заказах с маркетплейса. Частота: ~5% заказов. Логи прилагаю."

### test-engineer (из wshobson/agents или alirezarezvani)
**Что реально делает**: Пишет тесты — unit, integration, e2e. Покрывает edge cases, обработку ошибок, граничные условия. Знает pytest, jest, Playwright.
**Когда вызывать**: После написания фичи — делегируешь ему написание тестов.
**Пример**: "Используй @test-engineer — напиши тесты для модуля выдачи ключей: успешная выдача, ключ не найден, невалидный заказ, дублирование, таймауты API"

---

## АГЕНТЫ ДЛЯ ИНФРАСТРУКТУРЫ

### devops-engineer
**Источник**: VoltAgent → 03-infrastructure
**Что реально делает**: CI/CD, автоматизация деплоя, мониторинг, логирование. Docker, Nginx, systemd, bash-скрипты для автоматизации.
**Когда вызывать**: Настройка серверов для VPN, автоматический деплой CAME BOT.
**Пример**: "Используй @devops-engineer — настрой автоматический деплой CAME BOT: push в main → тесты → деплой на сервер → healthcheck → откат если сломалось"
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/03-infrastructure/devops-engineer.md \
  -o ~/.claude/agents/devops-engineer.md
```

### docker-expert
**Источник**: VoltAgent → 03-infrastructure
**Что реально делает**: Docker-контейнеризация — оптимальные Dockerfile, multi-stage builds, docker-compose, сети, volumes, безопасность. Уменьшает размер образов, ускоряет сборку.
**Когда вызывать**: Контейнеризация проектов, оптимизация Docker-конфигов.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/03-infrastructure/docker-expert.md \
  -o ~/.claude/agents/docker-expert.md
```

### database-administrator
**Источник**: VoltAgent → 03-infrastructure
**Что реально делает**: Администрирование БД — бэкапы, репликация, мониторинг, оптимизация запросов, миграции, security. PostgreSQL, MySQL, Redis, MongoDB.
**Когда вызывать**: База тормозит, нужен бэкап-план, или настройка репликации.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/03-infrastructure/database-administrator.md \
  -o ~/.claude/agents/database-administrator.md
```

### security-engineer
**Источник**: VoltAgent → 03-infrastructure
**Что реально делает**: Аудит безопасности — OWASP Top 10, проверка зависимостей, XSS/SQL injection, secrets management, hardening серверов.
**Когда вызывать**: Перед релизом или когда работаешь с деньгами/данными пользователей (VPN, CAME BOT).
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/03-infrastructure/security-engineer.md \
  -o ~/.claude/agents/security-engineer.md
```

---

## АГЕНТЫ ДЛЯ РЕСЁРЧА И БИЗНЕСА

### research-analyst
**Источник**: VoltAgent → 10-research-analysis
**Что реально делает**: Глубокий ресёрч — собирает информацию, синтезирует, оценивает достоверность, генерирует структурированный отчёт. Работает с WebSearch и WebFetch.
**Когда вызывать**: Нужно разобраться в теме перед принятием решения.
**Пример**: "Используй @research-analyst — исследуй текущее состояние Polymarket: какие рынки есть для футбола, ликвидность, комиссии, ограничения для российских пользователей"
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/10-research-analysis/research-analyst.md \
  -o ~/.claude/agents/research-analyst.md
```

### competitive-analyst
**Источник**: VoltAgent → 10-research-analysis
**Что реально делает**: Конкурентная разведка — анализ конкурентов, их продуктов, ценообразования, маркетинга. SWOT-анализ, позиционирование.
**Когда вызывать**: Перед выходом на новый рынок — FunPay vs GGSEL vs Яндекс Маркет.
**Пример**: "Используй @competitive-analyst — сравни площадки для продажи цифровых товаров в РФ: Яндекс Маркет, FunPay, GGSEL, Plati. Комиссии, аудитория, ограничения, сложность входа"
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/10-research-analysis/competitive-analyst.md \
  -o ~/.claude/agents/competitive-analyst.md
```

### project-idea-validator
**Источник**: VoltAgent → 10-research-analysis
**Что реально делает**: Жёсткий критик идей. Оценивает: рынок, конкуренция, unit-экономика, сроки реализации, технические риски. Даёт go/no-go с обоснованием. НЕ льстит.
**Когда вызывать**: Перед тем как начинать новый проект — фильтр.
**Пример**: "Используй @project-idea-validator — оцени идею: VPN-сервис для РФ на базе Marzban, подписка 200₽/мес, дистрибуция через Влада. Стартовый бюджет 0, есть VPS."
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/10-research-analysis/project-idea-validator.md \
  -o ~/.claude/agents/project-idea-validator.md
```

### trend-analyst
**Источник**: VoltAgent → 10-research-analysis
**Что реально делает**: Анализ трендов — emerging technologies, рыночные тренды, прогнозирование. Мониторинг направлений.
**Когда вызывать**: Стратегические решения — куда двигаться дальше.
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/10-research-analysis/trend-analyst.md \
  -o ~/.claude/agents/trend-analyst.md
```

---

## ОРКЕСТРАТОРЫ — АГЕНТЫ КОТОРЫЕ УПРАВЛЯЮТ АГЕНТАМИ

### Conductor (wshobson/agents)
**Что реально делает**: Превращает Claude Code в систему управления проектами. Цикл: опиши контекст проекта → Claude генерирует спецификацию → разбивает на фазы (tracks) → реализует с TDD и checkpoint-ами. **Сохраняет состояние между сессиями.**
**Зачем тебе**: Решает твою проблему "теряю контекст проекта". Conductor помнит где ты остановился.
**Команды**:
- `/conductor:setup` — начальная настройка (vision, стек, правила)
- `/conductor:new-track` — создать новый трек разработки
- `/conductor:implement` — реализация с верификацией
- `/conductor:revert` — откат по логической единице
```bash
/plugin marketplace add wshobson/agents
/plugin install conductor@claude-code-workflows
```

### workflow-orchestrator (VoltAgent → 09-meta-orchestration)
**Что реально делает**: Координирует сложные workflow — разбивает задачу на подзадачи, назначает каждую подходящему агенту, следит за выполнением.
**Когда вызывать**: Большая фича которая затрагивает несколько слоёв (API + фронт + тесты + деплой).
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/09-meta-orchestration/workflow-orchestrator.md \
  -o ~/.claude/agents/workflow-orchestrator.md
```

### agent-installer (VoltAgent → 09-meta-orchestration)
**Что реально делает**: Мета-агент — через Claude Code ищет и ставит других агентов из каталога VoltAgent. Вместо того чтобы курлить каждый файл вручную.
**Как использовать**: "Покажи доступные категории агентов" → "Установи data-scientist глобально"
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/09-meta-orchestration/agent-installer.md \
  -o ~/.claude/agents/agent-installer.md
```

### Agent Teams (встроенный в Claude Code)
**Что это**: Экспериментальная фича — несколько Claude Code сессий работают параллельно как команда. Один лид, несколько тиммейтов, общий task list.
**Включить**: `"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": true` в settings.json
**Когда полезно**: Параллельный ресёрч, разработка нескольких независимых частей одновременно.
**Когда НЕ полезно**: Последовательные задачи, мелкие правки. Жрёт много токенов.

---

## ВНЕШНИЕ АГЕНТНЫЕ СИСТЕМЫ (уровень выше)

### Claude Squad
**Что это**: Терминальное приложение — управляет несколькими Claude Code сессиями параллельно в отдельных workspace-ах.
**Зачем**: Работа над 3 проектами одновременно — CAME BOT в одном workspace, YARICK в другом, VPN в третьем.
**GitHub**: https://github.com/smtg-ai/claude-squad

### AgentSys (avifenesh)
**Что это**: Система автоматизации workflow — task-to-production пайплайны, PR management, code cleanup, drift detection, multi-agent code review.
**Зачем**: Если хочешь автоматизировать весь процесс от задачи до pull request-а.
**GitHub**: https://github.com/avifenesh/AgentSys

### Ruflo (ruvnet)
**Что это**: Платформа оркестрации мульти-агентных swarm-ов. Агенты организуются в рои с "королевой" которая координирует работу. Self-learning — запоминает успешные паттерны.
**Зачем**: Overkill для соло-разработки, но если масштабируешься — мощнее всего.
**GitHub**: https://github.com/ruvnet/ruflo

---

## ЧТО СТАВИТЬ — МИНИМАЛЬНЫЙ НАБОР

### Шаг 1: agent-installer (1 минута)
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/09-meta-orchestration/agent-installer.md \
  -o ~/.claude/agents/agent-installer.md
```
Дальше ставишь остальных агентов через него прямо из Claude Code.

### Шаг 2: Ядро для всех проектов (через agent-installer)
- `python-pro` — весь Python-код
- `backend-developer` — серверная часть
- `sql-pro` — базы данных
- `research-analyst` — ресёрч

### Шаг 3: Для YARICK
- `data-scientist` — ML, модели, анализ
- `data-researcher` — сбор и чистка данных

### Шаг 4: Для CAME BOT
- `data-analyst` — аналитика продаж
- `competitive-analyst` — сравнение площадок
- `project-idea-validator` — оценка новых направлений

### Шаг 5: Для качества
- `code-reviewer` — ревью перед коммитами
- `security-engineer` — аудит безопасности
- `devops-engineer` — CI/CD, деплой

### Шаг 6: Оркестрация
```bash
/plugin marketplace add wshobson/agents
/plugin install conductor@claude-code-workflows
```

---

## СТОИМОСТЬ (токены)

Каждый вызов агента = отдельная API-сессия:
- Простая задача (ревью, анализ): 10-50K токенов
- Средняя (написать модуль): 50-200K токенов  
- Сложная (архитектура + реализация): 200-500K токенов

По умолчанию агенты VoltAgent используют Sonnet (дешевле). Можно поменять в frontmatter агента:
```yaml
model: sonnet    # дешевле, для большинства задач
model: opus      # дороже, для сложных задач
model: inherit   # использует модель из основной сессии
```

**Рекомендация**: начинай с Sonnet, переключай на Opus только для архитектурных задач.
