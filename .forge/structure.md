# Project Structure

## Expected Layout

forge-plugin/              — корневая директория плагина
  .claude-plugin/          — метаданные плагина (plugin.json, marketplace.json)
  lib/                     — JS утилиты (skills-core.js)
  hooks/                   — хуки (hooks.json, shell-скрипты)
  agents/                  — промпт-шаблоны субагентов
  commands/                — описания команд (MD файлы)
  skills/                  — скиллы (SKILL.md + поддержка)
    {skill-name}/          — директория скилла
      SKILL.md             — определение скилла (frontmatter + промпт)
      stack-hints/         — подсказки по стекам (опционально)
      scripts/             — вспомогательные скрипты (опционально)
      data/                — данные (опционально)
  docs/                    — документация проекта
  tests/                   — тестовые промпты
ideas/                     — идеи и предложения
.forge/                    — FORGE контекст (L0/L1/L2)
  library/                 — L2 спецификации по директориям
  plans/                   — планы реализации
  dead-ends/               — детальные описания провалов
