---
description: "Полная загрузка контекста проекта в начале сессии — цель, стадия, что работает, что сломано, dead-ends, последние сессии"
---

# FORGE Session Start

## Контекст проекта

!`cat docs/index.md 2>/dev/null || echo "docs/index.md не найден. Запустите /forge:init для инициализации."`

## Что работает / сломано

!`cat docs/status.md 2>/dev/null || echo "docs/status.md не найден"`

## Ключевые решения

!`cat docs/decisions.md 2>/dev/null || echo "docs/decisions.md не найден"`

## Провальные подходы (темы)

!`ls docs/dead-ends/ 2>/dev/null || echo "нет dead-ends"`

## Последние сессии

!`head -30 docs/journal.md 2>/dev/null || echo "docs/journal.md не найден"`

## Последние коммиты

!`git log --oneline -10 2>/dev/null || echo "не git репозиторий"`

## Текущая ветка и изменения

!`git branch --show-current 2>/dev/null`
!`git diff --stat 2>/dev/null | tail -5`

---

На основе загруженного контекста:

1. Покажи краткий дашборд: цель, стадия, текущая задача, что работает/сломано
2. Если есть dead-ends — запомни их, не повторяй эти подходы
3. Если есть незаконченная задача — предложи продолжить
4. Жди запрос пользователя

НЕ спрашивай "что делаем?" — ты уже знаешь из index.md.
