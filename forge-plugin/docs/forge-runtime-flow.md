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

## 3. Skill Invocation Flow

```mermaid
flowchart TB
    A["Claude получает задачу"] --> B{"Нужен brainstorming?<br/>(новая фича/компонент)"}
    B -- Да --> C["/forge:brainstorm"]
    B -- Нет --> D{"Баг или проблема?"}
    D -- Да --> E["/forge:systematic-debugging"]
    D -- Нет --> F{"Реализация по плану?"}
    F -- Да --> G["/forge:execute-plan"]
    F -- Нет --> H{"Код написан, нужна проверка?"}
    H -- Да --> I["/forge:validate"]
    H -- Нет --> J["Другие скиллы по ситуации"]

    subgraph BRAINSTORM_FLOW["Brainstorming → Plan → Execute"]
        C --> C1["Загружает dead-ends + decisions"]
        C1 --> C2["Сократический диалог<br/>уточняет требования"]
        C2 --> C3["HARD GATE: дизайн одобрен?"]
        C3 -- Нет --> C2
        C3 -- Да --> C4["Автоматически → /forge:write-plan"]
        C4 --> C5["План в .forge/plans/<br/>задачи по 2-5 мин"]
        C5 --> C6["/forge:execute-plan<br/>или subagent-driven"]
    end

    subgraph EXECUTION["Execution Loop"]
        C6 --> EX1["Берёт задачу из плана"]
        EX1 --> EX2["TDD: пишет тест → RED"]
        EX2 --> EX3["Пишет код → GREEN"]
        EX3 --> EX4["Рефакторинг"]
        EX4 --> EX5{"Ещё задачи?"}
        EX5 -- Да --> EX1
        EX5 -- Нет --> EX6["/forge:sync — обновляет .forge/"]
    end
```

---

## 4. Subagent-Driven Development — Detail

```mermaid
sequenceDiagram
    participant U as Пользователь
    participant M as Main Claude
    participant S1 as Subagent 1
    participant S2 as Subagent 2
    participant R as Review Agent

    U->>M: /forge:execute-plan
    M->>M: Читает .forge/plans/plan.md
    
    Note over M: Задача 1
    M->>S1: Промт с задачей + контекст
    S1->>S1: TDD: test → code → refactor
    S1-->>M: Результат + diff

    M->>R: Review #1: соответствие спеке
    R-->>M: OK / замечания
    M->>R: Review #2: качество кода
    R-->>M: OK / замечания
    
    Note over M: Задача 2
    M->>S2: Следующая задача (чистый контекст)
    S2->>S2: TDD: test → code → refactor
    S2-->>M: Результат + diff

    M->>R: Review #1 + #2
    R-->>M: OK

    M->>M: /forge:sync — обновляет .forge/
    M-->>U: Отчёт о выполнении
```

---

## 5. Data Flow — What Reads/Writes What

```mermaid
flowchart TB
    subgraph HOOKS["Hooks (автоматические)"]
        H1["session-start.sh<br/>ЧИТАЕТ: using-forge/SKILL.md"]
        H2["context-inject.sh<br/>ЧИТАЕТ: .forge/index.md<br/>.forge/dead-ends/*<br/>git log, git branch"]
    end

    subgraph SKILLS_READ["Скиллы ЧИТАЮТ"]
        SR1["brainstorming<br/>← .forge/dead-ends/*<br/>← .forge/decisions.md<br/>← .forge/library/"]
        SR2["forge-context<br/>← .forge/index.md<br/>← .forge/map.json<br/>← .forge/conventions.json"]
        SR3["executing-plans<br/>← .forge/plans/*.md"]
        SR4["systematic-debugging<br/>← .forge/dead-ends/*"]
    end

    subgraph SKILLS_WRITE["Скиллы ПИШУТ"]
        SW1["brainstorming → writing-plans<br/>→ .forge/plans/YYYY-MM-DD-name.md"]
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
│    brainstorming SKILL.md      ~500 токенов              │
│    TDD SKILL.md                ~400 токенов              │
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
        ↓ Claude: подходит brainstorming      + brainstorming skill
        ↓ Skill читает dead-ends, decisions   + контекст проекта
        ↓ Claude задаёт вопросы               ...уточняет требования...

t=5     User одобряет дизайн
        ↓ Claude → writing-plans skill        + writing-plans skill
        ↓ Пишет план → .forge/plans/           .forge/ обновлён

t=6     User: "выполняй"
        ↓ UserPromptSubmit hook               + обновлённый index.md
        ↓ Claude → executing-plans skill      + executing-plans skill
        ↓ Задача 1: TDD cycle                 subagent с чистым контекстом
        ↓ Review → OK
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
