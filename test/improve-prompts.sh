#!/usr/bin/env bash
# improve-prompts.sh — Улучшает промпты через PromptCode INoT методологию
#
# Использует виртуальный отряд экспертов (Developer, QA, SecOps, Architect,
# Wisdom Entity) для итеративного улучшения промптов.
#
# Режимы:
#   1. Текстовый промпт:
#      ./improve-prompts.sh "Ты код ревьюер. Проверяй код."
#      ./improve-prompts.sh --file prompt.txt
#      → выводит улучшенный промпт в stdout
#
#   2. agents.json:
#      ./improve-prompts.sh --agents agents.json
#      → перезаписывает промпты в agents.json
#
#      ./improve-prompts.sh --agents agents.json --output improved.json
#      → сохраняет в improved.json, оригинал не трогает
#
# Параметры:
#   --model MODEL     Модель для улучшения (default: sonnet)
#   --budget AMOUNT   Макс бюджет на один промпт (default: 0.15)
#   --dry-run         Показать что будет сделано, не выполнять
#   --verbose         Показать диалог экспертов
#   --lang LANG       Язык промпта: ru|en (default: ru)
#   --max-repair N    Макс попыток починки JSON (default: 3)
#   --inot            Встроить INoT (Интроспекцию Мысли) в выходные промпты

set -euo pipefail

MODEL="sonnet"
BUDGET="0.15"
DRY_RUN=false
VERBOSE=false
LANG="ru"
MODE=""          # text | file | agents
INPUT=""
OUTPUT=""
AGENTS_FILE=""
MAX_REPAIR_ATTEMPTS=3
INOT=false

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'; DIM=$'\033[2m'; NC=$'\033[0m'

usage() {
    cat <<'EOF'
Usage:
  improve-prompts.sh "prompt text"              Улучшить текстовый промпт
  improve-prompts.sh --file prompt.txt          Улучшить промпт из файла
  improve-prompts.sh --agents agents.json       Улучшить все промпты в agents.json
  improve-prompts.sh --agents a.json -o b.json  Сохранить результат в другой файл

Options:
  --model MODEL     Модель Claude (default: sonnet)
  --budget AMOUNT   Макс USD на один промпт (default: 0.15)
  --output, -o FILE Файл для результата (для --agents; без него — перезапись)
  --dry-run         Показать план без выполнения
  --verbose         Показать полный диалог экспертов
  --lang ru|en      Язык промптов (default: ru)
  --max-repair N    Макс попыток починки JSON (default: 3)
  --inot            Встроить INoT (Интроспекцию Мысли) в выходные промпты
  -h, --help        Справка
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --agents)     MODE="agents"; AGENTS_FILE="$2"; shift 2 ;;
            --file)       MODE="file"; INPUT="$2"; shift 2 ;;
            --output|-o)  OUTPUT="$2"; shift 2 ;;
            --model)      MODEL="$2"; shift 2 ;;
            --budget)     BUDGET="$2"; shift 2 ;;
            --dry-run)    DRY_RUN=true; shift ;;
            --verbose)    VERBOSE=true; shift ;;
            --lang)       LANG="$2"; shift 2 ;;
            --max-repair) MAX_REPAIR_ATTEMPTS="$2"; shift 2 ;;
            --inot)       INOT=true; shift ;;
            -h|--help)    usage; exit 0 ;;
            -*)           echo "Unknown option: $1"; usage; exit 1 ;;
            *)
                # Positional argument = inline prompt text
                MODE="text"
                INPUT="$1"
                shift
                ;;
        esac
    done

    if [[ -z "$MODE" ]]; then
        echo "${RED}Error: specify a prompt text, --file, or --agents${NC}"
        usage
        exit 1
    fi
}

# ── INoT-блок: инструкция встроить интроспекцию мысли в выходной промпт ──
_build_inot_block() {
    cat <<'INOTBLOCK'

    КРИТИЧЕСКИ ВАЖНОЕ ДОПОЛНИТЕЛЬНОЕ ТРЕБОВАНИЕ:
    Результирующий промпт ДОЛЖЕН содержать встроенную Интроспекцию Мысли (INoT).
    Это значит, что сам выходной промпт должен заставлять LLM симулировать
    внутренний диалог между виртуальными экспертами перед выдачей результата.

    Структура выходного промпта ОБЯЗАТЕЛЬНО включает:

    a) <Role> — описание роли с указанием "способен к Интроспекции Мысли (INoT)"
    b) <PromptCodeDefinition> — объяснение что PromptCode это гибрид Python
       и естественного языка, и что агент ДОЛЖЕН симулировать диалог,
       а не просто выдать результат
    c) <Team_Definitions> — 3-5 виртуальных агентов, АДАПТИРОВАННЫХ под
       конкретную роль. НЕ копируй Developer/QA/SecOps — создай экспертов,
       релевантных задаче агента. Например:
       - Для код-ревьюера: Readability_Expert, Bug_Hunter, Performance_Analyst, Security_Auditor
       - Для DevOps: Reliability_Engineer, Cost_Optimizer, Security_Hardener, Incident_Responder
       - Для архитектора: Scalability_Expert, Simplicity_Advocate, Domain_Modeler, Tech_Debt_Hunter
       - Для тестировщика: Edge_Case_Finder, Integration_Checker, Regression_Hunter, UX_Validator
       Каждый агент должен иметь:
       - Уникальную перспективу (один ищет баги, другой — стиль, третий — безопасность)
       - Характерную "склонность" (как Developer "забывает граничные случаи")
       - Конкретный фокус проверки
    d) Опционально <Wisdom_Entity> — "Абсолютный Перфекционист", который
       ищет предвзятость, двусмысленность, неоптимальность. Блокирует
       результат при любом сомнении. Включать для критичных задач.
    e) <Reasoning_Logic> — алгоритм на Python-подобном псевдокоде:
       - Фаза 1: Первоначальное решение от основного агента
       - Фаза 2: Цикл проверки отрядом (while not approved, max_rounds)
         - Каждый агент ревьюит, даёт feedback
         - При наличии замечаний — рефакторинг и новый раунд
       - Фаза 3 (опц.): Врата Мудрости — финальная проверка Wisdom_Entity
         с analyze_bias() и find_any_imperfection(strict_mode=True)
       - Фаза 4: Финальный вывод
    f) <OutputFormat> — что именно выдать и в каком формате

    ВАЖНО по адаптации INoT:
    - Состав отряда и их фокусы ДОЛЖНЫ отражать специфику задачи агента
    - max_rounds: 2-3 для простых задач, 5-7 для критичных
    - Wisdom_Entity добавлять только если задача критична (безопасность,
      продакшен код, инфраструктура)
    - Диалог между агентами должен быть СОДЕРЖАТЕЛЬНЫМ (конкретные
      замечания), а не формальным ("LGTM")
    - Reasoning_Logic должен быть реально исполнимым — LLM будет
      следовать ему как алгоритму
INOTBLOCK
}

# ── Meta-prompt: инструкция для Claude как улучшать промпты ──────────────
# Это сам PromptCode, который улучшает другие промпты
build_meta_prompt() {
    local original_prompt="$1"
    local context="${2:-}"  # optional: agent name, role description

    local inot_block=""
    if [[ "$INOT" == "true" ]]; then
        inot_block=$(_build_inot_block)
    fi

    cat <<METAPROMPT
<Role>
    RoleName: Prompt Engineer (INoT Mode)
    Ты — эксперт по созданию промптов для LLM-агентов.
    Твоя задача — взять исходный промпт и превратить его в
    структурированный, конкретный, эффективный промпт.
    Ты управляешь Виртуальным Отрядом для итеративного улучшения.
</Role>

<Team_Definitions>
    <Agent Name="Clarity_Expert">
        Фокус: Устранение двусмысленности. Каждая инструкция должна
        иметь ровно одну интерпретацию. Нет расплывчатых слов вроде
        "хороший", "правильный", "при необходимости".
    </Agent>

    <Agent Name="Structure_Expert">
        Фокус: Организация промпта. Роль, контекст, задачи, ограничения,
        формат вывода — всё должно быть в отдельных секциях.
        Использует XML-теги для структуры.
    </Agent>

    <Agent Name="Efficiency_Expert">
        Фокус: Минимум токенов при максимуме смысла. Удаляет повторения,
        шаблонные фразы, лишние вежливости. Каждое слово должно нести
        информацию. Оценивает: можно ли этот промпт выполнить на haiku
        вместо opus?
    </Agent>

    <Agent Name="Domain_Expert">
        Фокус: Специфика предметной области. Добавляет конкретику:
        имена файлов, пути, форматы, примеры входа/выхода.
        Заменяет общие фразы на конкретные инструкции.
    </Agent>

    <Agent Name="Safety_Expert">
        Фокус: Ограничения и защита. Что агент НЕ должен делать?
        Какие файлы не трогать? Какие действия запрещены?
        Добавляет guardrails и fallback-поведение.
    </Agent>
</Team_Definitions>

<Context>
${context}
</Context>

<Task>
    Улучши этот промпт. Исходный промпт:

    ---
    ${original_prompt}
    ---

    Требования к результату:
    1. Структура: используй XML-теги (<Role>, <Context>, <Task>, <Constraints>, <OutputFormat>)
    2. Конкретика: замени общие фразы на конкретные инструкции
    3. Ограничения: явно укажи что НЕ делать
    4. Формат вывода: опиши ожидаемый формат ответа
    5. Примеры: добавь 1-2 примера входа/выхода если уместно
    6. Эффективность: минимум слов, максимум смысла
    7. Язык: ${LANG}
${inot_block}
</Task>

<Reasoning_Logic>
    experts = [Clarity_Expert(), Structure_Expert(), Efficiency_Expert(), Domain_Expert(), Safety_Expert()]

    # Фаза 1: Анализ исходного промпта
    print("--- Анализ исходного промпта ---")
    issues = []
    for expert in experts:
        problems = expert.analyze(original_prompt)
        if problems:
            print(f"[{expert.name}]: {problems}")
            issues.extend(problems)

    # Фаза 2: Генерация улучшенного промпта
    print("--- Генерация улучшенного промпта ---")
    improved = apply_all_improvements(original_prompt, issues)

    # Фаза 3: Финальная проверка
    print("--- Финальная проверка ---")
    for expert in experts:
        verdict = expert.verify(improved)
        print(f"[{expert.name}]: {verdict}")

    return improved
</Reasoning_Logic>

<OutputFormat>
    Выведи ТОЛЬКО улучшенный промпт. Без пояснений, без "вот улучшенный промпт:",
    без маркеров начала/конца. Только чистый текст промпта.
    Если используешь XML-теги в промпте — это часть промпта, не обёртка.
    Промпт должен быть готов к копированию и вставке.
</OutputFormat>
METAPROMPT
}

# ── Улучшить один промпт через Claude ───────────────────────────────────
improve_single_prompt() {
    local original="$1"
    local context="${2:-}"

    local meta_prompt
    meta_prompt=$(build_meta_prompt "$original" "$context")

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "${DIM}[dry-run] Would improve prompt (${#original} chars) with model=$MODEL budget=$BUDGET${NC}" >&2
        echo "$original"
        return 0
    fi

    local result
    result=$(unset CLAUDECODE && timeout --signal=KILL 120 \
        claude -p \
        --model "$MODEL" \
        --max-budget-usd "$BUDGET" \
        --dangerously-skip-permissions \
        --no-session-persistence \
        <<< "$meta_prompt" \
        2>&1) || true

    if echo "$result" | grep -qi "^Error:"; then
        echo "${RED}Error improving prompt: $(echo "$result" | head -3)${NC}" >&2
        echo "$original"  # return original on error
        return 1
    fi

    echo "$result"
}

# ── Режим: текстовый промпт ─────────────────────────────────────────────
mode_text() {
    local prompt="$INPUT"
    echo "${CYAN}Improving prompt (${#prompt} chars)...${NC}" >&2
    improve_single_prompt "$prompt"
}

# ── Режим: промпт из файла ──────────────────────────────────────────────
mode_file() {
    if [[ ! -f "$INPUT" ]]; then
        echo "${RED}File not found: $INPUT${NC}" >&2
        exit 1
    fi
    local prompt
    prompt=$(cat "$INPUT")
    echo "${CYAN}Improving prompt from $INPUT (${#prompt} chars)...${NC}" >&2

    local result
    result=$(improve_single_prompt "$prompt")

    if [[ -n "$OUTPUT" ]]; then
        echo "$result" > "$OUTPUT"
        echo "${GREEN}Saved to $OUTPUT${NC}" >&2
    else
        echo "$result"
    fi
}

# ── Режим: agents.json ──────────────────────────────────────────────────
mode_agents() {
    if [[ ! -f "$AGENTS_FILE" ]]; then
        echo "${RED}File not found: $AGENTS_FILE${NC}" >&2
        exit 1
    fi

    local out_file="${OUTPUT:-$AGENTS_FILE}"
    local tmp_file
    tmp_file=$(mktemp /tmp/agents-improved-XXXXXX.json)

    # Read agent names
    local agent_names
    agent_names=$(python3 -c "
import json, sys
with open('$AGENTS_FILE') as f:
    data = json.load(f)
for name in data:
    print(name)
")

    local total
    total=$(echo "$agent_names" | wc -l)
    local current=0

    echo "${CYAN}Improving $total agents in $AGENTS_FILE${NC}" >&2
    echo "${DIM}Model: $MODEL, budget per agent: \$$BUDGET${NC}" >&2
    if [[ "$out_file" == "$AGENTS_FILE" ]]; then
        echo "${YELLOW}Will overwrite $AGENTS_FILE${NC}" >&2
    else
        echo "${DIM}Output: $out_file${NC}" >&2
    fi
    echo "" >&2

    # Process each agent
    python3 -c "
import json
with open('$AGENTS_FILE') as f:
    data = json.load(f)
# Write original as starting point for the update script
with open('$tmp_file', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
"

    while IFS= read -r agent_name; do
        [[ -z "$agent_name" ]] && continue
        current=$((current + 1))

        # Extract current prompt and description
        local agent_info
        agent_info=$(python3 -c "
import json
with open('$AGENTS_FILE') as f:
    data = json.load(f)
agent = data.get('$agent_name', {})
print(agent.get('prompt', ''))
print('---SEPARATOR---')
print(agent.get('description', ''))
")
        local current_prompt
        current_prompt=$(echo "$agent_info" | sed '/^---SEPARATOR---$/,$d')
        local description
        description=$(echo "$agent_info" | sed -n '/^---SEPARATOR---$/,${/^---SEPARATOR---$/d;p;}')

        echo "${CYAN}[$current/$total] $agent_name${NC} ${DIM}(${#current_prompt} chars)${NC}" >&2

        if [[ ${#current_prompt} -lt 10 ]]; then
            echo "${DIM}  Skipped (prompt too short)${NC}" >&2
            continue
        fi

        local context="Agent name: $agent_name
Agent description: $description
This is a Claude Code subagent prompt in .claude/agents.json.
The agent is invoked automatically by Claude Code when its description matches the task.
Available agent fields: description, prompt, model (sonnet|opus|haiku), tools, maxTurns, permissionMode, isolation.
The improved prompt should be optimized for the agent's specific role."

        local improved
        improved=$(improve_single_prompt "$current_prompt" "$context")

        if [[ $? -eq 0 ]] && [[ -n "$improved" ]]; then
            # Update the prompt in the JSON
            python3 -c "
import json, sys

improved_text = sys.stdin.read()

with open('$tmp_file') as f:
    data = json.load(f)

if '$agent_name' in data:
    data['$agent_name']['prompt'] = improved_text.strip()

with open('$tmp_file', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
" <<< "$improved"
            echo "${GREEN}  Done${NC}" >&2
        else
            echo "${YELLOW}  Kept original (improvement failed)${NC}" >&2
        fi

    done <<< "$agent_names"

    # ── Validate JSON before saving ──────────────────────────────────────
    echo "" >&2
    echo "${CYAN}Validating result...${NC}" >&2

    # Step 1: python json.loads — strict syntax check
    local valid
    valid=$(python3 -c "
import json, sys
try:
    with open('$tmp_file') as f:
        data = json.load(f)
    # Check structure: every agent must have description and prompt
    errors = []
    for name, agent in data.items():
        if not isinstance(agent, dict):
            errors.append(f'{name}: not a dict')
            continue
        if 'description' not in agent:
            errors.append(f'{name}: missing description')
        if 'prompt' not in agent:
            errors.append(f'{name}: missing prompt')
        if 'model' in agent and agent['model'] not in ('sonnet', 'opus', 'haiku', 'inherit'):
            errors.append(f'{name}: invalid model \"{agent[\"model\"]}\"')
    if errors:
        print('ERRORS:' + '; '.join(errors))
    else:
        print('OK:' + str(len(data)) + ' agents')
except json.JSONDecodeError as e:
    print(f'JSON_ERROR:{e}')
except Exception as e:
    print(f'ERROR:{e}')
" 2>&1)

    if [[ "$valid" == JSON_ERROR:* ]]; then
        echo "${RED}  JSON syntax error: ${valid#JSON_ERROR:}${NC}" >&2

        local repair_attempt=0
        while [[ "$valid" == JSON_ERROR:* ]] && [[ $repair_attempt -lt $MAX_REPAIR_ATTEMPTS ]]; do
            repair_attempt=$((repair_attempt + 1))
            echo "${YELLOW}  Repair attempt $repair_attempt/$MAX_REPAIR_ATTEMPTS via Claude (haiku, \$0.02)...${NC}" >&2

            local fix_result
            fix_result=$(unset CLAUDECODE && timeout --signal=KILL 60 \
                claude -p \
                --model haiku \
                --max-budget-usd 0.02 \
                --dangerously-skip-permissions \
                --no-session-persistence \
                <<< "Fix this broken JSON. Return ONLY valid JSON, nothing else. No markdown, no code fences, no explanation.

$(cat "$tmp_file")" \
                2>&1) || true

            echo "$fix_result" > "$tmp_file"

            valid=$(python3 -c "
import json
try:
    with open('$tmp_file') as f:
        data = json.load(f)
    print('OK:' + str(len(data)) + ' agents')
except json.JSONDecodeError as e:
    print(f'JSON_ERROR:{e}')
except Exception as e:
    print(f'ERROR:{e}')
" 2>&1)
        done

        if [[ "$valid" == JSON_ERROR:* ]]; then
            echo "${RED}  JSON repair failed after $MAX_REPAIR_ATTEMPTS attempts${NC}" >&2
            echo "${RED}  Aborting — original file unchanged. Broken temp file: $tmp_file${NC}" >&2
            return 1
        fi
        echo "${GREEN}  JSON repaired on attempt $repair_attempt${NC}" >&2
    elif [[ "$valid" == ERRORS:* ]]; then
        echo "${YELLOW}  Structure warnings: ${valid#ERRORS:}${NC}" >&2
        echo "${YELLOW}  Saving anyway (prompts may need manual review)${NC}" >&2
    elif [[ "$valid" == OK:* ]]; then
        echo "${GREEN}  Valid JSON: ${valid#OK:}${NC}" >&2
    else
        echo "${RED}  Unexpected validation result: $valid${NC}" >&2
        echo "${RED}  Aborting — original file unchanged. Temp file: $tmp_file${NC}" >&2
        return 1
    fi

    # ── Save ─────────────────────────────────────────────────────────────
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "${DIM}[dry-run] Would save to $out_file${NC}" >&2
        cat "$tmp_file"
        rm -f "$tmp_file"
    else
        # Backup original if overwriting
        if [[ "$out_file" == "$AGENTS_FILE" ]]; then
            cp "$AGENTS_FILE" "${AGENTS_FILE}.bak"
            echo "${DIM}  Backup: ${AGENTS_FILE}.bak${NC}" >&2
        fi

        cp "$tmp_file" "$out_file"
        rm -f "$tmp_file"
        echo "${GREEN}Saved improved agents to $out_file${NC}" >&2

        if [[ "$out_file" == "$AGENTS_FILE" ]]; then
            echo "${DIM}Use 'git diff $AGENTS_FILE' to review changes${NC}" >&2
        fi
    fi
}

# ── Main ─────────────────────────────────────────────────────────────────
main() {
    parse_args "$@"

    case "$MODE" in
        text)   mode_text ;;
        file)   mode_file ;;
        agents) mode_agents ;;
        *)      echo "${RED}Unknown mode${NC}"; exit 1 ;;
    esac
}

main "$@"
