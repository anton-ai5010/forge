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

---

## Step 3: Common-Ground Check

На основе загруженного контекста — покажи краткий дашборд (3-5 строк):

```
Проект: {name} ({stack}) — {stage}, прогресс {X}%
Цель: {goal}
Сейчас: {current task}
Блокеры: {blockers or "нет"}
Ключевое: {1 важный факт из dead-ends, decisions или learnings}
```

Спроси: **"Верно? Что исправить?"**

- Если пользователь корректирует — обнови понимание, при необходимости обнови .forge/index.yml
- Если подтверждает — переходи к Step 4

## Step 4: Ready to Work

- Если есть незаконченная задача (session.now) — предложи продолжить
- Если есть dead-ends — запомни их, не повторяй эти подходы
- Жди запрос пользователя

НЕ спрашивай "что делаем?" — ты уже знаешь из контекста.
