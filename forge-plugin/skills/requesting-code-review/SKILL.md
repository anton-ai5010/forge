---
name: requesting-code-review
description: "Use proactively when code is written, edited, or about to be merged — even if it 'looks fine'. RU: 'проверь код', 'отревьюй', 'глянь код', 'код-ревью', 'код норм?', 'всё ок?'. EN: 'review', 'code review', 'before merge'. Dispatches the forge:code-reviewer subagent to catch spec drift, missed edge cases, security issues, and silent regressions BEFORE they ship. Run after each major feature and always before merge."
---

# Requesting Code Review

**Role:** You are a senior code reviewer (10 years, reviewed 3000+ PRs across backend, frontend, and infra). Check spec compliance, code quality, and edge cases.
**Stakes:** Every issue you miss ships to production. Every false positive wastes developer time and erodes trust. Be precise — flag real problems, skip nitpicks.

Dispatch forge:code-reviewer subagent to catch issues before they cascade.

**Core principle:** Review early, review often.

## Схема проверки шага

Модели и потолки — по таблице `$CLAUDE_PLUGIN_ROOT/docs/model-roles.md`. Чеклист один на всех — `review-checklist.md`.

**1. Вход — в промпт, а не «изучи проект».** Дифф шага (`git diff <base>..HEAD` или `git diff` несохранённого) + секции «Задача» / «Критерий готовности» из `.forge/tasks/...` + «Как проверим» шага из плана. Шаблон — `code-reviewer.md`.

**2. Параллельно, одним сообщением:**
- пять Agent `subagent_type: forge:code-reviewer` (sonnet, effort medium, потолок 30 шагов) — промпт по шаблону, углы `логика` / `надёжность` / `тексты` / `интерфейс` / `тесты` (раздел «Углы» чеклиста). Нет страниц и шаблонов в диффе — без `интерфейс`; нет ничего, что читает владелец, — без `тексты`;
- Bash (фоном): дифф и задачу — во временные файлы, затем `bash $CLAUDE_PLUGIN_ROOT/skills/requesting-code-review/codex-review.sh review <diff-file> <task-file>` → JSON находок или `SKIP: <причина>`. Вызывай как есть — без `timeout`/обёрток (на маке `timeout` нет; скрипт сам ограничен 10 мин) и из любой папки проекта, включая соседние рабочие копии.

**3. Сверка находок.** Совпали у двух источников (тот же файл ± 5 строк и та же суть) — подтверждены. Критичные, которые нашёл только один источник, — **один** проверяющий пачкой: Agent `model: "sonnet"`, в промпте дифф + весь список спорных находок, вердикт «настоящая / нет» по каждой одним заходом. Никогда — отдельный помощник на каждую находку.

**3а. Второй круг — только для шагов `[важное]`.** Те же углы, свежие помощники, тот же полный дифф + список всего найденного в первом круге (Sonnet и Codex) с просьбой искать пропущенное (шаблон, раздел «Второй круг»). Codex второй раз не зовётся. Зачем: проверяющие от прогона к прогону находят разное, а «ищи, что пропустили» добирает хвост — на integration второй круг старой схемы давал находки, которых не было в первом.

**4. Финальный Opus** — Agent `subagent_type: forge:code-reviewer`, `model: "opus"`, `effort: "high"`, тот же промпт + подтверждённые находки. Получает всё найденное в обоих кругах. Зови, только если:
- шаг помечен `[важное]` (цены, оплаты, заказы, закупки, боевой сервер, удаление данных); нет метки — запасной признак: такие пути или слова в диффе;
- Sonnet и Codex разошлись по критичной находке, а пачечная проверка не сняла спор;
- проверяющий упёрся в потолок (ответ неполный) — сначала один повтор, если снова — Opus;
- Codex не сработал (SKIP «не ответил» / «не установлен») на шаге `[важное]` — днём и ночью одинаково, сам, сообщив об этом в отчёте.

**5. Исправление → повторная проверка только диффа фикса**, тем же Sonnet (шаблон, в `{DIFF}` — дифф фикса). Codex и Opus повторно не зовутся, если фикс не меняет логику денег / прода / удаления.

**6. Отчёт владельцу — одной строкой по смыслу, без цифр:**
- «проверка: чисто»;
- «проверка: нашла 2 проблемы — могло задвоить заказ; цена могла уйти ниже закупки — исправлено» (по фразе `в жизни` из каждой находки);
- «проверка не уложилась — позвал Opus»;
- деградация — в той же строке: «проверял один Sonnet: Codex не ответил»;
- «Codex выключен в проекте / не установлен» — один раз за сессию, дальше молча.

Подробности (кто что нашёл, вердикты) — в `.forge/notes/<slug>.md`, не в чат.

**Codex в проекте** включается строкой `codex_review: on` в `.forge/index.yml` (по умолчанию выключен). Он получает только дифф и задачу: запуск в пустой временной папке, с отдельной папкой настроек (без глобальных инструкций `~/.codex/AGENTS.md`), в песочнице, которая не пускает в личные папки; куски `.env*` / `*.pem` / `*secret*` вырезаются, при похожем на секрет — `SKIP`, ничего не отправляется.

**Воркфлоу** (схема для многих шагов разом) — правила в разделе «Если пишешь воркфлоу» скилла execute.

## When to Request Review

- После каждого шага с кодом в execute и в subagent-driven-development
- Перед мержем
- Когда застрял (свежий взгляд)

**Act on feedback:** critical — чинить сразу; important — до следующего шага; minor — записать. Проверяющий неправ — возразить с доказательством (код, тест).

## Red Flags

**Never:**
- Skip review because "it's simple"
- Ignore Critical issues
- Proceed with unfixed Important issues
- Argue with valid technical feedback
- Отдельный помощник-скептик на каждую находку (в integration это давало до 36 помощников на одну проверку) — только пачкой
- «Изучи проект» вместо диффа в промпте проверяющему

**If reviewer wrong:**
- Push back with technical reasoning
- Show code/tests that prove it works
- Request clarification

See template at: requesting-code-review/code-reviewer.md
