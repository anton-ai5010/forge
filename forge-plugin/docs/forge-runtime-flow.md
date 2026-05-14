# Forge Plugin — Runtime Flow Visualization

> How the plugin works at runtime: hooks, context injection, skill invocation, and data flow.

---

## 1. Session Lifecycle (Big Picture)

```mermaid
flowchart TB
    subgraph SESSION_START["🟢 Session Start"]
        A[Claude Code запускается] --> B{SessionStart hook}
        B --> C[session-start.sh]
        C --> D["Читает skills/using-forge/SKILL.md"]
        D --> E["Инжектит полный текст using-forge<br/>в контекст Claude"]
        E --> F["Claude теперь знает:<br/>• какие скиллы есть<br/>• когда их вызывать<br/>• правила приоритетов"]
    end

    subgraph EVERY_PROMPT["🔄 Каждый промт пользователя"]
        G[Пользователь пишет сообщение] --> H{UserPromptSubmit hook}
        H --> I[context-inject.sh]
        I --> J{.forge/index.md существует?}
        J -- Нет --> K[Hook завершается молча]
        J -- Да --> L["Собирает контекст:"]
        L --> L1[".forge/index.md (~400 токенов)"]
        L --> L2["Список файлов в .forge/dead-ends/"]
        L --> L3["git log --oneline -3"]
        L --> L4["git branch --show-current"]
        L1 & L2 & L3 & L4 --> M["Инжектит JSON в промт Claude"]
    end

    subgraph CLAUDE_THINKS["🧠 Claude обрабатывает"]
        M --> N["Claude получает:<br/>сообщение пользователя<br/>+ using-forge правила<br/>+ project context"]
        N --> O{Подходит ли какой-то скилл?}
        O -- "Да (даже 1%)" --> P["Вызывает Skill tool"]
        O -- "Точно нет" --> Q["Отвечает напрямую"]
    end

    SESSION_START --> EVERY_PROMPT
    EVERY_PROMPT --> CLAUDE_THINKS
```

---

## 2. Context Injection — What Claude Sees on Every Prompt

```mermaid
flowchart LR
    subgraph INJECTED["Авто-инжект (невидим пользователю)"]
        direction TB
        IC1["using-forge skill<br/>(из SessionStart)"]
        IC2[".forge/index.md<br/>• Goal проекта<br/>• Current task<br/>• Session state<br/>~400 токенов"]
        IC3["Dead-ends список<br/>(только имена файлов)"]
        IC4["Git: branch + 3 коммита"]
    end

    subgraph USER_MSG["Сообщение пользователя"]
        UM["'Добавь авторизацию<br/>через JWT'"]
    end

    INJECTED --> CLAUDE["Claude видит ВСЁ вместе"]
    USER_MSG --> CLAUDE
```

---

## 3. The 4-Phase Pipeline

Forge organizes любую новую задачу в строгий 4-фазный пайплайн. Каждая фаза — отдельная команда с явным переходом.

```mermaid
flowchart TB
    A["Claude получает задачу"] --> B{"Что именно нужно?"}
    B -- "Новая задача / фича" --> P1["/forge:new-task<br/>Phase 1: Understanding"]
    B -- "Баг или проблема" --> DBG["/forge:systematic-debugging"]
    B -- "Простой read-only вопрос" --> ANS["Прямой ответ"]

    P1 --> P1A["Сократический диалог<br/>уточнение требований<br/>чтение .forge/decisions, dead-ends"]
    P1A --> P1G{"HARD GATE:<br/>понимание полное?"}
    P1G -- Нет --> P1A
    P1G -- Да --> P2["/forge:plan<br/>Phase 2: Planning"]

    P2 --> P2A["Декомпозиция на задачи<br/>2-5 мин каждая"]
    P2A --> P2R{"Найден дальний блокер?"}
    P2R -- Да --> P2REC["Рекурсия: under-plan<br/>для блокера"]
    P2REC --> P2A
    P2R -- Нет --> P2OUT[".forge/plans/YYYY-MM-DD-name.md"]
    P2OUT --> P3["/forge:critique<br/>Phase 3: Critique"]

    P3 --> P3PAR["4 персоны параллельно:<br/>• Architect<br/>• Security<br/>• UX<br/>• Pragmatist"]
    P3PAR --> P3ES["Execution Strategy<br/>(порядок, риски, чекпоинты)"]
    P3ES --> P3G{"План одобрен?"}
    P3G -- Нет --> P2
    P3G -- Да --> P4["/forge:execute<br/>Phase 4: Implementation"]

    P4 --> P4SUB["Запуск через субагентов"]
    P4SUB --> P4LOOP["Задача → TDD → diff → review"]
    P4LOOP --> P4CHK{"Чекпоинт?"}
    P4CHK -- Да --> P4STOP["СТОП: ждём подтверждения"]
    P4STOP --> P4LOOP
    P4CHK -- Нет --> P4MORE{"Ещё задачи?"}
    P4MORE -- Да --> P4LOOP
    P4MORE -- Нет --> SYNC["/forge:sync — обновляет .forge/"]
```

### Phase contracts

| Phase | Command | Outputs | Gate to next phase |
|-------|---------|---------|--------------------|
| 1. Understanding | `/forge:new-task` | Sharpened задача, открытые вопросы закрыты | Понимание подтверждено пользователем |
| 2. Planning | `/forge:plan` | `.forge/plans/*.md` с задачами 2-5 мин; рекурсия на блокеры | План полный, блокеры покрыты |
| 3. Critique | `/forge:critique` | Замечания от 4 персон + Execution Strategy | Critical issues закрыты, стратегия принята |
| 4. Implementation | `/forge:execute` | Код, тесты, обновлённый `.forge/` | Все задачи зелёные, чекпоинты пройдены |

---

## 4. Phase 4: Execute via Subagents

```mermaid
sequenceDiagram
    participant U as Пользователь
    participant M as Main Claude
    participant S1 as Subagent (task 1)
    participant S2 as Subagent (task 2)
    participant R as Review Agent

    U->>M: /forge:execute
    M->>M: Читает .forge/plans/plan.md + critique
    
    Note over M: Задача 1
    M->>S1: Промт с задачей + контекст
    S1->>S1: TDD: test → code → refactor
    S1-->>M: Результат + diff

    M->>R: Review: соответствие плану + качество
    R-->>M: OK / замечания

    Note over M,U: Чекпоинт (если задан в стратегии)
    M-->>U: Готов следующий шаг — продолжать?
    U-->>M: Да

    Note over M: Задача 2
    M->>S2: Следующая задача (чистый контекст)
    S2->>S2: TDD: test → code → refactor
    S2-->>M: Результат + diff

    M->>R: Review
    R-->>M: OK

    M->>M: /forge:sync — обновляет .forge/
    M-->>U: Отчёт о выполнении
```

Ключевое:
- Каждая задача — отдельный субагент с чистым контекстом.
- Review — отдельный агент, независимый от исполнителя.
- На чекпоинтах из Execution Strategy main Claude останавливается и ждёт пользователя.

---

## 5. Data Flow — What Reads/Writes What

```mermaid
flowchart TB
    subgraph HOOKS["Hooks (автоматические)"]
        H1["session-start.sh<br/>ЧИТАЕТ: using-forge/SKILL.md"]
        H2["context-inject.sh<br/>ЧИТАЕТ: .forge/index.md<br/>.forge/dead-ends/*<br/>git log, git branch"]
    end

    subgraph SKILLS_READ["Скиллы ЧИТАЮТ"]
        SR1["new-task<br/>← .forge/dead-ends/*<br/>← .forge/decisions.md<br/>← .forge/library/"]
        SR2["forge-context<br/>← .forge/index.md<br/>← .forge/map.json<br/>← .forge/conventions.json"]
        SR3["plan / critique / execute<br/>← .forge/plans/*.md"]
        SR4["systematic-debugging<br/>← .forge/dead-ends/*"]
    end

    subgraph SKILLS_WRITE["Скиллы ПИШУТ"]
        SW1["plan<br/>→ .forge/plans/YYYY-MM-DD-name.md"]
        SW2["session-awareness<br/>→ .forge/index.md (session section)<br/>→ .forge/dead-ends/topic.md<br/>→ .forge/journal.md"]
        SW3["/forge:sync<br/>→ .forge/index.md<br/>→ .forge/status.md<br/>→ .forge/map.json"]
        SW4["/forge:init<br/>→ ВСЮ структуру .forge/"]
    end

    subgraph DOCS[".forge/ (персистентная память)"]
        D1["index.md — точка входа ~400 токенов"]
        D2["dead-ends/ — провальные подходы"]
        D3["plans/ — планы реализации"]
        D4["decisions.md — архитектурные решения"]
        D5["journal.md — история сессий"]
        D6["library/ — спеки по директориям"]
        D7["map.json — структура проекта"]
        D8["conventions.json — правила именования"]
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
│  SessionStart hook:                                      │
│    using-forge SKILL.md        ~800 токенов (один раз)   │
│                                                          │
│  Каждый промт (context-inject):                          │
│    .forge/index.md              ~400 токенов              │
│    dead-ends список             ~50 токенов              │
│    git log + branch             ~30 токенов              │
│    ─────────────────────────────────────                  │
│    ИТОГО за промт:             ~480 токенов              │
│                                                          │
│  По запросу (Skill tool):                                │
│    new-task SKILL.md           ~500 токенов              │
│    plan / critique / execute   ~400 токенов каждый       │
│    другие скиллы               ~300-600 токенов          │
│                                                          │
│  Результат: 480 вместо 40,000+ на каждый промт           │
│  Экономия: ~98.8% токенов                                │
└─────────────────────────────────────────────────────────┘
```

---

## 7. Timeline — Typical Development Session

```
Время   Событие                              Контекст Claude
──────  ─────────────────────────────────     ─────────────────────────
t=0     Claude Code запускается               пусто
        ↓ SessionStart hook                   + using-forge (~800 tok)

t=1     User: "хочу добавить JWT авторизацию"
        ↓ UserPromptSubmit hook               + .forge/index.md + dead-ends + git
        ↓ Claude → /forge:new-task            Phase 1: Understanding
        ↓ Сократический диалог                ...уточняет требования...

t=4     User подтверждает понимание
        ↓ Claude → /forge:plan                Phase 2: Planning
        ↓ Декомпозиция; рекурсия на блокер    план в .forge/plans/

t=7     План готов
        ↓ Claude → /forge:critique            Phase 3: Critique
        ↓ 4 персоны параллельно               замечания + Execution Strategy
        ↓ User одобряет стратегию

t=9     User: "выполняй"
        ↓ Claude → /forge:execute             Phase 4: Implementation
        ↓ Задача 1: TDD cycle                 subagent с чистым контекстом
        ↓ Review → OK
        ↓ Чекпоинт → стоп → user "go"
        ↓ Задача 2: TDD cycle                 новый subagent
        ↓ Review → OK
        ...

t=15    Все задачи выполнены
        ↓ Claude → /forge:sync                обновляет .forge/index.md
        ↓ session-awareness                   пишет в journal.md
        ↓ Claude: "готово, запусти /forge:validate"

t=16    User: /forge:validate
        ↓ Проверяет код vs план vs docs       read-only аудит
        ↓ Claude: "всё соответствует плану"

t=17    User: "мержим"
        ↓ finishing-a-development-branch       тесты → merge/PR
```
