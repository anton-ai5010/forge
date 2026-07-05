# Forge Plugin — Runtime Flow

> How the plugin works at runtime: hooks, context injection, skill invocation, and data flow.
> Источник правды — код в `hooks/` (`hooks.json` + `*.sh`). Здесь — архитектура без привязки к номерам строк.

---

## 0. Зарегистрированные хуки (hooks.json)

| Событие | Matcher | Скрипт / команда | Что делает |
|---------|---------|------------------|------------|
| `SessionStart` | `startup\|resume\|clear\|compact` | `session-start.sh` | Короткое интро: версия, пайплайн, ROUTING + DOC DISCIPLINE |
| `UserPromptSubmit` | — (каждый промпт) | `context-inject.sh` | Инжектит L0 контекст: index.yml + branch + git log + graph hint |
| `PreToolUse` | `Bash` | `bash-safety.sh` | Блокирует опасные bash-команды до выполнения |
| `PreToolUse` | `Bash\|Edit\|Write\|NotebookEdit` | `user-rules-check.sh` | Применяет пользовательские правила из `.forge/hookrules/*.md` |
| `Stop` | — | inline-команда | Случайный mp3 из `sounds/stop/` (async) |
| `PermissionRequest` | — | inline-команда | Случайный mp3 из `sounds/permission/` (async) |

Отдельно (НЕ в hooks.json): `statusline.sh` — механизм statusline Claude Code, подключается через `~/.claude/settings.json` пользователя.

---

## 1. Session Lifecycle (Big Picture)

```mermaid
flowchart TB
    subgraph SESSION_START["🟢 Session Start (startup/resume/clear/compact)"]
        A[Claude Code запускается] --> B{SessionStart hook}
        B --> C[session-start.sh]
        C --> D["Короткое интро (НЕ полный using-forge):<br/>• версия плагина из plugin.json<br/>• таблица 6 фаз пайплайна<br/>• ROUTING: как выбирать L1 файлы по тегам<br/>• DOC DISCIPLINE: писать decisions/dead-ends/learnings сразу"]
        D --> E["using-forge — lazy-load:<br/>Claude подгружает через Skill tool,<br/>когда реально нужно"]
    end

    subgraph EVERY_PROMPT["🔄 Каждый промпт пользователя"]
        G[Пользователь пишет сообщение] --> H{UserPromptSubmit hook}
        H --> I[context-inject.sh]
        I --> J{.forge/index.yml существует?}
        J -- "Нет (и нет legacy index.md)" --> K[Hook завершается молча]
        J -- Да --> L["Собирает контекст:"]
        L --> L1[".forge/index.yml<br/>(cap 2500 байт, дальше — note об обрезке)"]
        L --> L2["git branch --show-current"]
        L --> L3["git log --oneline -3"]
        L --> L4["Graph hint — только если есть<br/>.forge/graph.json И установлен graphify"]
        L1 & L2 & L3 & L4 --> M["JSON additionalContext → в промпт Claude"]
    end

    subgraph CLAUDE_THINKS["🧠 Claude обрабатывает"]
        M --> N["Claude получает:<br/>сообщение пользователя<br/>+ intro из session-start<br/>+ L0 project context"]
        N --> O{Подходит ли какой-то скилл?}
        O -- "Да (даже 1%)" --> P["Вызывает Skill tool"]
        O -- "Точно нет" --> Q["Отвечает напрямую"]
    end

    SESSION_START --> EVERY_PROMPT
    EVERY_PROMPT --> CLAUDE_THINKS
```

Legacy: если вместо `index.yml` найден старый `.forge/index.md` — он инжектится целиком (fallback, новый формат приоритетнее).

---

## 2. Context Injection — What Claude Sees on Every Prompt

```mermaid
flowchart LR
    subgraph INJECTED["Авто-инжект (невидим пользователю)"]
        direction TB
        IC1["Интро session-start<br/>(один раз за сессию):<br/>пайплайн + ROUTING + DOC DISCIPLINE"]
        IC2[".forge/index.yml (L0)<br/>• goal, stage, task<br/>• catalog L1 файлов с тегами<br/>cap 2500 байт"]
        IC3["Git: branch + 3 последних коммита"]
        IC4["Graph hint (опционально):<br/>«есть graph.json, попробуй graphify query»"]
    end

    subgraph USER_MSG["Сообщение пользователя"]
        UM["'Добавь авторизацию<br/>через JWT'"]
    end

    INJECTED --> CLAUDE["Claude видит ВСЁ вместе"]
    USER_MSG --> CLAUDE
```

Правила STYLE в хуках больше не живут — они в нативном Output Style `output-styles/forge-concise.md` (auto-activated при включении плагина). ROUTING и DOC DISCIPLINE инжектятся один раз в session-start, а не на каждый промпт.

---

## 3. Guard Hooks — PreToolUse

### bash-safety.sh (matcher: Bash)

Парсит `tool_input.command` из JSON (через python3) и блокирует опасные категории паттернов **до выполнения**:

- `rm -rf` на критические пути (`/`, `~`, `$HOME`)
- `git push --force` в main/master
- `git reset --hard` к старому коммиту
- `dd` на блочные устройства
- `chmod 777` на системные каталоги
- удаление `.env` / credentials / ключей
- `curl | bash` — запуск скриптов из интернета

Контракт: exit 0 — разрешить; exit 2 — заблокировать, причина уходит Claude через stderr.

### user-rules-check.sh (matcher: Bash|Edit|Write|NotebookEdit)

Применяет **пользовательские** правила из `.forge/hookrules/*.md` (создаются скиллом `/forge:hookify`). Каждое правило — markdown с frontmatter:

```yaml
matcher: Bash|Edit|Write   # на каких инструментах действует
action: block | warn       # block = exit 2, warn = JSON permissionDecision allow + reason
pattern: 'regex'           # что искать в команде/контенте
message: "..."             # объяснение Claude, почему сработало
```

Правила читаются заново на каждый tool use — рестарт сессии не нужен. Нет `.forge/hookrules/` — хук молча пропускает.

---

## 4. The 6-Phase Pipeline (0 → 1 → 1.5 → 2 → 3 → 4)

Хуки пайплайн не ведут — его ведут скиллы/команды с auto-handoff (после «ОК» пользователя Claude сам инвокает следующую фазу).

```mermaid
flowchart TB
    A["Запрос пользователя"] --> B{"Что именно нужно?"}
    B -- "Непонятно КУДА двигать проект / застрял" --> P0["/forge:unblocker<br/>Phase 0: Direction"]
    B -- "Новая задача / фича" --> P1["/forge:new-task<br/>Phase 1: Understanding"]
    B -- "Баг или проблема" --> DBG["/forge:investigate или<br/>systematic-debugging"]
    B -- "Простой read-only вопрос" --> ANS["Прямой ответ"]

    P0 --> P0A["Карта проекта + все направления<br/>+ рекомендация (выбор за пользователем)"]
    P0A --> P1

    P1 --> P1A["Логические вопросы по одному,<br/>технику ищет сам в коде"]
    P1A --> P1OUT[".forge/tasks/YYYY-MM-DD-slug.md<br/>задача + критерий готовности"]
    P1OUT --> P15["/forge:refine-idea<br/>Phase 1.5: Idea Check"]

    P15 --> P15A["Реалити-чек идеи фактами проекта:<br/>decisions / dead-ends / status / код.<br/>Диалог, не отчёт"]
    P15A --> P2["/forge:plan<br/>Phase 2: Planning"]

    P2 --> P2A["Шаги + обязательные чекпоинты<br/>на смысловых границах"]
    P2A --> P2R{"Дальний блокер?"}
    P2R -- Да --> P2B["→ .forge/blockers/<br/>отдельная сессия"]
    P2R -- Нет --> P2OUT[".forge/plans/YYYY-MM-DD-slug.md"]
    P2OUT --> P3["/forge:critique<br/>Phase 3: Critique"]

    P3 --> P3PAR["4 персоны параллельно:<br/>• Skeptic<br/>• Pragmatist<br/>• Architect<br/>• User Advocate"]
    P3PAR --> P3ES["Синтез правок +<br/>Execution Strategy"]
    P3ES --> P3G{"План одобрен?"}
    P3G -- Нет --> P2
    P3G -- Да --> P4["/forge:execute<br/>Phase 4: Implementation"]

    P4 --> P4BR["Ветка feat/slug<br/>(одна задача = одна ветка)"]
    P4BR --> P4LOOP["Реализация; тяжёлое — субагентам"]
    P4LOOP --> P4CHK{"Чекпоинт из плана?"}
    P4CHK -- Да --> P4STOP["СТОП: ждём пользователя"]
    P4STOP --> P4LOOP
    P4CHK -- "Всё сделано" --> SYNC["/forge:sync → .forge/*.yml<br/>«мержим» → finishing-a-development-branch"]
```

### Phase contracts

| Phase | Command | Outputs | Gate to next phase |
|-------|---------|---------|--------------------|
| 0. Direction | `/forge:unblocker` | `direction.yml` + `ROADMAP.md`, первый шаг → new-task | Пользователь выбрал направление |
| 1. Understanding | `/forge:new-task` | `.forge/tasks/*.md`: задача + критерий готовности | Задача подтверждена пользователем |
| 1.5. Idea Check | `/forge:refine-idea` | Доработанный task-файл (опц. `## Доработано на разборе`) | Идея выдержала реалити-чек |
| 2. Planning | `/forge:plan` | `.forge/plans/*.md`: шаги + чекпоинты | План полный, блокеры покрыты |
| 3. Critique | `/forge:critique` | Правки в плане + Execution Strategy | Critical issues закрыты |
| 4. Implementation | `/forge:execute` | Код, тесты, обновлённый `.forge/` | Чекпоинты пройдены, критерий готовности проверен |

### GitHub Sync (опционально)

При `github_sync: true` в `.forge/index.yml` фазы зеркалятся на GitHub через скилл `github-sync` (`skills/github-sync/sync.sh`):
- `/forge:new-task` → Issue с задачей и критерием готовности
- `/forge:plan` → дочерние Sub-issues на шаги плана
- Pinned Issue — карта проекта (задачи по приоритетам/milestones) + авто-шапка README
- `/forge:roadmap` — управление картой целей на человеческом языке

Runtime-артефакты в проекте пользователя (gitignored): `.forge/.github-pinned-id`, `.forge/.github-issue-<slug>`, `.forge/.github-substeps-<slug>`, `.forge/.github-bootstrapped`.

---

## 5. Data Flow — What Reads/Writes What

```mermaid
flowchart TB
    subgraph HOOKS["Hooks (автоматические)"]
        H1["session-start.sh<br/>ЧИТАЕТ: .claude-plugin/plugin.json (версия)"]
        H2["context-inject.sh<br/>ЧИТАЕТ: .forge/index.yml<br/>.forge/graph.json (счётчик нод)<br/>git log, git branch"]
        H3["bash-safety.sh<br/>ЧИТАЕТ: tool_input команды"]
        H4["user-rules-check.sh<br/>ЧИТАЕТ: .forge/hookrules/*.md"]
        H5["statusline.sh<br/>ЧИТАЕТ: .forge/state.yml, git branch"]
    end

    subgraph SKILLS_READ["Скиллы ЧИТАЮТ"]
        SR1["new-task / refine-idea / plan<br/>← .forge/decisions.yml, dead-ends.yml,<br/>status.yml, library/"]
        SR2["forge-context<br/>← index.yml catalog → L1 файлы по тегам"]
        SR3["critique / execute<br/>← .forge/plans/*.md"]
        SR4["unblocker<br/>← вся .forge память + код"]
    end

    subgraph SKILLS_WRITE["Скиллы ПИШУТ"]
        SW1["new-task → .forge/tasks/*.md<br/>plan → .forge/plans/*.md"]
        SW2["unblocker → .forge/direction.yml + ROADMAP.md"]
        SW3["session-awareness → index.yml (session state),<br/>decisions.yml, dead-ends.yml, journal.yml, status.yml"]
        SW4["/forge:sync → .forge/*.yml по факту изменений<br/>/forge:init → ВСЮ структуру .forge/"]
        SW5["hookify → .forge/hookrules/*.md"]
        SW6["github-sync → Issues, Pinned Issue, README шапка"]
    end

    subgraph DOCS[".forge/ (персистентная память, gitignored)"]
        D1["index.yml — L0: goal/stage/task + catalog"]
        D2["L1: map.yml, conventions.yml, status.yml,<br/>decisions.yml, dead-ends.yml, journal.yml,<br/>learnings.yml, direction.yml"]
        D3["L2: library/*/spec.yml, dead-ends/*.md"]
        D4["tasks/ · plans/ · blockers/ · hookrules/"]
        D5["graph.json — knowledge graph (/forge:graph)"]
    end

    HOOKS --> DOCS
    SKILLS_READ --> DOCS
    SKILLS_WRITE --> DOCS
```

---

## 6. Token Economy

```
┌─────────────────────────────────────────────────────────┐
│                   БЕЗ FORGE                              │
│                                                          │
│  Claude читает исходники: 40,000+ токенов                │
│  Контекст теряется между сессиями                        │
│  Повторяет ошибки из прошлых попыток                     │
│  Каждая сессия — с нуля                                  │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                   С FORGE                                │
│                                                          │
│  SessionStart hook (один раз):                           │
│    короткое интро + ROUTING + DOC DISCIPLINE             │
│    (НЕ полный using-forge — тот lazy-load)               │
│                                                          │
│  Каждый промпт (context-inject):                         │
│    .forge/index.yml (cap 2500 байт) + branch             │
│    + git log -3 + graph hint                             │
│    — порядка нескольких сотен токенов на промпт          │
│                                                          │
│  По запросу (Skill tool):                                │
│    SKILL.md конкретного скилла — только когда нужен      │
│    L1/L2 файлы .forge — только по тегам каталога         │
│                                                          │
│  Результат: сотни токенов вместо 40,000+ на промпт       │
└─────────────────────────────────────────────────────────┘
```

---

## 7. Timeline — Typical Development Session

```
Время   Событие                              Контекст Claude
──────  ─────────────────────────────────     ─────────────────────────
t=0     Claude Code запускается               пусто
        ↓ SessionStart hook                   + интро (фазы, ROUTING, DOC DISCIPLINE)

t=1     User: "хочу добавить JWT авторизацию"
        ↓ UserPromptSubmit hook               + index.yml + branch + git log
        ↓ Claude → /forge:new-task            Phase 1: Understanding
        ↓ Логические вопросы по одному        технику ищет сам в коде

t=3     Задача + критерий готовности записаны
        ↓ Claude → /forge:refine-idea         Phase 1.5: Idea Check
        ↓ Реалити-чек фактами проекта         та ли проблема? нет ли проще?

t=5     Идея выдержала разбор
        ↓ Claude → /forge:plan                Phase 2: Planning
        ↓ Шаги + чекпоинты                    план в .forge/plans/

t=7     План готов
        ↓ Claude → /forge:critique            Phase 3: Critique
        ↓ Skeptic/Pragmatist/Architect/       правки + Execution Strategy
          User Advocate параллельно
        ↓ User одобряет (если контекст
          тяжёлый — рекомендация: новый чат)

t=9     User: "выполняй"
        ↓ Claude → /forge:execute             Phase 4: Implementation
        ↓ Ветка feat/<slug>                   одна задача = одна ветка
        ↓ Тяжёлое — субагентам                чтение файлов, тесты, логи
        ↓ Чекпоинт из плана → стоп → "go"
        ...

t=15    Все шаги выполнены
        ↓ Claude → /forge:sync                обновляет .forge/*.yml
        ↓ session-awareness                   пишет journal.yml

t=16    User: /forge:validate
        ↓ Проверяет код vs план vs docs       read-only аудит

t=17    User: "мержим"
        ↓ finishing-a-development-branch       тесты → merge в master → ветка удалена
```
