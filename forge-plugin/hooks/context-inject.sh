#!/usr/bin/env bash
# UserPromptSubmit hook — inject L0 context + skill hints into every prompt
# Reads ONLY index.yml (~200 tokens) or index.md (legacy, ~400 tokens)
# Analyzes user prompt keywords to recommend relevant skills

set -euo pipefail

# Check for FORGE docs (new format first, then legacy)
if [ -f ".forge/index.yml" ]; then
    index_content=$(cat .forge/index.yml 2>/dev/null || echo "")
elif [ -f ".forge/index.md" ]; then
    index_content=$(cat .forge/index.md 2>/dev/null || echo "")
else
    exit 0
fi

# Current branch
branch=$(git branch --show-current 2>/dev/null || echo "unknown")

# Last 3 commits
git_log=$(git log --oneline -3 2>/dev/null || echo "no git")

# ============ SKILL HINTS (R1+R6) ============
# Read user prompt from stdin (hook receives JSON with "input" field)
hook_input=$(cat)
user_prompt=$(printf '%s' "$hook_input" | sed -n 's/.*"input"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | tr '[:upper:]' '[:lower:]')

skill_hint=""
role_hint=""

# R1: Keyword-based skill matching (first match wins)
# Each match sets skill_hint + role_hint (compact role priming before full skill loads)
if printf '%s' "$user_prompt" | grep -qiE 'почему|разбер|пойм|что происходит|в чём проблем|в чем проблем|что не так|странно|непонятно|weird|investigate|diagnose|что случил|откуда берётся|откуда берется|из-за чего|с чем связан|в чём дело|в чем дело|что пошло не так|не пойму|не понимаю|разобраться|копни|покопай|выясни|расследуй|чё за фигня|чё за хрень|что за ерунда|хз почему|фиг знает|нифига не понятно'; then
    skill_hint="forge:problem-investigation"
    role_hint="Ты опытный следователь по коду. Не угадывай — собирай улики, строй гипотезы, проверяй каждую. Сначала пойми, потом чини."
elif printf '%s' "$user_prompt" | grep -qiE 'fix|почини|исправ|debug|отладк|bug|баг|ошибк|сломал|не работа|broken|fail|crash|падает|валится|вылетает|крашит|глючит|зависает|фикс|поправ|пофикс|чини|ломается|выбрасывает|exception|error|трейс|stacktrace|полетел|отвалил|коряв|кривой|кривая|кривое|дохнет|сдохл|не пашет|не фурыч|не запускается|вылезает|выскакивает'; then
    skill_hint="forge:systematic-debugging"
    role_hint="Ты senior-инженер, которого зовут в 3 ночи когда всё упало. Никаких угадываний — трейс, замер, доказательство. Сначала root cause, потом фикс."
elif printf '%s' "$user_prompt" | grep -qiE 'design|ui |ux |color|font|palette|палитр|дизайн|стиль|шрифт|макет|layout|верстк|компонент|кнопк|форм|интерфейс|отступ|выравнив|анимац|тема|темн|светл|адаптив|респонсив|красив|уродлив|страшн|некрасив|пикселе|цвет|иконк|модалк|попап|тултип|дропдаун|сайдбар|хедер|футер'; then
    skill_hint="forge:ui-ux-design"
    role_hint="Ты UI/UX дизайнер с чувством вкуса. Думай про визуальную иерархию, контраст, пространство. Никакого generic AI-стиля — делай красиво и осмысленно."
elif printf '%s' "$user_prompt" | grep -qiE 'api|апи|endpoint|route|маршрут|эндпоинт|rest|swagger|ручк|хэндлер|handler|контракт|запрос.*ответ|request.*response|роут|апишк|метод.*запрос'; then
    skill_hint="forge:api-design"
    role_hint="Ты API-архитектор. Думай про контракты, версионирование, обратную совместимость. Чёткие имена, предсказуемые ответы, правильные HTTP-коды."
elif printf '%s' "$user_prompt" | grep -qiE 'миграци|schema|таблиц|колонк|столбец|alter|database|бд |база данных|базу данных|базе данных|индекс.*табл|foreign.?key|внешний ключ|констрейнт|constraint|модель.*данн|pgmigrat|knex|prisma|sequelize|схема.*бд|схема.*баз|постгрес|postgres|mysql|sqlite|монго|mongo'; then
    skill_hint="forge:database-migrations"
    role_hint="Ты DBA с параноидальным отношением к данным. Каждая миграция обратима. Думай про блокировки, downtime, откат. Данные важнее кода."
elif printf '%s' "$user_prompt" | grep -qiE 'deploy|docker|ci.?cd|pipeline|деплой|контейнер|rollback|откат|прод|продакшн|production|релиз|release|кубер|k8s|helm|nginx|сервер.*наст|выкат|раскат|сборк|билд.*прод|закинь на серв|залей на серв|выложи на серв|запусти на серв|подними серв|задеплой|в прод|на прод|докер'; then
    skill_hint="forge:deployment"
    role_hint="Ты DevOps-инженер. Всё должно быть воспроизводимо, откатываемо, наблюдаемо. Если нет health check — это не деплой."
elif printf '%s' "$user_prompt" | grep -qiE 'безопасност|секьюрити|security|xss|sql.?inject|auth|авториз|аутентифик|токен|уязвим|vulnerability|пароль|password|шифрован|encrypt|csrf|cors|sanitiz|валидац.*вход|escape|доступ.*прав|привилег|дыр.*безопасн|утечк|leak'; then
    skill_hint="forge:security-review"
    role_hint="Ты security-инженер с менталитетом атакующего. Думай как злоумышленник — что можно сломать, обойти, украсть. Валидируй всё на границах системы."
elif printf '%s' "$user_prompt" | grep -qiE 'test|tdd|тест|покры|юнит|unit|mock|мок|assert|проверк.*код|спек|spec'; then
    skill_hint="forge:test-driven-development"
    role_hint="Ты TDD-практик. Сначала падающий тест, потом минимальный код чтобы он прошёл. Тесты — это спецификация, а не формальность."
elif printf '%s' "$user_prompt" | grep -qiE 'plan|план|архитектур|спроектир|decompos|декомпоз|разбить на|этапы|дорожн|roadmap|стратеги|подход к реализ'; then
    skill_hint="forge:writing-plans"
    role_hint="Ты системный архитектор. Разбивай на этапы, находи зависимости, определяй риски. План должен быть исполняемым, а не красивым."
elif printf '%s' "$user_prompt" | grep -qiE 'refactor|cleanup|dead.?code|почист|рефактор|порядок|качеств|мусор|неиспользуем|дублиров|упрост|вычист|причес|навести порядок|убрать лишн|удалить.*ненужн|разгрести|хлам|говнокод|лапша|спагетти|нечитаем'; then
    skill_hint="forge:code-cleanup"
    role_hint="Ты чистильщик кода. Удаляй мёртвое, упрощай сложное, именуй понятно. Каждое изменение должно быть безопасным — не сломай поведение."
elif printf '%s' "$user_prompt" | grep -qiE 'review|ревью|проверь|посмотри код|оцени код|глянь код|код.*нормальн'; then
    skill_hint="forge:requesting-code-review"
    role_hint="Ты строгий но справедливый ревьюер. Ищи баги, нарушения контрактов, пропущенные edge cases. Не придирайся к стилю — фокус на корректность."
elif printf '%s' "$user_prompt" | grep -qiE 'stuck|застрял|не знаю|что делать|с чего начать|потерял|контекст|тупик|заблокирован|не могу продвинуть|куда двигать|куда дальше|что дальше|потерялся|запутал|голова кругом|не въезжаю|хз что делать|без понятия'; then
    skill_hint="forge:project-unblocker"
    role_hint="Ты наставник который помогает выбраться из тупика. Не спрашивай — предлагай конкретные следующие шаги. Покажи путь вперёд."
elif printf '%s' "$user_prompt" | grep -qiE 'brainstorm|мозговой|придумай|обсудим|давай подумаем|новая фича|новый функционал|идея|предлож|как бы ты сделал|как лучше|варианты|обмозгу|накидай|порассужда|хочу сделать|хочу добавить|а что если|было бы круто|прикинь'; then
    skill_hint="forge:brainstorming"
    role_hint="Ты продуктовый дизайнер-визионер. Задавай вопросы по одному, раскрывай намерение за запросом. Не кодь — сначала пойми что и зачем."
elif printf '%s' "$user_prompt" | grep -qiE 'merge|pr |pull.?request|finish|branch|ветк.*готов|мерж|влить|смержить|закрыть ветк|готов к мерж|пулл реквест'; then
    skill_hint="forge:finishing-a-development-branch"
    role_hint="Ты release-инженер. Проверь что всё протестировано, задокументировано, конфликтов нет. Чистый мерж — твоя ответственность."
elif printf '%s' "$user_prompt" | grep -qiE 'sync|синх|обнови.*док|документац|обнови forge|forge sync'; then
    skill_hint="forge:sync"
    role_hint="Ты технический писатель. Документация должна отражать реальное состояние кода — не больше, не меньше."
elif printf '%s' "$user_prompt" | grep -qiE 'как работает|как устроен|объясни.*как|покажи как|визуализируй|explain how|what happens|расскажи про|что делает|как связан|как взаимодейств|поток.*данн|flow|схема работ'; then
    skill_hint="forge:explaining"
    role_hint="Ты терпеливый наставник. Объясняй от простого к сложному, используй аналогии. Покажи как части связаны между собой."
elif printf '%s' "$user_prompt" | grep -qiE 'карта проекта|обзор проекта|product.?map|из чего состоит|полная картина|навигатор|структура проект|что есть в проект|покажи проект'; then
    skill_hint="forge:product-mapping"
    role_hint="Ты системный аналитик. Покажи полную картину — компоненты, связи, зависимости. Карта должна помогать ориентироваться."
elif printf '%s' "$user_prompt" | grep -qiE 'инсайты|паттерны.*сесси|история.*диалог|что я чаще|session.?insights|анализ.*сесси|что мы обсуждали'; then
    skill_hint="forge:session-insights"
    role_hint="Ты аналитик рабочих процессов. Найди закономерности, повторяющиеся проблемы, неэффективности."
elif printf '%s' "$user_prompt" | grep -qiE 'готово|done|завершил|закончил|финиш|всё сделал|все сделал|проверь результат|убедись что работа|работает ли|всё ли ок|все ли ок|можно мержить'; then
    skill_hint="forge:verification-before-completion"
    role_hint="Ты QA-инженер. Не верь на слово — запусти, проверь, убедись. Утверждения без доказательств = ложь."
elif printf '%s' "$user_prompt" | grep -qiE 'создать скилл|новый скилл|написать скилл|редактировать скилл|изменить скилл|skill.*creat|write.*skill|edit.*skill'; then
    skill_hint="forge:writing-skills"
    role_hint="Ты мета-инженер — создаёшь инструменты для разработки. Скилл должен быть чётким, тестируемым, с понятным триггером."
fi

# R6: File-context hints (only if no keyword match)
if [ -z "$skill_hint" ]; then
    changed_files=$(git diff --name-only HEAD 2>/dev/null; git diff --name-only --cached 2>/dev/null) || true
    if printf '%s' "$changed_files" | grep -qiE '\.(css|scss|less|styled|vue|svelte)$'; then
        skill_hint="forge:ui-ux-design"
        role_hint="Ты UI/UX дизайнер с чувством вкуса. Думай про визуальную иерархию, контраст, пространство."
    elif printf '%s' "$changed_files" | grep -qiE '(test|spec|__test__)'; then
        skill_hint="forge:test-driven-development"
        role_hint="Ты TDD-практик. Сначала падающий тест, потом минимальный код."
    fi
fi

# ============ GRAPH HINT ============
graph_hint=""
if [ -f ".forge/graph.json" ]; then
    node_count=$(python3 -c "import json; d=json.load(open('.forge/graph.json')); print(len(d.get('nodes',d.get('elements',{}).get('nodes',[]))))" 2>/dev/null || echo "?")
    graph_hint="--- Graph: .forge/graph.json (${node_count} nodes). Before grep/find, try: graphify query/path/explain --graph .forge/graph.json"
fi

# ============ BUILD CONTEXT ============
# Escape for JSON
escape_for_json() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

context="FORGE L0 CONTEXT (auto-injected):\n\n${index_content}\n\n--- Branch: ${branch}\n--- Recent: ${git_log}"

# Add graph hint if available
if [ -n "$graph_hint" ]; then
    context="${context}\n${graph_hint}"
fi

# Add skill + role hints if found
if [ -n "$skill_hint" ]; then
    context="${context}\n\nSKILL HINT: Consider using ${skill_hint} for this task."
    if [ -n "$role_hint" ]; then
        context="${context}\nROLE: ${role_hint}"
    fi
else
    context="${context}\n\nROLE: Ты опытный senior-разработчик и напарник. Отвечай конкретно, по делу, с примерами кода. Не лей воду — сразу к сути."
fi

# ============ COMMUNICATION STYLE ============
context="${context}\n\nSTYLE: Сжимай ответы. Конкретные правила:\n- Первое предложение — что ты делаешь или предлагаешь. Без преамбул и лести.\n- Максимум 1 уровень списка. Никаких вложенных буллетов, таблиц с вариантами A/B/C/D, нумерованных шагов 1-7.\n- Если есть выбор — предложи ОДИН путь и коротко скажи почему. Не вываливай 3 варианта чтобы пользователь решал за тебя.\n- Один вопрос за раз. Не два, не 'и ещё'. Если нужно несколько — задай первый, остальные после ответа.\n- Технические термины (файл, функция, API, миграция) оставляй — они не пугают. Но не нагромождай по 5 в предложении.\n- Длинный ответ = плохой ответ. Если получилось больше 15 строк — выкинь половину. Структура не заменяет ясность.\n- Не пиши финальных 'если согласен — стартуем', 'дай отмашку', 'жду ответа'. Просто жди.\n- Файл, функция, строка — конкретно, не абстрактно. Мат допустим. Без воды."

context="${context}\n\nROUTING: Match catalog[].tags with current task to decide which L1 files to load. Do NOT load all files — only what matches.\n\nDOC DISCIPLINE: If you just made a technical decision — record in .forge/decisions.yml. If an approach failed — record in .forge/dead-ends.yml. If you learned something non-obvious — record in .forge/learnings.yml. Do it NOW, not later."

escaped=$(escape_for_json "$context")

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "${escaped}"
  }
}
EOF

exit 0
