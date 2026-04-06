# Рекомендации по плагинам, скиллам и MCP-серверам для Claude Code

> Подобрано под проекты: **CAME BOT** (цифровые товары на Яндекс Маркет), **YARICK** (ML-предсказания футбола), **VPN-сервис**, **Upwork фриланс** (веб-скрейпинг/автоматизация)
> Система: Ubuntu 24.04, Python, Node.js

---

## ПРИОРИТЕТ 1 — Поставить сразу (польза с первого дня)

### Context7 (MCP сервер)
**Что делает простыми словами**: Когда ты просишь Claude Code написать код с какой-то библиотекой (pandas, XGBoost, Playwright, React) — он часто использует устаревшие примеры или выдумывает несуществующие функции. Context7 в момент запроса скачивает АКТУАЛЬНУЮ документацию этой библиотеки и подсовывает её Claude. Результат — код работает с первого раза.

**Как использовать**: Добавляешь "use context7" в конец промпта. Например: "напиши скрипт парсинга на Playwright — use context7"

**Установка**:
```bash
claude mcp add context7 -- npx -y @upstash/context7-mcp@latest
```

**Полезно для**: ВСЕ проекты. Особенно YARICK (XGBoost, pandas, sklearn) и Upwork-задачи (Playwright, различные API).

---

### code-review-graph (MCP сервер)
**Что делает простыми словами**: Сканирует твой проект один раз и запоминает как все файлы связаны друг с другом. Когда ты просишь Claude что-то изменить — он читает только нужные файлы, а не весь проект. Экономит токены (= деньги) в 6-8 раз.

**Дополнительно**: Умеет генерировать wiki по структуре проекта, показывать "blast radius" (какие файлы затронет изменение), находить мёртвый код.

**Установка**:
```bash
pip install code-review-graph --break-system-packages
code-review-graph install --platform claude-code
code-review-graph build  # первый раз в папке проекта
```

**Полезно для**: CAME BOT и YARICK — оба проекта уже достаточно большие чтобы Claude терялся в них.

**GitHub**: https://github.com/tirth8205/code-review-graph

---

### hex-line (MCP сервер, часть levnikolaevich/claude-code-skills)
**Что делает простыми словами**: Claude иногда "помнит" старую версию файла и вносит правки поверх несуществующего кода — всё ломается. hex-line добавляет к каждой строке контрольный хеш. Если файл изменился с момента когда Claude его прочитал — правка отклоняется. Страховка от тупых ошибок.

**Установка**:
```bash
npm i -g @levnikolaevich/hex-line-mcp
claude mcp add -s user hex-line -- hex-line-mcp
```

**Полезно для**: Любые длинные сессии. Особенно когда ты даёшь Claude задачу и уходишь — он не сломает код незаметно.

---

## ПРИОРИТЕТ 2 — Для ML и YARICK

### Claude Scientific Skills (набор скиллов)
**Что делает простыми словами**: 125+ инструкций которые учат Claude правильно работать с ML. Без них Claude пишет ML-код "как получится". С ними — он знает:
- Как правильно делить данные на train/test (чтобы не было data leakage)
- Как настраивать XGBoost (какие гиперпараметры крутить первыми)
- Как визуализировать результаты (confusion matrix, feature importance, ROC curves)
- Как делать walk-forward validation для временных рядов (актуально для YARICK!)
- Как корректно считать метрики (accuracy vs precision vs recall vs CLV)

**Конкретно полезные скиллы из набора**:
- `machine-learning` — общий ML пайплайн
- `time-series-analysis` — для исторических данных матчей
- `data-analysis-visualization` — EDA и графики
- `statistical-analysis` — статтесты для проверки гипотез

**Установка**:
```bash
git clone https://github.com/K-Dense-AI/claude-scientific-skills.git
# Копируешь нужные папки в ~/.claude/skills/
cp -r claude-scientific-skills/skills/machine-learning ~/.claude/skills/
cp -r claude-scientific-skills/skills/time-series-analysis ~/.claude/skills/
cp -r claude-scientific-skills/skills/data-analysis-visualization ~/.claude/skills/
```

**GitHub**: https://github.com/K-Dense-AI/claude-scientific-skills

---

### HuggingFace Official Skills
**Что делает простыми словами**: Официальные скиллы от команды HuggingFace. Учат Claude работать с их экосистемой — загружать датасеты, файнтюнить модели, трекать эксперименты. Если YARICK вырастет до уровня где нужны трансформеры — это готовая интеграция.

**Конкретно полезные**:
- `hugging-face-datasets` — загрузка и работа с датасетами (можно опубликовать свой датасет матчей)
- `hugging-face-trackio` — трекинг экспериментов с дашбордами (альтернатива W&B)
- `hugging-face-model-trainer` — файнтюнинг моделей (SFT, DPO, GRPO)

**Установка**: Через VoltAgent/awesome-agent-skills — описано как устанавливать каждый отдельно.

**GitHub**: https://github.com/VoltAgent/awesome-agent-skills (секция HuggingFace)

---

## ПРИОРИТЕТ 3 — Для веб-разработки и Upwork

### ClaudeKit web-dev-tools (набор скиллов)
**Что делает простыми словами**: Пачка инструкций которые учат Claude писать современный веб-код. Без них Claude часто генерирует устаревшие паттерны (Pages Router вместо App Router в Next.js, className вместо Tailwind, vanilla CSS вместо компонентов). С ними — пишет как senior frontend.

**Что внутри конкретно**:
- `web-frameworks` — Next.js (App Router, Server Components, SSR/SSG), Turborepo для монорепо
- `ui-styling` — shadcn/ui + Tailwind CSS + тёмная тема + доступность
- `frontend-design` — уникальный дизайн, не "AI-слоп" (типовой серый шаблон)
- `frontend-development` — React/TypeScript паттерны, Suspense, lazy loading
- `chrome-devtools` — Puppeteer автоматизация, скриншоты, скрейпинг

**Установка**:
```bash
# Через маркетплейс Claude Code:
/plugin marketplace add mrgoonie/claudekit-skills
/plugin install web-dev-tools@claudekit-skills
```

**Полезно для**: Upwork-задачи (скрейпинг через Puppeteer/Playwright), сайт для КОДХАБ, любые веб-проекты.

**GitHub**: https://github.com/mrgoonie/claudekit-skills

---

### next-devtools-mcp (MCP сервер от Vercel)
**Что делает простыми словами**: Если делаешь проект на Next.js — этот MCP подключается к запущенному dev-серверу и показывает Claude все ошибки, роуты, метаданные приложения в реальном времени. Claude видит что сломалось и чинит без твоей помощи.

**Установка**:
```bash
claude mcp add next-devtools -- npx -y next-devtools-mcp@latest
```

**Полезно для**: Только если работаешь с Next.js. Для Upwork задач с React/Next.js — маст хэв.

**GitHub**: https://github.com/vercel/next-devtools-mcp

---

## ПРИОРИТЕТ 4 — Для продуктивности и качества кода

### webapp-testing (скилл)
**Что делает простыми словами**: Учит Claude тестировать веб-приложения через Playwright — открывает страницу в реальном браузере, кликает кнопки, проверяет что работает. Полезно когда Claude сделал фронтенд и нужно убедиться что он не сломан.

**GitHub**: Есть в нескольких коллекциях (BehiSecc/awesome-claude-skills, anthropics/skills)

---

### senior-architect (скилл из alirezarezvani/claude-skills)
**Что делает простыми словами**: Claude думает как архитектор — сначала планирует структуру проекта, потом пишет код. Без этого скилла Claude часто сразу кидается писать код и получается каша. С ним — сначала рисует план, потом реализует.

**Полезно для тебя**: Ты описал себя как "архитектор без прораба" — этот скилл как раз даёт Claude роль прораба, а тебе оставляет роль архитектора.

---

### self-improving-agent (скилл из alirezarezvani/claude-skills)
**Что делает простыми словами**: Claude записывает свои ошибки и учится на них в рамках проекта. Если он однажды сделал ошибку в твоём проекте — запоминает и не повторяет.

---

### systematic-debugging (скилл)
**Что делает простыми словами**: Когда есть баг — вместо того чтобы хаотично менять код, Claude следует структурированному процессу: воспроизвести → локализовать → понять причину → починить → проверить. Экономит часы.

**GitHub**: BehiSecc/awesome-claude-skills

---

## ЧТО НЕ НУЖНО (почему фильтрую)

Из тех 220+ / 1367+ скиллов в мега-коллекциях бОльшая часть тебе не нужна:
- **Marketing/SEO/CRO** (35+ скиллов) — ты не маркетолог
- **Compliance/GDPR/HIPAA** (20+ скиллов) — для корпоратов
- **AWS/Azure/GCP** (15+ скиллов) — ты используешь VPS напрямую
- **Kubernetes/Helm/Terraform** (10+ скиллов) — оверкилл для твоих проектов
- **C-level/Executive** (28 скиллов) — управление компаниями
- **iOS/Swift/Xcode** (5+ скиллов) — не твоя платформа
- **HealthTech/MedTech** (8 скиллов) — специализированная медицина

---

## ИЗ МЕГА-КОЛЛЕКЦИЙ: ЧТО РЕАЛЬНО ПОЛЕЗНО ДЛЯ ТВОИХ ПРОЕКТОВ

### Из alirezarezvani/claude-skills (220+ скиллов):
| Скилл | Зачем тебе |
|-------|-----------|
| `senior-architect` | Планирование структуры перед кодом |
| `senior-backend` | Python backend для CAME BOT, API |
| `senior-fullstack` | Комплексные веб-проекты |
| `data-engineer` | Пайплайны данных для YARICK |
| `self-improving-agent` | Claude учится на своих ошибках в проекте |
| `playwright-testing` | Автотесты для веб + Upwork-скрейпинг |
| `database-designer` | Проектирование БД для CAME BOT |
| `financial-analyst` | Unit-экономика CAME BOT, анализ |

### Из wshobson/agents (182 агента):
| Плагин | Зачем тебе |
|--------|-----------|
| `python-development` | 3 Python-эксперта + 5 скиллов |
| `api-development` | REST API дизайн для бота |
| `testing-frameworks` | Автотесты |
| `git-workflow` | Git автоматизация, PR |
| `conductor` | Управление контекстом проекта (Context → Spec → Implement) |

### Из VoltAgent/awesome-agent-skills (1000+):
| Скилл | Зачем тебе |
|-------|-----------|
| `huggingface/*` (10 скиллов) | ML пайплайны для YARICK |
| `coderabbitai/skills` | Автоматический code review |
| `deep-research` | Ресёрч через Gemini для анализа рынка |
| `webapp-testing` | Тестирование веб-приложений |
| `hand-drawn-diagrams` | Быстрые диаграммы архитектуры |

---

## ВИЗУАЛИЗАЦИЯ ПРОЕКТОВ — КАСТОМНЫЙ СКИЛЛ

**Задача**: Генерировать понятную нод-схему проекта (как n8n), где видно бизнес-логику, а не код.

**Решение**: Скилл-агент `project-visualizer` на базе Understand-Anything + React Flow.

**Как будет работать**:
1. Ты пишешь: `/visualize` или "покажи мне как работает проект"
2. Агент сканирует проект и генерирует JSON-описание бизнес-потоков
3. Создаёт интерактивную HTML-страницу с React Flow
4. Каждая нода — понятным языком ("Получает заказ", "Проверяет остатки", "Отправляет ключ")
5. Связи между нодами показывают поток данных
6. Можно кликать на ноду — видишь детали

**Пример для CAME BOT**:
```
[Яндекс Маркет] → [Получение заказа] → [Проверка остатков]
                                              ↓
                                    [Есть ключи?]
                                    ↙          ↘
                            [Да: Отправка]  [Нет: Оповещение]
                                ↓                    ↓
                        [Списание из БД]    [Закупка у поставщика]
                                ↓
                        [Подтверждение заказа]
```

**Статус**: Нужно написать. Я могу создать этот скилл для тебя — он будет жить в `~/.claude/skills/project-visualizer/`.

---

## ПОРЯДОК УСТАНОВКИ

### Шаг 1: MCP-серверы (5 минут)
```bash
# Context7 — актуальные доки
claude mcp add context7 -- npx -y @upstash/context7-mcp@latest

# hex-line — защита от stale edits
npm i -g @levnikolaevich/hex-line-mcp
claude mcp add -s user hex-line -- hex-line-mcp

# code-review-graph — экономия токенов
pip install code-review-graph --break-system-packages
code-review-graph install --platform claude-code
```

### Шаг 2: ML-скиллы (3 минуты)
```bash
git clone https://github.com/K-Dense-AI/claude-scientific-skills.git ~/tools/claude-scientific-skills
cp -r ~/tools/claude-scientific-skills/skills/machine-learning ~/.claude/skills/
cp -r ~/tools/claude-scientific-skills/skills/time-series-analysis ~/.claude/skills/
cp -r ~/tools/claude-scientific-skills/skills/data-analysis-visualization ~/.claude/skills/
cp -r ~/tools/claude-scientific-skills/skills/statistical-analysis ~/.claude/skills/
```

### Шаг 3: Веб-скиллы (2 минуты)
```bash
# В Claude Code:
/plugin marketplace add mrgoonie/claudekit-skills
/plugin install web-dev-tools@claudekit-skills
```

### Шаг 4: Архитектурные скиллы (3 минуты)
```bash
git clone https://github.com/alirezarezvani/claude-skills.git ~/tools/claude-skills
cp -r ~/tools/claude-skills/engineering-team/senior-architect ~/.claude/skills/
cp -r ~/tools/claude-skills/engineering-team/senior-backend ~/.claude/skills/
cp -r ~/tools/claude-skills/engineering-team/self-improving-agent ~/.claude/skills/
cp -r ~/tools/claude-skills/engineering-team/database-designer ~/.claude/skills/
```

### Шаг 5: Визуализация (2 минуты)
```bash
# Understand-Anything
/plugin marketplace add Lum1104/Understand-Anything
/plugin install understand-anything
```

---

## ВАЖНЫЕ ОГОВОРКИ

1. **Не ставь всё сразу**. Каждый скилл занимает токены при сканировании (~100 токенов на скилл). 20 скиллов = 2000 токенов на каждый запрос. Ставь то что нужно прямо сейчас.

2. **MCP-серверы НЕ жрут токены просто так** — они активируются только когда Claude их вызывает. Их можно ставить все.

3. **Скиллы могут конфликтовать**. Если два скилла дают противоположные инструкции — Claude запутается. Не ставь два "frontend" скилла одновременно.

4. **Проверяй актуальность**. Половина этих репозиториев может забросить через полгода. Смотри дату последнего коммита перед установкой.

5. **Бэкап конфигов**. Перед экспериментами:
```bash
cp -r ~/.claude ~/.claude.backup
```
