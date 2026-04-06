#!/bin/bash
# ============================================
# Инициализация Memory System для проекта
# Запускай в корне проекта: bash setup-memory.sh
# ============================================

MEMORY_DIR=".claude/memory"

echo "🧠 Инициализация Memory System..."

# Создаём структуру
mkdir -p "$MEMORY_DIR/failures"
mkdir -p "$MEMORY_DIR/decisions"
mkdir -p "$MEMORY_DIR/patterns"
mkdir -p "$MEMORY_DIR/blockers"
mkdir -p "$MEMORY_DIR/learnings"
mkdir -p "$MEMORY_DIR/todo"

# Копируем MEMORY.md (инструкции для агентов)
# Если MEMORY.md уже рядом со скриптом — копируем
if [ -f "MEMORY-template.md" ]; then
    cp "MEMORY-template.md" "$MEMORY_DIR/MEMORY.md"
    echo "  ✅ MEMORY.md скопирован из шаблона"
else
    echo "  ⚠️  MEMORY-template.md не найден — скопируй вручную в $MEMORY_DIR/MEMORY.md"
fi

# Создаём начальный project-state.md
PROJECT_NAME=$(basename "$(pwd)")
cat > "$MEMORY_DIR/project-state.md" << EOF
# $PROJECT_NAME — Состояние проекта

## Статус: Активная разработка
## Последнее обновление: $(date +%Y-%m-%d)

## Текущий фокус
[Описать текущую задачу]

## Что сделано
- [ ] Инициализирован Memory System — $(date +%Y-%m-%d)

## Следующие шаги
- [ ] [Описать следующий шаг]

## Стек
[Языки, фреймворки, БД]

## Активные блокеры
Нет
EOF
echo "  ✅ project-state.md создан"

# Создаём начальный conventions.md
cat > "$MEMORY_DIR/patterns/conventions.md" << 'EOF'
# Конвенции проекта

## Код
- [Добавь свои конвенции]

## Структура
- [Описание структуры проекта]

## Git
- Conventional commits: feat/fix/refactor/docs/test

## Тесты
- [Описание тестовой стратегии]
EOF
echo "  ✅ patterns/conventions.md создан"

# Создаём backlog
cat > "$MEMORY_DIR/todo/backlog.md" << 'EOF'
# Backlog

## Высокий приоритет
- [ ] [Добавь задачи]

## Средний приоритет

## Низкий приоритет / Идеи

## Завершено
EOF
echo "  ✅ todo/backlog.md создан"

# Добавляем в .gitignore если нужно (memory коммитим!)
# НЕ добавляем .claude/memory в gitignore — это нужно шарить

echo ""
echo "✅ Memory System инициализирован в $MEMORY_DIR"
echo ""
echo "Следующие шаги:"
echo "  1. Заполни $MEMORY_DIR/project-state.md — текущее состояние проекта"
echo "  2. Заполни $MEMORY_DIR/patterns/conventions.md — конвенции кодирования"
echo "  3. Добавь в агенты: memory: project в frontmatter"
echo "  4. git add .claude/memory && git commit -m 'feat: init memory system'"
