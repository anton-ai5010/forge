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

# R1: Keyword-based skill matching (first match wins)
if printf '%s' "$user_prompt" | grep -qiE 'почему|разбер|пойм|что происходит|в чём проблем|в чем проблем|что не так|странно|непонятно|weird|investigate|diagnose|что случил|откуда берётся|откуда берется|из-за чего|с чем связан|в чём дело|в чем дело|что пошло не так|не пойму|не понимаю|разобраться|копни|покопай|выясни|расследуй|чё за фигня|чё за хрень|что за ерунда|хз почему|фиг знает|нифига не понятно'; then
    skill_hint="forge:problem-investigation"
elif printf '%s' "$user_prompt" | grep -qiE 'fix|почини|исправ|debug|отладк|bug|баг|ошибк|сломал|не работа|broken|fail|crash|падает|валится|вылетает|крашит|глючит|зависает|фикс|поправ|пофикс|чини|ломается|выбрасывает|exception|error|трейс|stacktrace|полетел|отвалил|коряв|кривой|кривая|кривое|дохнет|сдохл|не пашет|не фурыч|не запускается|вылезает|выскакивает'; then
    skill_hint="forge:systematic-debugging"
elif printf '%s' "$user_prompt" | grep -qiE 'design|ui |ux |color|font|palette|палитр|дизайн|стиль|шрифт|макет|layout|верстк|компонент|кнопк|форм|интерфейс|отступ|выравнив|анимац|тема|темн|светл|адаптив|респонсив|красив|уродлив|страшн|некрасив|пикселе|цвет|иконк|модалк|попап|тултип|дропдаун|сайдбар|хедер|футер'; then
    skill_hint="forge:ui-ux-design"
elif printf '%s' "$user_prompt" | grep -qiE 'api|апи|endpoint|route|маршрут|эндпоинт|rest|swagger|ручк|хэндлер|handler|контракт|запрос.*ответ|request.*response|роут|апишк|метод.*запрос'; then
    skill_hint="forge:api-design"
elif printf '%s' "$user_prompt" | grep -qiE 'миграци|schema|таблиц|колонк|столбец|alter|database|бд |база данных|базу данных|базе данных|индекс.*табл|foreign.?key|внешний ключ|констрейнт|constraint|модель.*данн|pgmigrat|knex|prisma|sequelize|схема.*бд|схема.*баз|постгрес|postgres|mysql|sqlite|монго|mongo'; then
    skill_hint="forge:database-migrations"
elif printf '%s' "$user_prompt" | grep -qiE 'deploy|docker|ci.?cd|pipeline|деплой|контейнер|rollback|откат|прод|продакшн|production|релиз|release|кубер|k8s|helm|nginx|сервер.*наст|выкат|раскат|сборк|билд.*прод|закинь на серв|залей на серв|выложи на серв|запусти на серв|подними серв|задеплой|в прод|на прод|докер'; then
    skill_hint="forge:deployment"
elif printf '%s' "$user_prompt" | grep -qiE 'безопасност|секьюрити|security|xss|sql.?inject|auth|авториз|аутентифик|токен|уязвим|vulnerability|пароль|password|шифрован|encrypt|csrf|cors|sanitiz|валидац.*вход|escape|доступ.*прав|привилег|дыр.*безопасн|утечк|leak'; then
    skill_hint="forge:security-review"
elif printf '%s' "$user_prompt" | grep -qiE 'test|tdd|тест|покры|юнит|unit|mock|мок|assert|проверк.*код|спек|spec'; then
    skill_hint="forge:test-driven-development"
elif printf '%s' "$user_prompt" | grep -qiE 'plan|план|архитектур|спроектир|decompos|декомпоз|разбить на|этапы|дорожн|roadmap|стратеги|подход к реализ'; then
    skill_hint="forge:writing-plans"
elif printf '%s' "$user_prompt" | grep -qiE 'refactor|cleanup|dead.?code|почист|рефактор|порядок|качеств|мусор|неиспользуем|дублиров|упрост|вычист|причес|навести порядок|убрать лишн|удалить.*ненужн|разгрести|хлам|говнокод|лапша|спагетти|нечитаем'; then
    skill_hint="forge:code-cleanup"
elif printf '%s' "$user_prompt" | grep -qiE 'review|ревью|проверь|посмотри код|оцени код|глянь код|код.*нормальн'; then
    skill_hint="forge:requesting-code-review"
elif printf '%s' "$user_prompt" | grep -qiE 'stuck|застрял|не знаю|что делать|с чего начать|потерял|контекст|тупик|заблокирован|не могу продвинуть|куда двигать|куда дальше|что дальше|потерялся|запутал|голова кругом|не въезжаю|хз что делать|без понятия'; then
    skill_hint="forge:project-unblocker"
elif printf '%s' "$user_prompt" | grep -qiE 'brainstorm|мозговой|придумай|обсудим|давай подумаем|новая фича|новый функционал|идея|предлож|как бы ты сделал|как лучше|варианты|обмозгу|накидай|порассужда|хочу сделать|хочу добавить|а что если|было бы круто|прикинь'; then
    skill_hint="forge:brainstorming"
elif printf '%s' "$user_prompt" | grep -qiE 'merge|pr |pull.?request|finish|branch|ветк.*готов|мерж|влить|смержить|закрыть ветк|готов к мерж|пулл реквест'; then
    skill_hint="forge:finishing-a-development-branch"
elif printf '%s' "$user_prompt" | grep -qiE 'sync|синх|обнови.*док|документац|обнови forge|forge sync'; then
    skill_hint="forge:sync"
elif printf '%s' "$user_prompt" | grep -qiE 'как работает|как устроен|объясни.*как|покажи как|визуализируй|explain how|what happens|расскажи про|что делает|как связан|как взаимодейств|поток.*данн|flow|схема работ'; then
    skill_hint="forge:explaining"
elif printf '%s' "$user_prompt" | grep -qiE 'карта проекта|обзор проекта|product.?map|из чего состоит|полная картина|навигатор|структура проект|что есть в проект|покажи проект'; then
    skill_hint="forge:product-mapping"
elif printf '%s' "$user_prompt" | grep -qiE 'готово|done|завершил|закончил|финиш|всё сделал|все сделал|проверь результат|убедись что работа|работает ли|всё ли ок|все ли ок|можно мержить'; then
    skill_hint="forge:verification-before-completion"
elif printf '%s' "$user_prompt" | grep -qiE 'создать скилл|новый скилл|написать скилл|редактировать скилл|изменить скилл|skill.*creat|write.*skill|edit.*skill'; then
    skill_hint="forge:writing-skills"
fi

# R6: File-context hints (only if no keyword match)
if [ -z "$skill_hint" ]; then
    changed_files=$(git diff --name-only HEAD 2>/dev/null; git diff --name-only --cached 2>/dev/null) || true
    if printf '%s' "$changed_files" | grep -qiE '\.(css|scss|less|styled|vue|svelte)$'; then
        skill_hint="forge:ui-ux-design"
    elif printf '%s' "$changed_files" | grep -qiE '(test|spec|__test__)'; then
        skill_hint="forge:test-driven-development"
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

# Add skill hint if found
if [ -n "$skill_hint" ]; then
    context="${context}\n\nSKILL HINT: Consider using ${skill_hint} for this task."
fi

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
