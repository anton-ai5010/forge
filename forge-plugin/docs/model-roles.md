# Кто на какой модели — таблица ролей

Один источник правды: какая модель и сколько «думать» (effort) у каждого помощника плагина. Скиллы ссылаются сюда как `$CLAUDE_PLUGIN_ROOT/docs/model-roles.md`. Меняешь роль — меняешь здесь и в месте вызова (тест `tests/hooks/test-model-roles.sh` сверяет).

Зачем: подписка ограничена недельным лимитом. Помощник без явной модели наследует модель основного чата (часто Opus) — это главный источник лишнего расхода. Поэтому **ни один помощник не запускается без явной модели**.

Ступени: 🟢 дешёвый (haiku) · 🟡 средний (sonnet) · 🔴 дорогой (opus) · ⚪ вне лимита Claude (Codex, подписка ChatGPT).

**Fable — только по явному решению владельца, плагин его не назначает.**

## Таблица

| Роль | Где | Модель | effort | maxTurns | Почему |
|---|---|---|---|---|---|
| разведчик: поиск / список / подсчёт | execute `[agent]`-поиск, unblocker-сканы, init-сканы, refine-idea grep, problem-investigation логи | 🟢 haiku (`forge:scout`) | low | 15 | механика, ошибка дешёвая и видна |
| исследование с выводами | product-mapping (2), project-guide (6), session-insights (4), code-cleanup анализ, systematic-debugging | 🟡 sonnet | medium | — | здравый смысл, не глубина |
| документация / структура | forge-documenter, structure-enforcer, init library-доки | 🟡 sonnet | low | — | по образцу |
| проверяющий кода | `forge:code-reviewer` ×5 углов (логика / надёжность / тексты / интерфейс / тесты), на `[важное]` — два круга; оба проверяющих в subagent-driven-development | 🟡 sonnet | medium | 30 | ищет по диффу; один «на всё» пропускает тексты, сбои и тесты; Codex — второй взгляд |
| второй взгляд другой семьи | Codex: проверка кода, 5-й критик плана | ⚪ codex (модель из `~/.codex/config.toml` или легче) | medium | — | ошибки GPT и Claude мало совпадают; лимит Claude не тратит |
| проверка находок (пачкой) | verify в воркфлоу | 🟡 sonnet | medium | 30 | подтверждает готовый список, не ищет |
| финальный проверяющий | деньги / прод / удаление, спор Sonnet↔Codex, Codex не сработал на `[важное]`, проверяющий не уложился | 🔴 opus | high | 40 | цена ошибки высокая |
| критики | Скептик, Архитектор — 🔴 opus/high; Прагматик, Адвокат — 🟡 sonnet/medium; + Codex | см. слева | см. слева | — | дыры и архитектура требуют глубины |
| исполнитель кода | subagent-driven implementer, execute `[agent]`-код, фиксы code-cleanup / dispatching-parallel-agents | 🟡 sonnet; 🔴 opus если `[важное]` | medium / high | — | по готовому плану; Opus где ошибка дорогая |
| основной чат | — | выбирает владелец | подсказка | — | смена модели в чате сбрасывает кеш (решение `no-jev-model-router`) |

Разведчик на haiku прошёл сравнение с sonnet на 3 реальных задачах integration без ошибок (2026-10-13, `.forge/notes/2026-10-13-models-and-costs-measure.md`).

`[важное]` — шаг трогает цены, оплаты, заказы, закупки, боевой сервер или удаление данных. Метку ставит critique в Execution Strategy; запасной признак — такие пути/слова в диффе.

## Как применять

- **Одиночный помощник** — тип из `agents/` (модель уже в его frontmatter) или `model` прямо в вызове Agent.
- **Воркфлоу** — `model` и `effort` у **каждого** `agent()`; метки с фиксированными префиксами `impl:` `review:` `verify:` `final-review:` `fix:` (по ним считается расход). Подробно — раздел «Если пишешь воркфлоу» в скилле execute.
- **Роль не из таблицы** — бери ближайшую; в сомнении — sonnet.
- **effort** у одиночного вызова Agent не задаётся (у инструмента есть только `model`) — он берётся из frontmatter типа агента (`agents/*.md`) или из `agent(..., {effort})` в воркфлоу. Для критиков и исследователей, запускаемых обычным Agent, effort — колонка-ориентир, не гарантия.
- **Потолок шагов (maxTurns)** — помощник, упёршийся в потолок, возвращает неполный ответ: один повтор, потом Opus.

## Инвентарь мест вызова

Каждая строка — место, где плагин запускает помощника. Тест ищет в файле строку с «якорем» и в ближайших строках после неё — ожидаемую модель (`model: "<модель>"` или `forge:scout`).

<!-- inventory:start -->
| Файл | Якорь | Модель |
|---|---|---|
| skills/critique/SKILL.md | Скептик — `model: | opus |
| skills/critique/SKILL.md | Архитектор — `model: | opus |
| skills/critique/SKILL.md | Прагматик — `model: | sonnet |
| skills/critique/SKILL.md | Адвокат пользователя — `model: | sonnet |
| skills/project-guide/SKILL.md | запусти 6 субагентов | sonnet |
| skills/product-mapping/SKILL.md | Dispatch 2 subagents in parallel | sonnet |
| skills/session-insights/SKILL.md | Dispatch 4 agents simultaneously | sonnet |
| skills/code-cleanup/SKILL.md | Scan in parallel | sonnet |
| skills/code-cleanup/SKILL.md | When fixing, dispatch parallel agents | sonnet |
| skills/dispatching-parallel-agents/SKILL.md | ### 3. Dispatch in Parallel | sonnet |
| skills/systematic-debugging/SKILL.md | **Parallelize:** | sonnet |
| skills/project-unblocker/SKILL.md | Запускай **параллельных субагентов** | scout |
| commands/init.md | Launch 3-4 subagents simultaneously | scout |
| skills/refine-idea/SKILL.md | **делегируй субагенту** | scout |
| skills/problem-investigation/SKILL.md | dispatch subagents in parallel | scout |
| skills/subagent-driven-development/SKILL.md | ## Модели помощников | sonnet |
| commands/init.md | dispatch parallel subagents: one per source directory | sonnet |
| skills/subagent-driven-development/implementer-prompt.md | Agent tool (general-purpose): | sonnet |
| skills/subagent-driven-development/spec-reviewer-prompt.md | Agent tool (general-purpose): | sonnet |
| skills/subagent-driven-development/code-quality-reviewer-prompt.md | Agent tool (subagent_type: forge:code-reviewer): | sonnet |
| commands/sync.md | subagent_type: forge:structure-enforcer | sonnet |
| commands/sync.md | subagent_type: forge:forge-documenter | sonnet |
<!-- inventory:end -->

Агенты (`agents/*.md`) — модель и effort во frontmatter:

<!-- agents:start -->
| Агент | model | effort | maxTurns |
|---|---|---|---|
| code-reviewer | sonnet | medium | 30 |
| forge-documenter | sonnet | low | — |
| structure-enforcer | sonnet | low | — |
| scout | haiku | low | 15 |
<!-- agents:end -->
