# Агенты для Claude Code — Рекомендации

> **Скилл vs Агент — в чём разница?**
> - **Скилл** = инструкция. Говорит Claude "когда тебя просят про ML — делай вот так". Работает внутри твоей сессии, расширяет знания Claude.
> - **Агент** = отдельный исполнитель. Ты делегируешь ему задачу, он уходит работать в своём контексте, возвращает результат. Как нанять фрилансера на подзадачу.
>
> Агенты полезны когда: задача самостоятельная, не требует твоего контроля на каждом шаге, и может выполняться параллельно с другой работой.

---

## ИСТОЧНИКИ АГЕНТОВ

### 1. VoltAgent/awesome-claude-code-subagents
- **Что это**: 100+ готовых агентов, разложенных по категориям. Самая структурированная коллекция.
- **Как устанавливать**: Скачать один .md файл → положить в `~/.claude/agents/`
- **GitHub**: https://github.com/VoltAgent/awesome-claude-code-subagents
- **Быстрая установка всего**: 
```bash
curl -sO https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/install-agents.sh
chmod +x install-agents.sh
./install-agents.sh
```
- **Или отдельный агент**:
```bash
# Пример: ставим data-scientist
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/05-data-ai/data-scientist.md \
  -o ~/.claude/agents/data-scientist.md
```

### 2. wshobson/agents (claude-code-workflows)
- **Что это**: 182 агента + 75 плагинов + 16 оркестраторов. Больше про workflow-автоматизацию.
- **Как устанавливать**: Через plugin marketplace в Claude Code
- **GitHub**: https://github.com/wshobson/agents
```bash
# В Claude Code:
/plugin marketplace add wshobson/agents
/plugin install python-development@claude-code-workflows
```

### 3. avivl/claude-007-agents
- **Что это**: 112 агентов + Task Master (автономная система разработки).
- **Фишка**: bootstrap-orchestrator анализирует проект и настраивает агентов под него автоматически.
- **GitHub**: https://github.com/avivl/claude-007-agents

### 4. Встроенные агенты Claude Code
- **Explore** — read-only агент для поиска по кодбейзу. Не модифицирует файлы.
- **Plan** — агент-архитектор. Создаёт план реализации без написания кода.
- **General-purpose** — полноценный агент с доступом ко всем инструментам.
- Вызываются через Task tool автоматически или можно указать явно.

---

## АГЕНТЫ ДЛЯ ТВОИХ ПРОЕКТОВ

### Для YARICK (ML/предсказания)

#### data-scientist
**Что делает**: Полный цикл data science — от формулирования гипотезы до валидации модели. Знает XGBoost, LightGBM, scikit-learn, Pandas, StatsModels, Plotly/Seaborn. Умеет делать walk-forward validation, feature engineering, A/B тесты.
**Как использовать**: "Используй @data-scientist чтобы проанализировать мой датасет матчей и предложить фичи для XGBoost модели"
**Зачем тебе**: Это твой "Ярослав в Claude Code" — делегируешь ему исследовательскую работу по данным, получаешь отчёт с визуализациями.
**Источник**: VoltAgent, категория 05-data-ai
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/05-data-ai/data-scientist.md \
  -o ~/.claude/agents/data-scientist.md
```

#### data-researcher  
**Что делает**: Ищет и обрабатывает данные из разных источников. Чистка, анализ, обнаружение паттернов, построение предиктивных моделей. Генерирует интерактивные дашборды.
**Как использовать**: "Используй @data-researcher чтобы проанализировать покрытие данных по лигам за 2024 год и найти пробелы"
**Зачем тебе**: Для задач типа "у меня 534K записей OU2.5, покажи где дыры в данных и что с этим делать".
**Источник**: VoltAgent, категория 10-research-analysis
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/10-research-analysis/data-researcher.md \
  -o ~/.claude/agents/data-researcher.md
```

---

### Для CAME BOT (цифровые товары)

#### python-pro
**Что делает**: Senior Python-разработчик. Знает Python 3.11+, async/await, type hints, тестирование, packaging. Пишет production-ready код с обработкой ошибок, логированием, типизацией.
**Как использовать**: "Используй @python-pro чтобы отрефакторить модуль обработки заказов с правильной типизацией и обработкой ошибок"
**Зачем тебе**: Когда нужно не просто "написать код" а написать его правильно — с тестами, типами, обработкой edge cases.
**Источник**: VoltAgent, категория 02-language-specialists
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/02-language-specialists/python-pro.md \
  -o ~/.claude/agents/python-pro.md
```

#### api-architect (из wshobson/agents)
**Что делает**: Проектирует REST API — эндпоинты, схемы данных, аутентификация, версионирование, обработка ошибок. Думает об API как о продукте.
**Как использовать**: "Используй @api-architect чтобы спроектировать API для интеграции CAME BOT с Яндекс Маркет"
**Зачем тебе**: Правильная архитектура API с первого раза, а не "потом переделаем".
**Источник**: wshobson/agents
```bash
/plugin install api-development@claude-code-workflows
```

---

### Для VPN-сервиса

#### devops-specialist (или sysadmin из VoltAgent)
**Что делает**: Linux-администрирование, Docker, Nginx, конфигурация серверов, мониторинг, автоматизация деплоя.
**Как использовать**: "Используй @devops-specialist чтобы настроить Marzban с VLESS+xHTTP и Cloudflare CDN fronting"
**Зачем тебе**: Конфигурация серверов для VPN — это именно devops-задача.
**Источник**: VoltAgent, категория 03-infrastructure

---

### Для Upwork (скрейпинг/автоматизация)

#### scraping-автоматизация — нет готового, но есть составные решения:
- **python-pro** — пишет код скрейпера
- **research-analyst** — исследует структуру сайта перед скрейпингом  
- **data-analyst** — обрабатывает собранные данные

---

### Для всех проектов (универсальные)

#### task-orchestrator (из claude-007-agents)
**Что делает**: Разбивает большую задачу на подзадачи, назначает каждую подходящему агенту, координирует выполнение, собирает результат. По сути — твой "прораб".
**Как использовать**: "Используй @task-orchestrator чтобы скоординировать разработку нового модуля оплаты: нужен API, тесты, документация"
**Зачем тебе**: Ты описал себя как "архитектор без прораба" — этот агент и есть прораб. Ты говоришь ЧТО нужно, он разбивает на КАК и делегирует.
**Источник**: avivl/claude-007-agents
```bash
git clone https://github.com/avivl/claude-007-agents.git ~/tools/claude-007-agents
cp ~/tools/claude-007-agents/.claude/agents/task-orchestrator.md ~/.claude/agents/
```

#### research-analyst
**Что делает**: Глубокий ресёрч по любой теме — собирает информацию из разных источников, синтезирует, оценивает достоверность, генерирует отчёт.
**Как использовать**: "Используй @research-analyst чтобы исследовать текущие комиссии маркетплейсов для цифровых товаров в России"
**Зачем тебе**: Вместо того чтобы самому часами гуглить — делегируешь ресёрч агенту.
**Источник**: VoltAgent, категория 10-research-analysis
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/10-research-analysis/research-analyst.md \
  -o ~/.claude/agents/research-analyst.md
```

#### project-idea-validator
**Что делает**: Жёстко оценивает бизнес-идею — рынок, конкуренты, unit-экономика, риски. Даёт go/no-go решение с обоснованием. Не льстит.
**Как использовать**: "Используй @project-idea-validator чтобы оценить идею продажи цифровых товаров через FunPay как альтернативу Яндекс Маркету"
**Зачем тебе**: Фильтр от плохих идей до того как потратишь время.
**Источник**: VoltAgent, категория 10-research-analysis
```bash
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/10-research-analysis/project-idea-validator.md \
  -o ~/.claude/agents/project-idea-validator.md
```

#### systematic-debugger (obra/systematic-debugging)
**Что делает**: Методичная отладка — воспроизводит баг → локализует → находит причину → чинит → проверяет. Не "давай попробуем поменять эту строчку", а инженерный подход.
**Как использовать**: "Используй @systematic-debugger — бот перестал отправлять ключи после обновления API маркетплейса"
**Зачем тебе**: Когда что-то сломалось и непонятно где — вместо хаотичного тыканья получаешь структурированную отладку.
**Источник**: VoltAgent/awesome-agent-skills (obra)

---

## МУЛЬТИ-АГЕНТНАЯ ОРКЕСТРАЦИЯ

Это следующий уровень — несколько агентов работают параллельно. Есть 3 варианта:

### Agent Teams (встроенный в Claude Code)
**Что это**: Экспериментальная фича Claude Code. Один агент-лид раздаёт задачи нескольким "тиммейтам", каждый работает в своём контексте.
**Как включить**: 
```bash
# В settings.json Claude Code:
"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": true
```
**Когда полезно**: Параллельный ресёрч (3 агента исследуют разные аспекты), разработка фичи по слоям (frontend + backend + тесты).
**Когда НЕ полезно**: Последовательные задачи, работа с одним файлом, маленькие задачи.
**Честная оценка**: Экспериментально, жрёт много токенов, но для больших задач — мощнее одного агента.

### Claude Squad
**Что это**: Терминальное приложение для управления несколькими Claude Code сессиями параллельно. Каждая сессия — отдельная задача в отдельном workspace.
**GitHub**: https://github.com/smtg-ai/claude-squad
**Когда полезно**: Когда у тебя 3 проекта (CAME BOT, YARICK, VPN) и хочешь работать над всеми одновременно.

### Conductor (wshobson/agents)
**Что это**: Плагин который превращает Claude Code в систему управления проектами. Workflow: описываешь контекст → Claude генерирует спецификацию → разбивает на фазы → реализует с TDD.
**Как установить**:
```bash
/plugin install conductor@claude-code-workflows
```
**Как работает**:
1. `/conductor:setup` — описываешь проект (vision, стек, правила)
2. `/conductor:new-track` — Claude создаёт план: спецификация → фазы → задачи
3. `/conductor:implement` — Claude реализует с checkpoint-ами и тестами
4. `/conductor:revert` — откат по логическим единицам если что-то пошло не так
**Зачем тебе**: Это решение твоей проблемы "теряю состояние проекта между сессиями". Conductor сохраняет контекст проекта и может продолжить с того места где остановился.

---

## ЧТО СТАВИТЬ — ПРИОРИТЕТЫ

### Прямо сейчас (5 минут):
```bash
# 1. data-scientist — для YARICK
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/05-data-ai/data-scientist.md \
  -o ~/.claude/agents/data-scientist.md

# 2. python-pro — для всего Python
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/02-language-specialists/python-pro.md \
  -o ~/.claude/agents/python-pro.md

# 3. research-analyst — для ресёрча
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/10-research-analysis/research-analyst.md \
  -o ~/.claude/agents/research-analyst.md

# 4. project-idea-validator — фильтр идей
curl -s https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories/10-research-analysis/project-idea-validator.md \
  -o ~/.claude/agents/project-idea-validator.md
```

### Когда освоишься:
```bash
# Conductor — управление проектами  
# В Claude Code:
/plugin marketplace add wshobson/agents
/plugin install conductor@claude-code-workflows
```

### Когда начнёшь масштабироваться:
- Agent Teams (экспериментальное, для параллельной работы)
- Claude Squad (несколько проектов одновременно)

---

---

## TELEGRAM-ИНТЕГРАЦИЯ (управляй Claude Code с телефона)

Это отдельная категория — не агенты, но мощнейший инструмент для твоего стиля работы. Ты отправляешь сообщение в Telegram → Claude Code на твоём десктопе выполняет задачу → результат приходит обратно в Telegram.

### Официальный Telegram-плагин (Anthropic)
**Что это**: Официальный канал от Anthropic. Claude Code слушает Telegram-бота, получает твои сообщения, выполняет с полным доступом к файлам/git/MCP, отвечает в чат.
**Зачем тебе**: Ушёл из дома — написал боту "запусти тесты для CAME BOT и скажи что сломалось". Или "какой статус YARICK датасета?". Claude Code на десктопе делает работу, результат на телефоне.
**Установка**:
```bash
# В Claude Code:
/plugin marketplace add anthropics/claude-plugins-official
/plugin install telegram@claude-plugins-official

# Создать бота через @BotFather в Telegram
# Получить токен
/telegram:configure <TOKEN>

# Запустить с каналом:
claude --channels plugin:telegram@claude-plugins-official
```
**GitHub**: https://github.com/anthropics/claude-plugins-official

### CCGram (продвинутая альтернатива)
**Что это**: Telegram-мост с фичами которых нет в официальном плагине:
- **Approve/Deny через кнопки** — Claude просит разрешение на действие, ты тапаешь "Allow" в Telegram
- **Smart notifications** — уведомляет только когда ты отошёл от терминала (>5 минут неактивности)
- **Resume** — можно продолжить любую прошлую сессию Claude Code из Telegram
- **Multi-session** — управляй несколькими проектами одновременно
**Зачем тебе**: Запустил Claude Code работать над YARICK, ушёл гулять с котом. Через Telegram следишь за прогрессом, approve/deny действий, получаешь результат.
**GitHub**: https://github.com/jsayubi/ccgram

### CCBot (ещё вариант)
**Что это**: Похожий мост, но с отличием — каждый Telegram-топик = отдельная сессия Claude Code. Поддерживает голосовые сообщения (транскрибирует через OpenAI).
**Зачем тебе**: Один топик = CAME BOT, другой = YARICK, третий = VPN. Пишешь в нужный — Claude работает в соответствующем проекте.
**GitHub**: https://github.com/six-ddc/ccbot

---

## ДОПОЛНИТЕЛЬНЫЕ MCP-СЕРВЕРЫ

### Playwright MCP (Microsoft)
**Что делает**: Claude Code управляет настоящим браузером — открывает страницы, кликает, заполняет формы, делает скриншоты. Видит accessibility tree (структуру страницы).
**Зачем тебе**: Upwork-скрейпинг, тестирование CAME BOT на маркетплейсе, автоматизация.
**Установка**:
```bash
claude mcp add playwright -- npx -y @anthropic-ai/playwright-mcp@latest
```
**GitHub**: https://github.com/microsoft/playwright-mcp (30K+ звёзд)

### Firecrawl MCP
**Что делает**: Мощный веб-скрейпер — извлекает чистый контент из любого сайта, конвертирует в markdown, поддерживает JS-рендеринг. Есть автономный "агент" который сам планирует стратегию сбора данных.
**Зачем тебе**: Upwork-задачи по скрейпингу. "Собери данные о ценах с 10 сайтов" — Firecrawl делает автоматически.
**Установка**:
```bash
# Нужен API ключ (бесплатный tier есть)
claude mcp add firecrawl -- npx -y firecrawl-mcp
```
**GitHub**: https://github.com/firecrawl/firecrawl-mcp-server

### PostgreSQL MCP
**Что делает**: Claude Code напрямую работает с PostgreSQL — запросы, схемы, анализ данных через SQL.
**Зачем тебе**: Если CAME BOT или YARICK используют PostgreSQL — Claude видит данные в реальном времени.
**Установка**:
```bash
claude mcp add postgres -- npx -y @modelcontextprotocol/server-postgres \
  "postgresql://user:pass@localhost/dbname"
```

### GitHub MCP (официальный)
**Что делает**: Claude Code работает с GitHub API напрямую — создаёт PR, ревьюит код, управляет issues, ищет по репозиториям.
**Зачем тебе**: Автоматизация git-workflow. "Создай PR с описанием изменений" — одной командой.
**Установка**:
```bash
claude mcp add github -- docker run -i --rm \
  -e GITHUB_PERSONAL_ACCESS_TOKEN \
  ghcr.io/github/github-mcp-server
```

### Composio MCP (250+ интеграций через один сервер)
**Что делает**: Один MCP-сервер вместо десяти — подключает GitHub, Slack, Gmail, Notion, Jira и 250+ сервисов. OAuth через дашборд, не нужно каждый раз настраивать токены.
**Зачем тебе**: Если нужна интеграция с несколькими сервисами одновременно.

---

## HOOKS (автоматические триггеры)

Hooks — это не агенты и не скиллы, а автоматические действия которые выполняются при определённых событиях в Claude Code. Например: "после каждого коммита — запусти тесты", "при старте сессии — загрузи контекст проекта".

### Полезные хуки для тебя:

**Auto-test после изменений**:
```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Write|Edit",
      "hooks": [{"type": "command", "command": "pytest tests/ -x --tb=short 2>&1 | tail -5"}]
    }]
  }
}
```
→ После каждого изменения файла Claude автоматически видит результат тестов.

**Auto-lint**:
```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Write",
      "hooks": [{"type": "command", "command": "ruff check --fix $(jq -r '.file_path') 2>&1"}]
    }]
  }
}
```

**Hookify** (плагин) — генерирует хуки через диалог:
```bash
/plugin install hookify@claude-code-workflows
/hookify  # интерактивный мастер создания хуков
```

---

## ОРКЕСТРАТОРЫ (управление несколькими агентами)

### Claude Squad
**Что это**: Терминальное приложение. Запускает несколько Claude Code сессий параллельно, каждая в своём git worktree. Дашборд в терминале показывает статус всех сессий.
**Зачем тебе**: CAME BOT фиксит баг в одной сессии, YARICK тренирует модель в другой, VPN конфигурирует сервер в третьей — всё одновременно.
**GitHub**: https://github.com/smtg-ai/claude-squad

### CC Mirror (скрытый оркестратор из самого Claude Code)
**Что это**: Open-source проект который разблокировал встроенную мульти-агентную систему Claude Code. Claude становится "дирижёром" — разбивает задачу на граф зависимостей, спавнит агентов в бэкграунде, координирует.
**Паттерны**: Fan-Out (раздай всем), Pipeline (последовательная цепочка), Map-Reduce (разбей-обработай-собери).
**GitHub**: Ищи "CC Mirror claude code" на GitHub

### AgentSys (avifenesh)
**Что это**: Комплексная система автоматизации — task-to-production workflow, PR management, code cleanup, drift detection, мульти-агентный code review.
**Зачем тебе**: Когда проект вырастет и нужен полноценный CI/CD пайплайн с AI-ревью.
**GitHub**: https://github.com/avifenesh/AgentSys

---

## ДОПОЛНИТЕЛЬНЫЕ АГЕНТЫ (из второго прохода поиска)

### claude-devtools (desktop app)
**Что это**: Десктопное приложение для наблюдения за Claude Code сессиями. Показывает: потребление токенов по турнам, визуализацию compaction, деревья суб-агентов, кастомные уведомления.
**Зачем тебе**: Понимать сколько токенов (= денег) уходит на каждый запрос.
**GitHub**: https://github.com/matt1398/claude-devtools

### agnix (линтер для AI-конфигов)
**Что это**: Проверяет твои CLAUDE.md, AGENTS.md, SKILL.md, хуки, MCP на ошибки. Как ESLint но для конфигов Claude Code.
**Зачем тебе**: Когда наставишь много скиллов и агентов — помогает найти конфликты и ошибки.
**GitHub**: через AgentSys (avifenesh)

### Codebase to Course
**Что это**: Превращает любой проект в интерактивный HTML-курс. Claude анализирует код и генерирует обучающий материал с объяснениями.
**Зачем тебе**: Для онбординга — когда Ярослав или Влад заходят в твой проект, дай им сгенерированный курс вместо "читай README".

---

## АГЕНТЫ КОТОРЫЕ НЕ НУЖНЫ

Из 100+ агентов в коллекциях, отфильтровал лишнее:

- **kubernetes-architect, docker-specialist, terraform-expert** — ты не используешь K8s/Terraform
- **react-native-specialist, ios-developer, android-expert** — не мобильная разработка
- **java-pro, csharp-pro, rust-pro, go-pro** — не твои языки
- **blockchain-developer, smart-contract-auditor** — не крипторазработка
- **product-manager, ux-researcher, marketing-strategist** — ты соло-разработчик
- **aws-solutions-architect, azure-engineer, gcp-specialist** — используешь VPS
- **compliance-officer, gdpr-specialist** — не enterprise

---

## ВАЖНО: КАК АГЕНТЫ ТРАТЯТ ТОКЕНЫ

Агенты работают в отдельном контексте — каждый вызов агента это отдельная цепочка запросов к API. Один вызов @data-scientist может стоить 50K-200K токенов в зависимости от сложности задачи.

**Рекомендации по экономии**:
- Используй агенты для больших задач (>30 минут ручной работы)
- Для мелких задач — работай в основной сессии
- Агенты из VoltAgent по умолчанию используют Sonnet (дешевле Opus)
- Можно поменять модель в frontmatter агента: `model: sonnet` или `model: inherit`
