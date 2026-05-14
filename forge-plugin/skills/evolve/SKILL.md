---
name: evolve
description: "Use when user says 'эволюция', 'evolve', 'кластеризуй боли', 'найди паттерны', 'что я повторяю', 'мои сквозные грабли', 'что автоматизировать', 'одни и те же грабли', 'из месяца в месяц одно', 'улучши плагин под меня'. Periodically (every 2 weeks) analyzes .forge/learnings.yml + .forge/journal.yml + memory's project_pain_patterns.md to find recurring user pain patterns across sessions, clusters them, and proposes automation: create hooks via /forge:hookify, new skills, commit helpers, workflow tweaks. Output is HTML report (visual-first for non-coder) with concrete suggestions ranked by frequency × impact. The user can accept/reject each suggestion."
---

# Evolve — превращаем повторяющиеся боли в автоматизацию

Цель: найти то что Антон правит/просит/ругает **из раза в раз**, и предложить превратить в правило плагина (хук, скилл, паттерн).

## Когда запускать

- Раз в 2 недели вручную
- Когда чувствуешь "опять одна и та же фигня"
- Перед большим релизом плагина — собрать накопленное

## Процесс

### 1. Собираем сырьё

Прочитай **все доступные источники**:

- `.forge/learnings.yml` — что записывал session-awareness skill
- `.forge/journal.yml` — история сессий
- `.forge/dead-ends.yml` — провальные подходы
- `.forge/decisions.yml` — архитектурные решения (для понимания трендов)
- `~/.claude/projects/-run-media-anton-Kingston4TB-plugin/memory/project_pain_patterns.md` — сквозные боли через 116+ сессий
- `forge-plugin/evals/error-analysis.tsv` если Антон заполнял — реальные провалы pipeline

### 2. Ищем паттерны (open coding → axial)

**Open coding:** выпиши все упоминания того что Антон правил/просил/ругал. Свободным текстом.

**Axial coding:** сгруппируй в 5-8 категорий. Примеры категорий:
- "Claude делает X несмотря на просьбу не делать"
- "Каждый раз приходится напоминать Y"
- "Pipeline проигнорил/потерял Z"
- "Одни и те же опечатки голоса не распознаются"
- "Документация устаревает — забываю обновить"
- "Сессии теряют контекст после возврата через дни"

Для каждой категории посчитай **частоту**: сколько раз встречалось.

### 3. Ранжируем

**Приоритет = частота × impact:**
- Часто (5+ раз) × Раздражает (тратит время каждый раз) = **HIGH**
- Часто × Низкий impact = MEDIUM
- Редко × Высокий impact = MEDIUM (но flag это как "потенциальный риск")
- Редко × Низкий impact = LOW (игнорируй)

### 4. Предлагаем автоматизацию

По каждой HIGH/MEDIUM категории — **конкретное предложение**:

| Категория | Решение |
|-----------|---------|
| Эмодзи в коде (4 раза) | `/forge:hookify` — block-правило на Edit/Write |
| Коммиты не на русском (3 раза) | `/forge:hookify` — warn-правило на git commit |
| Забываю /forge:sync (5 раз) | новый Stop-хук с reminder если есть незакоммиченное |
| Pipeline теряет контекст между сессиями (4 раза) | усилить state.yml + добавить journal-write в /execute |

Каждое предложение **с ссылкой на конкретный механизм** (хук / скилл / правило).

### 5. Создаём HTML-отчёт

Антон любит визуальное. Сохрани в `.forge/evolve/YYYY-MM-DD-evolve-report.html`:

```html
<!DOCTYPE html>
<html lang="ru">
<head>
  <title>Forge Evolve — отчёт за период</title>
  <style>/* clean cards layout */</style>
</head>
<body>
  <h1>Что у тебя повторяется</h1>
  <p>Период: <i>дата от</i> — <i>дата до</i> | Анализированно сессий: <i>N</i></p>

  <section class="high-priority">
    <h2>🔥 HIGH (стоит делать)</h2>
    <div class="card">
      <h3>Категория 1: ...</h3>
      <p><b>Частота:</b> 5 раз за период</p>
      <p><b>Примеры:</b> [3 коротких цитаты из journal]</p>
      <p><b>Предложение:</b> ...</p>
      <p><b>Реализация:</b> <code>/forge:hookify "..."</code></p>
    </div>
    <!-- ещё карточки -->
  </section>

  <section class="medium-priority">
    <h2>🟡 MEDIUM</h2>
    <!-- ... -->
  </section>

  <section class="low-priority">
    <h2>⚪ LOW (для справки)</h2>
    <!-- ... -->
  </section>
</body>
</html>
```

### 6. Покажи Антону

Кратко: *"Evolve-отчёт готов: 3 HIGH категории, 5 MEDIUM, 4 LOW. Открой `.forge/evolve/YYYY-MM-DD-evolve-report.html`. По каждой HIGH — конкретный путь автоматизации."*

### 7. Действие

Не делай ничего автоматически. Пусть Антон выберет:
- "захукай первое" → запускаем `/forge:hookify` с готовым промптом
- "пропусти эту" → следующая
- "отложи всё на потом" → отчёт остаётся в `.forge/evolve/`

## Чего НЕ делаешь

- **Не предлагай автоматизацию для одного случая.** Минимум 3 повтора или явная просьба Антона.
- **Не делай отчёт длиннее 1 экрана.** Если HIGH+MEDIUM получилось >10 пунктов — сократи до топ-10, остальное в LOW.
- **Не предлагай переписать половину плагина.** Маленькие хирургические правки.
- **Не создавай правила/скиллы без подтверждения.** Только показываешь предложения.

## Выход

- HTML-отчёт в `.forge/evolve/YYYY-MM-DD-evolve-report.html`
- Опционально — добавление новых entries в `.forge/learnings.yml` если нашёл что-то достойное общего знания
- После принятия Антоном — ссылки на следующие команды (`/forge:hookify`, etc.)
