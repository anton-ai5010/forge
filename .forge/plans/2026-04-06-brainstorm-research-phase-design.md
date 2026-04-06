# Design: Research-фаза в forge:brainstorm

## Requirements

### Must-Have

**R1:** После получения идеи от пользователя, скилл запускает 3 параллельных research-агента перед уточняющими вопросами
AC: В SKILL.md прописаны 3 агента с фиксированными ролями, каждый запускается через Agent tool параллельно

**R2:** Research-агенты автономно выбирают источники (WebSearch, Context7, GitHub) исходя из задачи
AC: Каждый агент имеет инструкцию использовать релевантные инструменты; пользователь не выбирает источники вручную

**R3:** Результаты research синтезируются в единый отчёт, который показывается пользователю
AC: Пользователь видит структурированный отчёт (аналоги, технические решения, риски) до начала уточняющих вопросов

**R4:** Уточняющие вопросы учитывают результаты research
AC: Вопросы ссылаются на найденные аналоги/подходы, предлагают варианты на основе research

**R5:** Существующий flow (FORGE context → confirm → questions → requirements → approaches → design → design doc) сохраняется
AC: Все текущие шаги checklist остаются, research добавляется как новый шаг между confirm и questions

### Nice-to-Have

**R6:** 3 роли агентов: "аналоги и конкуренты", "технические решения и библиотеки", "риски и ограничения"
AC: Роли зафиксированы в SKILL.md с конкретными промптами для каждого агента

**R7:** Research-отчёт включается в итоговый дизайн-документ как секция "Research Findings"
AC: В `.forge/plans/*-design.md` есть секция с ключевыми находками из research

## Research Findings

Не применимо — изменение внутреннее, основано на понимании архитектуры скиллов.

## Architecture

### Подход: Research как отдельный шаг в checklist

Новый шаг **2.5 "Internet Research"** вставляется между "Confirm understanding" (шаг 2) и "Ask clarifying questions" (шаг 3).

После подтверждения идеи скилл:
1. Формулирует 3 поисковых задания на основе идеи пользователя
2. Запускает 3 агента параллельно через Agent tool
3. Собирает результаты в Research Report
4. Показывает отчёт пользователю
5. Переходит к уточняющим вопросам, информированным research-ом

### 3 агента и их роли

| Агент | Роль | Что ищет | Инструменты |
|-------|------|----------|-------------|
| **Analyst** | Аналоги и конкуренты | Существующие решения, open source проекты, как другие решали эту задачу | WebSearch, GitHub |
| **Technologist** | Технические решения | Библиотеки, фреймворки, API, паттерны реализации | WebSearch, Context7 |
| **Critic** | Риски и ограничения | Подводные камни, типичные ошибки, ограничения подходов, скейлинг | WebSearch |

Каждый агент получает промпт с описанием идеи + контекстом проекта (стек, стадия) и возвращает краткий отчёт (до 300 слов).

## Data Flow

```
User idea → Confirm goal → Formulate 3 search briefs →
  ┌─ Agent 1 (Analyst): WebSearch/GitHub → findings
  ├─ Agent 2 (Technologist): WebSearch/Context7 → findings
  └─ Agent 3 (Critic): WebSearch → findings
→ Synthesize into Research Report → Show to user →
→ Clarifying questions (informed by research) → Requirements → ... → Design doc
```

### Research Report — формат

```markdown
## Research Report

### Аналоги и существующие решения
- [название] — что делает, чем полезно/не подходит

### Технические подходы
- [подход] — библиотеки/инструменты, плюсы/минусы

### Риски и ограничения
- [риск] — почему важен, как митигировать

### Ключевые выводы
1-3 пункта, которые влияют на дизайн
```

### Обновлённый checklist flow

```
1. Load FORGE context (existing)
2. Confirm understanding of goal (existing)
2.5. Internet Research (NEW) — 3 parallel agents → report
3. Ask clarifying questions — informed by research (modified)
3.5. Define requirements (existing)
4. Propose 2-3 approaches (existing)
5. Present design (existing)
6. Write design doc — includes Research Findings section (modified)
7. Transition to writing-plans (existing)
```

## Error Handling

- Если агент не нашёл ничего полезного — его секция помечается "Релевантных результатов не найдено"
- Research не блокирует flow — если все 3 агента вернули пустоту, скилл продолжает с вопросами как раньше
- Таймаут агента — секция пропускается с пометкой

## Testing

Prompt-based тест в `forge-plugin/tests/` — запускает brainstorm с тестовой идеей и проверяет что research-фаза отработала (3 агента запущены, отчёт показан).

## Изменяемые файлы

- `forge-plugin/skills/brainstorming/SKILL.md` — основные изменения (новый шаг, промпты агентов, формат отчёта)
