# forge-plugin

Плагин для Claude Code, автоматизирующий рабочие процессы разработки через 7-фазный pipeline (0 → 1 → 1.5 → 2 → 3 → 4 → 5) + систему скиллов + L0/L1/L2 контекст.

## Technical Stack

- **Bash** — хуки (`hooks/*.sh`)
- **Python** — BM25 поиск для UI/UX дизайна
- **Markdown** — скиллы, команды, документация, output styles
- **Claude Code Plugin System** — runtime

## Project Structure

```
forge-plugin/              — корневая директория плагина
  .claude-plugin/          — manifest (plugin.json, marketplace.json)
  hooks/                   — bash хуки (session-start, context-inject, bash-safety, statusline)
  agents/                  — промпт-шаблоны субагентов
  commands/                — slash-команды (MD файлы)
  skills/                  — 33 скилла (SKILL.md + поддержка)
  output-styles/           — нативный Output Style "Forge Concise" (auto-activated)
  evals/                   — каркас Hamel-style eval-сетапа (корпус пуст, ни одного прогона)
  sounds/                  — mp3 для Stop / PermissionRequest хуков
  docs/                    — спецификация, архитектура, runtime-flow
  tests/                   — prompt-based тесты + bash-тесты хуков
ideas/                     — идеи и прототипы (pipeline-v2.html и др.)
.forge/                    — FORGE контекст (L0/L1/L2) — в git, мусор в .forge/.gitignore
```

## Running

- **Запуск:** плагин загружается автоматически через Claude Code Plugin System
- **Тесты:** prompt-based в `forge-plugin/tests/skill-triggering/` + bash в `forge-plugin/tests/hooks/`
- **Линтер:** нет

## FORGE Context (L0/L1/L2)

Context auto-injected via `hooks/context-inject.sh` — умная инжекция: полный блок (~700 tokens по замеру — L0 + branch + git log + graph hint) только при изменении `.forge`-контекста, в новой сессии или каждые 15 промптов; в остальных промптах — короткая строка-напоминание (~20 tokens).

ROUTING и DOC DISCIPLINE инжектятся **один раз** через `session-start.sh`. STYLE правил больше нет в хуке — они в нативном Output Style.

**L0 (always loaded):** `.forge/index.yml` — goal, stage, task, catalog of all resources

**L1 (load by tags from catalog):**
- `.forge/map.yml` — structure [tags: structure, files, navigate]
- `.forge/conventions.yml` — naming, patterns [tags: naming, format, rules]
- `.forge/status.yml` — working/broken/blocked [tags: working, broken, health]
- `.forge/decisions.yml` — why we chose X [tags: why, architecture, choice]
- `.forge/dead-ends.yml` — failed approaches [tags: failed, tried, avoid]
- `.forge/journal.yml` — session history [tags: history, last-session, resume]
- `.forge/learnings.yml` — project lessons [tags: lesson, learning, insight]
- `.forge/direction.yml` — strategic layer: directions/hypotheses, backlog, goal-shift [tags: direction, strategy, navigate]

**L2 (load rarely):** `.forge/library/*/spec.yml`, `.forge/dead-ends/*.md`

DO NOT load all L1 files. Match catalog tags to current task.
DO NOT read source code before checking `.forge/library/spec.yml`.

Подробная процедура загрузки контекста — в скилле `forge-context`.

## GitHub Sync (опционально)

Автоматическая синхронизация пайплайна с GitHub: каждая фаза публикует артефакты как Issues и обновляет карту проекта.

**Как включается:**
- Флаг `github_sync: true` в `.forge/index.yml` — явное включение
- Иначе при первой задаче в проекте плагин сам спросит, если есть `gh` CLI и проект на GitHub (через `sync.sh should-offer`)

**Что появляется на GitHub:**
- **Issue per task** — `/forge:new-task` создаёт Issue с чистой задачей и критерием готовности
- **Sub-issues per step** — `/forge:critique` по финальному плану заводит дочерний Issue под каждый шаг (по черновику из `/forge:plan` — не заводит; повторный вызов обновляет состав шагов)
- **Pinned Issue карта проекта** — единый Issue с целями и счётчиками задач; обновляется механически внутри sync.sh (create-task, add-steps) и в финале execute
- **README шапка** — короткий блок "над чем идёт работа" в README.md, перегенерируется при изменении состояния

Projects v2 board не используется — Pinned Issue + README покрывают навигацию без требования non-default scope `project` в `gh auth`.

Гайд по проекту (Phase 5, `/forge:guide`) в Issues не отражается — он уезжает на GitHub файлами `docs/guide/` вместе с памятью (memory-backup).

**Команда:** `/forge:roadmap` — редактирование карты целей (milestones) на человеческом языке. Меняет описание Pinned Issue и шапку README.

**Runtime артефакты** в проекте пользователя (в `.forge/.gitignore`): `.forge/.github-pinned-id`, `.forge/.github-issue-<slug>`, `.forge/.github-substeps-<slug>`, `.forge/.github-bootstrapped`.

## Память проекта в git (memory-backup)

`.forge/` (задачи, планы, идеи, решения, журнал) — **часть репозитория**, переживает смерть диска/VPS. Служебный мусор (`.inject-state`, `.last-backup`, `state.yml`, `.github-*`, `graph.json`, `guide/shots/`) отсечён через `.forge/.gitignore`. Автосохранение: `session-awareness` (итог сессии) и `finishing` (после мержа) зовут `skills/memory-backup/backup.sh` — коммит `.forge` + `docs/guide/` (видимые версии гайда по проекту — тем же коммитом) + push текущей ветки. Ручной запуск: `/forge:save` или «сохрани». Напоминание при старте сессии, если несохранённое старше суток (session-start.sh). Без удалёнки — предложение приватного репозитория (только с явного «да»). Секреты в `.forge` не пишутся — только названия записей Bitwarden.

## Development Workflow — 7-фазный pipeline (0 → 1 → 1.5 → 2 → 3 → 4 → 5)

### Phase 0 — Direction (`/forge:unblocker`)
Навигатор направления — **над** пайплайном. Когда непонятно КУДА двигать проект (не «как сделать задачу X», а «какие глобальные направления ведут к цели») или когда застрял. Показывает живую цель строкой-якорем из `index.yml`, читает всю `.forge`-память + сканирует код, **рисует карту проекта** — все части по шагам его механизма со статусом (6 статусов — легенда в скилле project-unblocker; честно, без завышения), затем расписывает ВСЕ направления (= дыры карты) кратко (что делает + зачем, приоритет с учётом стадии), рекомендует дефолт-движение **не выбирая молча**, заканчивает одним физическим шагом → кормит `/forge:new-task`. Язык — простой, без жаргона (Антон не-кодер). Антон — не-кодер: слаб в придумывании стратегии, поэтому навигатор расписывает поле и рекомендует, но финальный выбор за ним.

**Память (петля):** пишет `.forge/direction.yml` (для Клода: directions/backlog/goal_shift). Отдельный документ «для глаз» не заводит — это гайд по проекту (Phase 5). Цикл: разговор → память → навигатор → задачи → результаты → снова память.

**Выход:** обновлённый `direction.yml`, первый физический шаг подан в `/forge:new-task`.

### Phase 1 — Understanding (`/forge:new-task`)
Сырой промпт → чистая задача + критерий готовности. Логические вопросы пользователю по одному, технические — Claude ищет сам в коде/доках. Опциональный HTML-набросок если пользователь буксует.

**Выход:** `.forge/tasks/YYYY-MM-DD-<slug>.md` с секциями `## Задача` и `## Критерий готовности`.

### Phase 1.5 — Idea Check (`/forge:refine-idea`)
Реалити-чек самой идеи до плана. Claude зеркалит как понял идею, оспаривает её фактами проекта (decisions / dead-ends / status / существующий код): та ли проблема, нет ли пути проще, что сломает, стоит ли усилий. На каждую слабость — конкретная альтернатива, а не приговор. Диалог, не отчёт. Не 4 персоны — один живой проход в основной сессии. Нужно потому, что пользователь не-кодер часто отдаёт идею как идею, а она не всегда разумна.

**Выход:** доработанный `.forge/tasks/YYYY-MM-DD-<slug>.md` (опц. секция `## Доработано на разборе`).

### Phase 2 — Planning (`/forge:plan`)
Задача → план с обязательными чекпоинтами на смысловых границах. Близкие блокеры становятся шагами плана, дальние выносятся в отдельную сессию через `.forge/blockers/`.

**Выход:** `.forge/plans/YYYY-MM-DD-<slug>.md` с шагами + чекпоинтами.

### Phase 3 — Critique (`/forge:critique`)
4 параллельных субагента-персоны (Skeptic / Pragmatist / Architect / User Advocate) рвут план каждый со своей стороны. Синтез правок + дописывание Execution Strategy (что в субагенты, что параллельно).

**Выход:** обновлённый `.forge/plans/...` с применёнными правками и Execution Strategy.

### Phase 4 — Implementation (`/forge:execute`)
Реализация в текущей сессии. Тяжёлая работа (чтение многих файлов, длинные тесты) делегируется субагентам. Остановка **только на чекпоинтах из плана**, не каждые N шагов.

Условный handoff: если контекст уже тяжёлый — рекомендуется новый чат для `/execute`.

### Phase 5 — Гайд по проекту (`/forge:guide`)
Один живой версионный документ, из которого человек со стороны (партнёр, заказчик, новый исполнитель, сам владелец через месяц) понимает проект целиком: 00 «где мы — за 30 секунд» + 🔥 «без чего стоим» + «как работать с документом» · 01 суть одной схемой + экраны · 02 из чего состоит · 03 главный путь по шагам · 04 роли · 05 решения с кодами и «почему» (принятые / «дефолт» / открытые) · 06 карта рисков (R-коды) · 07 план «сейчас → дальше → позже» · 08 словарик · футер «откуда собрано». Документ — на «вы», чат с владельцем — на «ты». Формат-эталон — `forge-plugin/docs/project-guide-format.md` (по образцу гайда Vespera, A4 для печати). Скилл — `skills/project-guide/`, имя фазы — `guide` (`state.yml: phase: guide`). Полная сборка — по слову «собери гайд» / «обнови гайд» / «гайд по проекту» (и «собери отчёт» — старое имя): `render.py bump` заводит новую версию (копия прошлой, +0.1; «это версия 2» → `bump major` → следующая крупная; старые версии не правятся; старый отчёт «Что дальше» первый `bump` переносит сам) → 6 субагентов одним сообщением: 2 картографа по образцу product-mapping (схема и главный путь; части, роли, словарь, дыры) + 4 аналитика (код / git / инфраструктура / память-документация-решения из `decisions.yml` и `direction.yml`) → Клод правит последний `.forge/guide/vX.Y.json` (память проекта, коммитится) → `render.py render` собирает `docs/guide/guide-vX.Y.html` + копию `guide-latest.html`, `render.py pdf` — `guide-vX.Y.pdf` через Chrome headless (нет Chrome — только HTML); Клод HTML руками не пишет → открыт в браузере. Повторная сборка дополняет прошлую версию и пишет «что изменилось с vX.Y»; оборванная сборка дособирается следующим «собери гайд», номера не плодятся. Экраны: веб с живым адресом → снимки Playwright (≤6, PNG ≤200 КБ, в `.forge/guide/shots/`, под игнором, в HTML — data: URI); Telegram-бот → нарисованный диалог из настоящих текстов бота; нечего показать — без картинок, без вопросов. «Открой гайд» / «покажи гайд» — последняя версия без пересборки и без агентов. Ответы владельца кодами в чате («A2 ок», «B2 — переделать: …», «D1 обсудить», «O1 — <ответ>», «R4 приоритет выше») читает Клод и передаёт рендереру уже разобранный статус — `render.py verdict <код> <статус> [текст]`, по одному вызову на код: статусы в последнем `vX.Y.json` меняются, его HTML (и PDF, если был) перерисованы, 🔥 остаётся только у неотвеченных, номер не растёт; принятое пишется в `decisions.yml`. Непонятный ответ — 2–3 варианта + рекомендация, без применения. После «мержим» `finishing` зовёт `render.py merged <slug>` (пункт задачи → «уже работает», счётчик устаревания +1, HTML и PDF пересобраны, номер тот же). Пункт «Код», взятый в работу, уходит в `/forge:new-task`; после сохранения task-файла new-task связывает его с задачей (`render.py link <id> <slug>`, `<id>` — `f7` или `R7`). Слова «что дальше по проекту» остаются за unblocker, «статус проекта» — за загрузкой контекста, «карта проекта» — за product-mapping. На GitHub гайд уезжает файлами `docs/guide/` вместе с памятью, Issues не заводятся.

**Выход:** последний `.forge/guide/vX.Y.json` + `docs/guide/guide-vX.Y.html` + `guide-vX.Y.pdf` + `guide-latest.html`; при старте сессии — одна строка «📖 Гайд по проекту vX.Y: ждут N решений владельца, гайд устарел на M задач» (session-start.sh; считаются только открытые, «обсудить» и 🔥, а не каждый «дефолт»).

### Git-модель: одна задача = одна ветка → мерж
- На входе в `/forge:execute` plugin сам заводит ветку `feat/<slug>` под задачу (молча, если пользователь на основной ветке; спрашивает на языке смысла, если он в чужой незавершённой работе).
- Ручные коммиты по ходу не обязательны — `finishing-a-development-branch` по команде «мержим» сам сохранит несохранённое, вольёт в master и уберёт ветку.
- Worktree (`using-git-worktrees`) — опционально, только для параллельной работы над несколькими задачами одновременно.
- `.forge/` — в git (память проекта коммитится и пушится, см. секцию memory-backup); служебный мусор отсечён `.forge/.gitignore`.

### Auto-handoff между фазами
По умолчанию: после "ОК" пользователя — Claude автоматически инвокает следующий skill. Пользователь может остановить словами "стоп" / "пауза" / "погоди". Между Phase 3 и Phase 4 — рекомендация открыть свежий чат если контекст большой. Phase 5 в цепочку auto-handoff не входит: полная сборка — только по команде/слову, после мержа гайд обновляется сам.

### Hard rules
- NO production code without finalized plan (`/critique` complete)
- NO implementation without approved task statement (`/new-task` complete)
- NO fixes without root cause analysis
- NO "done" claims without verifying against completion criterion
- NO skipping `/new-task` even for "simple" changes
- NO technical questions to Anton — find in code/docs yourself (он не-кодер)

### TDD — где имеет смысл
Используй для функциональной логики (валидаторы, парсеры, бизнес-правила, утилиты). Не насаждай TDD на HTML-вёрстку, конфиги, миграции БД, регистрацию роутов.

### Coding principles (Karpathy-style)

**Think before coding:** Don't assume — ask. State assumptions explicitly. If unclear — stop and clarify, don't guess.

**Simplicity first:** Minimum code that solves the problem. Nothing speculative. No unrequested features, no single-use abstractions, no error handling for impossible scenarios. Three identical lines are better than a premature abstraction.

**Surgical changes:** Touch only what you must. Don't improve adjacent code, don't fix unrelated issues, don't add docstrings to code you didn't change. Match existing style. Every changed line should trace directly to the request.

**Goal-driven execution:** Transform vague requests into testable objectives. Not "add validation" but "write tests for invalid inputs, then make them pass". Define success criteria, loop until verified.

## Conventions

- **Файлы/директории:** kebab-case
- **JS функции/переменные:** camelCase
- **Python функции/переменные:** snake_case
- **Константы:** UPPER_SNAKE_CASE
- **Скиллы:** директория + SKILL.md внутри
- **Команды:** kebab-case MD файлы

## Native Claude Code features used

- **Output Style "Forge Concise"** (`output-styles/forge-concise.md`) — нативный механизм Claude Code для правил вывода. `force-for-plugin: true` — авто-активация при включении плагина. Заменяет ручной STYLE-блок в хуке.
- **Statusline** (`hooks/statusline.sh`) — показывает фазу пайплайна, ветку, % контекста. Активируется через `~/.claude/settings.json` пользователя.
- **PreToolUse bash safety** (`hooks/bash-safety.sh`) — блокирует опасные паттерны (`rm -rf /`, `git push --force main`, etc.) до выполнения.

## Commands Reference

| Command | When |
|---------|------|
| `/forge:start` | Session start |
| `/forge:unblocker` | **Phase 0** — навигатор направления: куда двигать проект |
| `/forge:new-task` | **Phase 1** — раскрутить сырую задачу |
| `/forge:refine-idea` | **Phase 1.5** — реалити-чек идеи до плана |
| `/forge:plan` | **Phase 2** — построить план |
| `/forge:critique` | **Phase 3** — 4 персоны рвут план |
| `/forge:execute` | **Phase 4** — реализация |
| `/forge:guide` | **Phase 5** — гайд по проекту: суть, устройство, экраны, решения с кодами, риски, план; версии в docs/guide/, после мержа обновляется сам |
| `/forge:sync` | After work — обновить docs |
| `/forge:validate` | Before merge — verify code vs plan |
| `/forge:cleanup` | Code quality audit |
| `/forge:discover` | Search marketplace |
| `/forge:graph` | Code knowledge graph |
| `/forge:product-map` | Project navigator (HTML) |
| `/forge:explain` | Visual "how does X work?" (HTML) |
| `/forge:investigate` | Problem diagnosis before fixing |
| `/forge:session-insights` | Session patterns analysis |
| `/forge:roadmap` | Управление картой целей (milestones) на человеческом языке |
| `/forge:init` | First time in project — создать `.forge/` структуру (L0/L1/L2) |
| `/forge:hookify` | Зафиксировать правило-хук в `.forge/hookrules/` («чтобы не повторялось») |
| `/forge:evolve` | Кластеризовать повторяющиеся боли из learnings/journal → предложить автоматизацию |
| `/forge:api-design` | Contract-first дизайн REST API |
| `/forge:design` | Design system: стиль, цвета, шрифты, UX |
| `/forge:migrate` | Миграции БД с планом отката |
| `/forge:deploy` | Deployment: Docker, CI/CD, health checks, rollback |
| `/forge:security-review` | Security-чеклист (OWASP) перед merge/deploy |

Полезные **встроенные** команды Claude Code (не наши):
- `/btw <вопрос>` — side-вопрос, ответ в overlay, **не попадает в историю**
- `/clear` — очистить контекст
- `/compact` — сжать историю в саммари

## Evals

`forge-plugin/evals/` — **каркас** Hamel-style error analysis, не рабочая система. `evals/README.md` — инструкция-workflow (план работ), корпус ещё не собран (планируется на базе ~116 сессий Антона). Реальное состояние:
- `error-analysis.tsv` — только строка заголовка, ни одного трейса
- `criteria/*.yml` — бинарные критерии по всем 7 фазам (unblocker, refine-idea и guide — `criteria/guide.yml` — добавлены), ни разу не применялись
- `transition-matrix.tsv` — пустая матрица на 7 фаз, все нули
- `corpus/raw/*.jsonl` и `taxonomy-v1.md` — описаны в workflow, пока не существуют

## Communication

- Russian unless asked otherwise
- Concise — no fluff (правила в Output Style "Forge Concise")
- Reference code as `file_path:line_number`
- One clarifying question at a time
- Anton — не-кодер, голосовой ввод: опечатки норма, не переспрашивать "имел ли ты в виду X"
