---
description: "Полная загрузка контекста проекта в начале сессии — цель, стадия, что работает, что сломано, dead-ends, последние сессии"
---

# FORGE Session Start

## Step 1: Load Project Context

!`cat .forge/index.yml 2>/dev/null || cat .forge/index.md 2>/dev/null || echo ".forge/ не найден. Запустите /forge:init для инициализации."`

## Step 2: Load Detail Files

### Что работает / сломано

!`cat .forge/status.yml 2>/dev/null || cat .forge/status.md 2>/dev/null || echo "нет status"`

### Ключевые решения

!`cat .forge/decisions.yml 2>/dev/null || cat .forge/decisions.md 2>/dev/null || echo "нет decisions"`

### Провальные подходы

!`cat .forge/dead-ends.yml 2>/dev/null || ls .forge/dead-ends/ 2>/dev/null || echo "нет dead-ends"`

### Уроки проекта

!`cat .forge/learnings.yml 2>/dev/null || echo "нет learnings"`

### Последние сессии

!`cat .forge/journal.yml 2>/dev/null || head -30 .forge/journal.md 2>/dev/null || echo "нет journal"`

### Git контекст

!`git log --oneline -10 2>/dev/null || echo "не git репозиторий"`
!`git branch --show-current 2>/dev/null`
!`git diff --stat 2>/dev/null | tail -5`

### Карта проекта из GitHub (если есть github-sync)

!`if [ -f .forge/.github-pinned-id ] && command -v gh >/dev/null 2>&1; then gh issue view "$(cat .forge/.github-pinned-id)" --json body -q .body 2>/dev/null > /tmp/.forge-pinned-body.md && echo "PINNED_BODY_FILE: /tmp/.forge-pinned-body.md"; else echo "нет github-sync в этом проекте (это нормально)"; fi`

### GitHub-sync настроен, но не включён? (старый forge-проект)

!`SYNC=$(find ~/.claude/plugins -path '*/forge*/skills/github-sync/sync.sh' 2>/dev/null | head -1); [ -n "$SYNC" ] && bash "$SYNC" should-offer || echo "no"`

**Если выше `yes`** — проект на GitHub и `gh` залогинен, но `github_sync` ещё не задан (forge заводили до этой фичи). В Step 4 один раз предложи включить. **Если `no`** — пропусти молча, ничего не спрашивай.

---

## Step 3: Common-Ground Check

На основе загруженного контекста — покажи краткий дашборд (3-7 строк):

```
Проект: {name} ({stack}) — {stage}, прогресс {X}%
Цель: {goal}
Сейчас: {current task}
Блокеры: {blockers or "нет"}
Ключевое: {1 важный факт из dead-ends, decisions или learnings}
```

**Если выше есть `PINNED_BODY_FILE:` строка** — Прочитай этот файл (cat) и **сжми** его в 2-3 строки человеческим языком (не выводи сырой markdown с маркерами и эмодзи-барами):
- "Цели в работе: {имена через запятую}, прогресс {N}% по основной"
- "Последняя задача: {название}"
- "Открытых задач сейчас: {N}"

Спроси: **"Верно? Что исправить?"**

- Если пользователь корректирует — обнови понимание, при необходимости обнови .forge/index.yml
- Если подтверждает — переходи к Step 4

## Step 4: Ready to Work

- **Если в Step 2 GitHub-проверка вернула `yes`** — один раз спроси: "У тебя проект на GitHub, а синхронизация ещё не включена. Включить? Тогда задачи и карта проекта будут вестись Issues. (да/нет)"
  - "да" → `SYNC=$(find ~/.claude/plugins -path '*/forge*/skills/github-sync/sync.sh' | head -1); bash "$SYNC" enable && bash "$SYNC" diagnose && bash "$SYNC" bootstrap-labels && bash "$SYNC" ensure-pinned-map` — покажи вывод diagnose если есть warnings.
  - "нет" → `bash "$SYNC" disable` (больше не спросит).
- Если есть незаконченная задача (session.now) — предложи продолжить
- Если есть dead-ends — запомни их, не повторяй эти подходы
- Жди запрос пользователя

НЕ спрашивай "что делаем?" — ты уже знаешь из контекста.
