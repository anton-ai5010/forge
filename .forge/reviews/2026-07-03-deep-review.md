# Глубокое ревью плагина — 2026-07-03

62 подтверждённые находки (адверсариальная верификация, 71 агент). Отклонена 1.

## [0] CRITICAL / docs-reality — README: инструкция установки указывает на несуществующий репозиторий
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/README.md:36-37

README говорит: «/plugin marketplace add anton-ai5010/forge-plugin» и «/plugin install forge@forge-plugin». Проверено через gh: репозитория anton-ai5010/forge-plugin НЕ существует («Could not resolve to a Repository»), реальный публичный репо — anton-ai5010/forge (git remote origin = github.com/anton-ai5010/forge.git). Вдобавок имя маркетплейса в корневом .claude-plugin/marketplace.json — «forge-marketplace», а не «forge-plugin». Любой человек, следуя README, не сможет установить плагин — падает на первом же шаге.

**Как исправить:** Заменить на «/plugin marketplace add anton-ai5010/forge» и «/plugin install forge@forge-marketplace» (имя маркетплейса взять из корневого .claude-plugin/marketplace.json). Проверить установку с нуля на чистой машине/профиле.

**Уточнение верификатора:** Предложение верное: «/plugin marketplace add anton-ai5010/forge» + «/plugin install forge@forge-marketplace». Смежно (вне находки): в forge-plugin/.claude-plugin/plugin.json поля homepage/repository указывают на чужой github.com/obra/forge — стоит исправить той же правкой.

## [1] CRITICAL / manifest — Инструкция установки в README указывает на несуществующий репозиторий и несуществующее имя marketplace
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/README.md:36-37

README говорит: "/plugin marketplace add anton-ai5010/forge-plugin" и "/plugin install forge@forge-plugin". Проверено через gh api: репозитория anton-ai5010/forge-plugin НЕ существует (404) — реальный remote это anton-ai5010/forge. Кроме того, marketplace регистрируется под именем из поля name в корневом .claude-plugin/marketplace.json, а там "forge-marketplace", а не "forge-plugin". Любой человек (включая самого Антона на новой машине), который выполнит эти две команды, получит ошибку и не сможет установить плагин. Единственный публичный путь дистрибуции сломан на 100%.

**Как исправить:** Заменить на реальные команды: "/plugin marketplace add anton-ai5010/forge" и "/plugin install forge@forge-marketplace" (либо переименовать marketplace в корневом marketplace.json в "forge-plugin" и тогда чинить только первую строку). После правки прогнать команды на чистой машине/профиле и убедиться, что установка проходит.

## [2] CRITICAL / manifest — plugin.json homepage/repository указывают на чужой и к тому же мёртвый репозиторий obra/forge
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/.claude-plugin/plugin.json:9-10

В манифесте: "homepage": "https://github.com/obra/forge", "repository": "https://github.com/obra/forge". obra — это Jesse Vincent, автор оригинального плагина, откуда forge форкнут; но реальный remote проекта — https://github.com/anton-ai5010/forge.git. Проверка gh api показала, что obra/forge вообще возвращает 404 — ссылка мёртвая. Пользователь, кликнувший homepage из UI плагина, попадёт на страницу "Not Found"; issue и вклад уйдут в никуда; проект выглядит как чужой.

**Как исправить:** Заменить оба поля на "https://github.com/anton-ai5010/forge". Атрибуцию оригинала оставить в README (она там уже есть, строка 81) и в LICENSE.

**Уточнение верификатора:** Находка даже уже, чем проблема на самом деле: чужая идентичность разлита шире двух полей. В том же plugin.json author = "Forge Contributors" / noreply@forge.dev, а в соседнем .claude-plugin/marketplace.json owner и author плагина — "Jesse Vincent" jesse@fsck.com. Если чинить, стоит одновременно поправить и эти поля (иначе плагин по-прежнему выглядит чужим). Мелочь: ссылка на obra/forge в README-атрибуции тоже теперь 404 — можно оставить как исторический факт или пометить, что оригинал удалён.

## [3] CRITICAL / pipeline — Расхождение slug молча ломает всю цепочку github-sync после Phase 1
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/github-sync/sync.sh:152 + /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/execute/SKILL.md:66

create_task пишет маркер Issue от полного имени файла С ДАТОЙ: `slug=$(basename "$task_file" .md)` → `.forge/.github-issue-2026-07-03-<slug>`. А execute — единственное место, где slug явно определён — требует БЕЗ даты: «slug — это имя файла плана... без даты и `.md`» (SKILL.md:66), и передаёт его в `close-step <task-slug>` (строка 129) и `close-task <task-slug>` (строка 200). Lookup `cat ".forge/.github-issue-$task_slug"` (sync.sh:184, 251) не находит файл и по дизайну молча возвращает 0 («no parent, skipping»). В plan шаг 7.5 `<task-slug>` вообще не определён. Итог: sub-issues не создаются, шаги не закрываются, задача не закрывается, journal не пишется — и никто этого не видит, потому что «тихий no-op» неотличим от «sync выключен». Антон принимает решения по устаревшей карте — ровно тот сценарий, который SKILL.md github-sync называет главной ставкой.

**Как исправить:** Нормализовать slug в одном месте — в sync.sh: в create_task и во всех lookup'ах срезать датный префикс `slug=$(basename ... .md | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}-//')`. И в github-sync/SKILL.md явно определить: «<task-slug> — всегда без даты», чтобы plan/critique/execute передавали одно и то же. Плюс тест: create-task → close-task на файле с датой должен находить маркер.

**Уточнение верификатора:** Три уточнения. (1) Severity чуть завышена в формулировке «ломает ВСЮ цепочку после Phase 1»: в plan `<task-slug>` не определён вовсе, и Claude в фазе plan не видит execute:66 — исторически он передавал датный slug и add-steps работал (substeps-файл существует). Гарантированно-вероятный слом сконцентрирован в execute (close-step/close-task/reassign-task), где бездатное определение лежит явно; это противоречие инструкций с вероятностным исходом, а не детерминированный баг. (2) «Тихий no-op неотличим от sync выключен» буквально верно только для close-task (sync.sh:252 — return 0 без сообщения); add-steps/add-critique/close-step печатают в stderr «sync: no parent issue for X, skipping» — это видно в выводе Bash-тула, но execute:132 прямо велит Claude считать это нормой («Молча no-op если sync выключен или sub-issues не создавались»), так что эффект для Антона тот же. (3) Предложенный фикс со срезанием даты в create_task осиротит уже существующие датные маркеры (в этом репо такой есть); лучше нормализовать одной функцией и на записи, и на чтении (или на чтении принимать обе формы), а главное — явно определить `<task-slug>` в github-sync/SKILL.md, чтобы все фазы передавали одно и то же.

## [4] MAJOR / commands — /forge:start: !`...` bash-препроцессинг без allowed-tools — контекст не загрузится как задумано
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/commands/start.md:9-45

Команда целиком построена на 10 строках inline-исполнения bash: «!`cat .forge/index.yml 2>/dev/null || ...`», «!`git log --oneline -10 ...`» и т.д. (строки 9, 15, 19, 23, 27, 31, 35-37, 41, 45). Но во frontmatter только `description` — поля `allowed-tools` нет ни в start.md, ни в одной из 25 команд (grep -l 'allowed-tools' *.md → NONE). Документация Claude Code по slash-командам требует для bash-выполнения через `!` префикс явный `allowed-tools: Bash(...)` во frontmatter (пример из docs: allowed-tools: Bash(git add *), Bash(git status *)). Без него препроцессинг не выполняется автоматически / упирается в permission-промпты — и главная ежедневная команда загрузки контекста тихо деградирует до литерального текста, который Клоду приходится исполнять вручную.

**Как исправить:** Добавить в frontmatter start.md: `allowed-tools: Bash(cat:*), Bash(ls:*), Bash(head:*), Bash(git log:*), Bash(git branch:*), Bash(git diff:*), Bash(gh issue view:*), Bash(find:*), Bash(bash:*)`. Затем проверить в живой сессии, что все `!`-блоки реально исполнились и вывод попал в контекст (а не остался текстом).

**Уточнение верификатора:** Три существенных уточнения. (1) Механизм иной: команда не «деградирует до литерального текста» — она абортится целиком с ошибкой, Клод вообще не получает промпт. (2) Скоуп уже: простые строки (9, 15, 19, 23, 27, 31, 35-37 — cat/git с || и пайпами) проходят БЕЗ allowed-tools (safe read-only команды авто-аппрувятся при статическом анализе); ломают команду только строки 41 и 45 — из-за $(...) и bash "$VAR", которые «cannot be statically analyzed». Причём у Антона баг сейчас замаскирован: в его ~/.claude/settings.json стоит бланкетный "Bash" в permissions.allow — /forge:start у него работает; сломано только у сторонних пользователей marketplace. (3) Предложенный фикс НЕ работает: проверил точный список из находки (Bash(cat:*), ..., Bash(gh issue view:*), Bash(bash:*)) — та же ошибка статического анализа, scoped-паттерны не лечат нестатически-анализируемые команды. Рабочие варианты: allowed-tools: Bash (бланкетный — проверено, все 6 строк исполнились и попали в контекст) либо переписать строки 41/45 без $(...)/compound-синтаксиса. Бонус-баг: строка 36 (git branch --show-current без || echo) при ненулевом exit-коде (не-git директория) тоже абортит всю команду даже С allowed-tools: Bash.

## [5] MAJOR / commands — COMMANDS.md: пайплайн описан как 4-фазный, /forge:refine-idea вообще не документирован, handoff new-task противоречит скиллу
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/COMMANDS.md:9-51,162,756

Заголовок «## Сердце плагина: 4-фазный pipeline» (строка 9) и схема «/forge:new-task → /forge:plan → /forge:critique → /forge:execute» (строка 14), workflow «Полный цикл разработки (4-фазный пайплайн)» (строка 756) — при том что README.md:3 («6-фазный пайплайн») и корневой CLAUDE.md (6 фаз 0→1→1.5→2→3→4) уже синхронизированы в v7.4.0. `grep -c refine-idea COMMANDS.md → 0` — команда commands/refine-idea.md существует, но в «полном справочнике» отсутствует, единственная из фаз. Хуже: секция new-task (строка 162) утверждает «Handoff: на коротком "ОК" автоматически передаёт управление в /forge:plan», а skills/new-task/SKILL.md:103 говорит «сразу инвокни refine-idea skill (Phase 1.5). Не жди явного /refine-idea». Клод или Антон, читающие COMMANDS.md, получат маршрут в обход Phase 1.5 — реалити-чек идеи будет пропущен.

**Как исправить:** Переписать шапку COMMANDS.md на 6 фаз (0→1→1.5→2→3→4), добавить секцию «/forge:refine-idea (Phase 1.5)» между new-task и plan, исправить handoff new-task на «→ /forge:refine-idea», обновить оба Workflow-блока. Заодно дополнить таблицу Commands Reference в корневом CLAUDE.md — там grep не находит init, hookify, evolve, design, api-design, migrate, deploy, security-review (8 из 25 команд).

**Уточнение верификатора:** Severity чуть завышена в части «Клод получит маршрут в обход Phase 1.5»: runtime-handoff управляется SKILL.md (инжектится при инвокации скилла), а COMMANDS.md не подгружается в контекст автоматически — пропуск Phase 1.5 случится только если COMMANDS.md явно прочитан. Это документационный дрейф с риском дезинформации читателя (и Клода, если файл в контексте), а не гарантированный сбой пайплайна. Предложение фикса корректно; при правке учесть все 3 вхождения «4-фазный» (строки 9, 756, 955) и workflow-блоки, где new-task идёт сразу в plan.

## [6] MAJOR / commands — init.md генерирует в чужие проекты устаревший CLAUDE.md: «5-phase pipeline», без Phase 0 и refine-idea в таблице
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/commands/init.md:564,613-629

Встроенный в /forge:init шаблон CLAUDE.md содержит «## Development Workflow (5-phase pipeline)» (строка 564) — без Phase 0 (unblocker/direction); в генерируемой таблице Commands Reference (строки 613-629) нет строк /forge:refine-idea и /forge:roadmap, хотя Phase 1.5 упомянута в workflow выше, а /forge:unblocker подписан просто «When stuck» вместо «Phase 0». Строка 618: «/forge:critique | Phase 3 — 4 персоны рвут план (confidence ≥80%)» — формулировка, которую v7.4.0 уже убрал из собственных доков плагина. Итог: каждый новый проект пользователя инициализируется документацией, противоречащей актуальному поведению плагина — дрейф закладывается прямо на старте, и self-check 14e его не ловит (проверяет только плейсхолдеры и размер).

**Как исправить:** Синхронизировать шаблон в Step 14d с корневым CLAUDE.md: «6-фазный pipeline (0 → 1 → 1.5 → 2 → 3 → 4)», добавить Phase 0 в workflow и строки /forge:refine-idea (Phase 1.5), /forge:roadmap в таблицу, убрать «(confidence ≥80%)». В self-check 14e добавить пункт «таблица команд содержит все 6 фаз».

**Уточнение верификатора:** Две неточности. (1) Утверждение «(confidence ≥80%) — формулировка, которую v7.4.0 уже убрал из собственных доков» неверно: git log -S "confidence" -- CLAUDE.md пуст (фразы там никогда не было), а фильтр confidence ≥ 80% — живой рабочий механизм критики (skills/critique/SKILL.md:78,104,175). Убрать её из таблицы можно для единообразия с корневым CLAUDE.md, но это не «противоречие актуальному поведению». (2) «Self-check 14e проверяет только плейсхолдеры и размер» неверно: 14e содержит 7 проверок, включая пункт 6 «Commands table complete: At minimum: start, new-task, plan, critique, execute, sync, validate, cleanup» (init.md:653). Дрейф не ловится потому, что этот минимальный список устарел — чинить нужно его (добавить refine-idea, unblocker/Phase 0, roadmap), а не добавлять новый пункт. Также спорно включение /forge:roadmap в шаблон каждого проекта: команда осмысленна только при github_sync: true — можно добавлять условно.

## [7] MAJOR / commands — discover.md: bash-блоки с /plugins и /install (неисполнимо), ссылка на несуществующую команду /forge:writing-skills, и всё это model-invocable
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/commands/discover.md:69,200,237

Строка 69: «Run in Claude Code: ```bash /plugins```» и строка 200: «```bash /install plugin-name```» — это интерактивные UI-команды Claude Code, в bash они гарантированно падают с command not found; модель, следуя инструкции буквально, получит ошибку. Строка 237: «Use `/forge:writing-skills` to create skill» — команды writing-skills не существует (есть только скилл forge:writing-skills, в commands/ файла нет). При этом discover — одна из 6 команд без disable-model-invocation, т.е. модель может сама её инвокнуть по описанию «Search Claude Code marketplace...», хотя тело честно признаёт «Real marketplace search API doesn't exist yet» (строка 80) — потратит контекст на заглушку.

**Как исправить:** 1) Добавить `disable-model-invocation: true` (по образцу session-insights/cleanup из прошлого аудита). 2) Заменить bash-блоки на текст «предложи пользователю выполнить /plugins вручную». 3) Строку 237 заменить на «Invoke the forge:writing-skills skill». 4) В description честно указать, что поиск маркетплейса — пока анализ плана + рекомендации без API.

**Уточнение верификатора:** Три уточнения по severity. 1) Блок /install (стр. 200) лежит внутри «Step 7: Install Approved (Future)» с пометкой «Future implementation», а Step 3 (стр. 85) велит «Skip to Step 6» — путь недостижим в текущем потоке, реально опасен только живой /plugins на стр. 69. 2) Ссылка /forge:writing-skills (стр. 237) — не жёсткая поломка: скилла forge:writing-skills существует, а Claude Code резолвит ссылки вида «/<имя>» через Skill tool, так что модель скорее всего попадёт куда надо; это несогласованность нотации, а не битая ссылка. 3) Отсутствие disable-model-invocation может быть полуосознанным: в аудите 899cd44 флаг ставили только «командам-дублям» скиллов, а у discover скилла-двойника нет. Но предложение всё равно валидно: заявленная интеграция «plan skill should prompt user to run this command» (стр. 245) не существует (в plan нет ни одного упоминания discover), так что отключение model-invocation ничего не теряет, а честная правка description — главный фикс.

## [8] MAJOR / dead-weight — tests/opencode/ полностью сломан — 0 из 2 тестов проходят, тестирует удалённый runtime
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/opencode/setup.sh:24

setup.sh копирует файл, которого нет нигде в репо: `cp "$REPO_ROOT/.opencode/plugins/forge.js" ...` — директории .opencode/ не существует (проверено find по всему репо). Все 4 теста сьюта source-ят setup.sh, поэтому падают на первой же строке. Реальный запуск `bash run-tests.sh` даёт: «cp: .../.opencode/plugins/forge.js: No such file or directory ... Passed: 0, Failed: 2, STATUS: FAILED». Сьют тестирует OpenCode-плагин, которого в репо больше нет — это мёртвый груз, создающий иллюзию тестового покрытия и красный статус при любом запуске.

**Как исправить:** Удалить директорию tests/opencode/ целиком (вместе с lib/, см. следующую находку). Если поддержка OpenCode когда-нибудь вернётся — тесты вернутся вместе с самим forge.js. Заодно убрать упоминание «bash в tests/opencode/» из секции Running в CLAUDE.md.

**Уточнение верификатора:** Мелкие уточнения: сломанный cp находится на строке 22 setup.sh, а не 24; тесты падают не «на первой же строке», а на этом cp (set -euo pipefail обрывает выполнение). И формулировка «тестирует удалённый runtime» чуть неточна: git log --all показывает, что forge.js никогда не коммитился в этот репозиторий — сьют не мог пройти ни в одной точке истории, т.е. runtime не «удалён», а никогда здесь не существовал. Суть находки это только усиливает.

## [9] MAJOR / dead-weight — lib/skills-core.js — мёртвый код: единственные потребители — сломанные opencode-тесты, и даже они его не импортируют
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/lib/skills-core.js:108-140

Grep по репо: skills-core упоминается только в CLAUDE.md и трёх файлах tests/opencode/ (которые не запускаются — см. выше). Причём test-skills-core.sh даже не импортирует реальную библиотеку — он содержит комментарий «Inline the extractFrontmatter function for testing» и тестирует скопированную внутрь теста версию функции, т.е. регрессию в настоящем файле не поймал бы никогда. Вдобавок файл несёт остатки форка superpowers: `skillName.startsWith('superpowers:')`, `sourceType: 'superpowers'` (resolveSkillPath, строки 108-140). При этом правило .claude/rules/core-lib.md называет это «Core plugin code. Changes here affect all users» — вводит в заблуждение и заставляет писать тесты перед правкой мёртвого файла.

**Как исправить:** Удалить forge-plugin/lib/ вместе с tests/opencode/, убрать строку про lib/skills-core.js из Technical Stack и Project Structure в CLAUDE.md, удалить .claude/rules/core-lib.md (или перенацелить его на hooks/ — настоящий core плагина).

**Уточнение верификатора:** Две поправки к предложению. 1) core-lib.md в frontmatter уже таргетирует и forge-plugin/lib/**, и forge-plugin/hooks/** — удалять правило целиком нельзя (потеряется легитимный guardrail для hooks, настоящего core); правильный фикс — убрать только глоб forge-plugin/lib/**. 2) CLAUDE.md не вводит в заблуждение: он честно пишет «lib/ — JS утилиты (legacy, для OpenCode)» и «используется только в OpenCode тестах»; вводит в заблуждение только формулировка в core-lib.md. Само удаление lib/ + tests/opencode/ + строк из CLAUDE.md — обоснованно.

## [10] MAJOR / dead-weight — agents/forge-documenter.md и agents/structure-enforcer.md никогда не диспатчатся — все вызовы идут через general-purpose с inline-промптами
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/agents/structure-enforcer.md

Grep по skills/ и commands/: единственный агент, вызываемый по имени — `Task tool (forge:code-reviewer)` (requesting-code-review/SKILL.md, code-quality-reviewer-prompt.md:10). Оба других агента дублируются inline: commands/sync.md:75-88 диспатчит «Agent tool (general-purpose)» с укороченной копией промпта structure-enforcer'а, а skills/subagent-driven-development/forge-documenter-prompt.md:10 и sync.md Step 2 — «Task tool (general-purpose)» вместо forge-documenter. Вызов `forge:forge-documenter` встречается только в docs/Forge spec v2.md:499 (спека, не runtime). Итог: два файла агентов регистрируются в каждой сессии (занимают контекст в списке доступных субагентов), но никогда не используются, а их inline-копии уже разъехались по содержанию (sync.md-версия structure-enforcer'а заметно короче и без секции Critical violations).

**Как исправить:** Выбрать одно из двух: (а) в sync.md и forge-documenter-prompt.md диспатчить по имени — `Task tool (forge:structure-enforcer)` / `(forge:forge-documenter)` — и убрать inline-дубли, чтобы был один источник правды; или (б) если inline-подход осознанный — удалить agents/forge-documenter.md и agents/structure-enforcer.md, оставив только рабочий code-reviewer.md.

**Уточнение верификатора:** Дрейф даже сильнее, чем в находке: inline-копия documenter'а (forge-documenter-prompt.md) застряла на legacy-формате v2 — пишет только spec.json/map.json, тогда как agents/forge-documenter.md уже детектит v3 (spec.yml/map.yml). Т.е. рабочий inline-путь документирует в устаревший формат. Плюс внутреннее противоречие: граф в subagent-driven-development/SKILL.md:66,88 обещает «Dispatch forge-documenter subagent», а шаблон рядом диспатчит general-purpose. Мелкая оговорка: «занимают контекст» — эффект небольшой (пара описаний агентов в списке доступных субагентов), главная цена — двойной источник правды и уже случившийся рассинхрон форматов.

## [11] MAJOR / dead-weight — evals/ — пустой каркас, выдающий себя за работающую систему; критерии застряли на старом 4-фазном пайплайне
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/evals/README.md

README заявляет: «Этот эвал-сетап показывает карту реальных провалов на основе 116+ сессий Антона» и «Перед каждым Bump to vX.Y.Z коммитом (gate релиза)». Реальность: corpus/ не существует вовсе, error-analysis.tsv — одна строка заголовка, transition-matrix.tsv — все нули, run-evals.sh (Этап 4 README) не существует, taxonomy-v1.md (упомянут и в README, и в CLAUDE.md) не существует. Ничего не трогалось с 2026-05-14 (git log), хотя с тех пор вышли v7.3 и v7.4 — «gate релиза» ни разу не срабатывал. Criteria покрывают только new-task/plan/critique/execute/handoff — фаз 0 (unblocker) и 1.5 (refine-idea) нет, transition-matrix.tsv тоже знает только 4 фазы. Это мёртвый груз, который к тому же документирован в CLAUDE.md как существующая инфраструктура.

**Как исправить:** Либо реанимировать: Этап 1 (сбор корпуса) по README занимает 30 минут — скопировать трейсы, добавить criteria/unblocker.yml и criteria/refine-idea.yml, расширить transition-matrix до 6 фаз, написать run-evals.sh. Либо честно пометить в evals/README.md и CLAUDE.md статус «каркас, не запускался» и убрать заявления про 116+ сессий и gate релиза, удалив ссылки на несуществующие taxonomy-v1.md и corpus/.

**Уточнение верификатора:** Формулировка «выдающий себя за работающую систему» чуть завышена для README в целом: его Этапы 1-5 написаны как инструкция-playbook на будущее, и сам коммит честно назван «eval skeleton» — автор знал, что это каркас. Но вводная фраза README про «116+ сессий» (настоящее время) и особенно секция Evals в CLAUDE.md, безоговорочно перечисляющая несуществующие corpus/raw/*.jsonl и taxonomy-v1.md как имеющиеся артефакты, действительно вводят в заблуждение. Минимальный фикс — второй вариант предложения (честная пометка «каркас, не запускался» + правка CLAUDE.md) — дешевле и адекватнее реанимации.

## [12] MAJOR / dead-weight — tests/claude-code/ запускает claude без --plugin-dir — тестирует установленный плагин, а не рабочую копию
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/claude-code/test-helpers.sh:13

run_claude строит команду `cmd="claude -p \"$prompt\""` без флага --plugin-dir; интеграционный тест (test-subagent-driven-development-integration.sh:152) — так же. Grep подтверждает: PLUGIN_DIR в tests/claude-code/ не встречается ни разу, тогда как соседние сьюты это делают правильно (tests/skill-triggering/run-test.sh:50 передаёт `--plugin-dir "$PLUGIN_DIR"`). Итог: тесты проверяют версию плагина из глобального кеша (~/.claude/plugins), а не изменённые файлы в репо — правишь скилл, гоняешь тест, а он зелёный/красный по старой версии. Ложная уверенность ровно там, где тесты должны ловить регрессии скилла.

**Как исправить:** В test-helpers.sh добавить в run_claude флаг `--plugin-dir "$(cd "$SCRIPT_DIR/../.." && pwd)"` (по образцу skill-triggering/run-test.sh), и то же самое в строку 152 интеграционного теста. Заодно передавать prompt через массив аргументов, а не через строку с eval-подобной подстановкой кавычек.

**Уточнение верификатора:** Два уточнения. (1) Поведение полу-документировано: tests/claude-code/README.md в Requirements пишет «Local forge plugin installed» — но это не оправдание, а часть той же ошибки, потому что комментарий в самом интеграционном тесте (строка 138) прямо декларирует намерение тестировать локальные dev-скиллы, которое не выполняется. (2) Смягчение severity: маркетплейс указывает на тот же репозиторий автора, поэтому установленная версия часто близка к HEAD — расхождение бьёт именно по незакоммиченным/незапушенным правкам, т.е. ровно в момент, когда тесты и гоняют перед коммитом. Предложение фикса корректно: $SCRIPT_DIR в test-helpers.sh задаётся сорсящим тестом (оба лежат в tests/claude-code/), так что `--plugin-dir "$(cd "$SCRIPT_DIR/../.." && pwd)"` укажет на корень forge-plugin; замечание про передачу prompt массивом вместо `bash -c "$cmd"` тоже по делу — текущая склейка ломается на промптах с кавычками/$.

## [13] MAJOR / docs-reality — .forge/index.yml протух на 3 версии и врёт в каждом промпте
**Файл:** /Users/mac/Projects/Plugin/plugin/.forge/index.yml:3-11,48-58

Подозрение подтвердилось полностью: version: "7.1.2" (plugin.json — 7.4.0), goal: «…через 4-фазный pipeline (new-task → plan → critique → execute)» — фаз уже 6; now.task: «Готово к мерджу feat/github-project-map», now.branch: feat/github-project-map — ветка давно влита, текущая master; session.started: 2026-05-14, last_session: «2026-05-14 — Sync…» — сегодня 2026-07-03, с тех пор были v7.2–v7.4 (refine-idea, unblocker, аудит). Этот файл — L0, context-inject.sh инжектит его в КАЖДЫЙ промпт: Claude в каждом сообщении получает ложную цель (4 фазы), ложную текущую задачу и двухмесячной давности сессию.

**Как исправить:** Прогнать /forge:sync (или руками): goal → 6-фазный pipeline (0 → 1 → 1.5 → 2 → 3 → 4), version → 7.4.0, now/session/last_session → реальное состояние (master, аудит v7.4.0). Добавить в finishing-a-development-branch/session-awareness шаг «обнови version и now в index.yml», чтобы не протухал снова.

**Уточнение верификатора:** Два уточнения, не меняющие сути. 1) Про ветку хук частично сам себя исправляет: в ту же инжекцию context-inject.sh добавляет живые «--- Branch: master» + последние 3 коммита, так что Claude видит противоречие, а не чистую ложь о ветке; но goal (4 фазы), version и session-блок противовеса не имеют. 2) index.yml — gitignored runtime-память конкретной машины, а не доки в репо, поэтому это провал петли памяти плагина (session-awareness/sync не сработали за ~7 недель и 3 минорных версии), что усиливает вторую часть предложения: важнее добавить обязательный шаг обновления index.yml в finishing-a-development-branch/session-awareness, чем разово прогнать /forge:sync.

## [14] MAJOR / docs-reality — COMMANDS.md: до сих пор «4-фазный pipeline», фаза 1.5 (refine-idea) отсутствует полностью
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/COMMANDS.md:9,13-17,756,955

Прошлый аудит заявил «синхронизация COMMANDS.md… (6 фаз)», но в файле трижды осталось «4-фазный pipeline» (строки 9 «## Сердце плагина: 4-фазный pipeline», 756, 955), схема конвейера на строках 13-17 показывает только new-task → plan → critique → execute без Phase 0 и 1.5. Хуже: команда /forge:refine-idea НЕ УПОМЯНУТА ВООБЩЕ (grep по файлу — 0 совпадений), хотя commands/refine-idea.md существует — задокументированы 24 команды из 25. Справочник противоречит README («6-фазный»), CLAUDE.md и session-start.sh, который каждую сессию показывает 6 фаз.

**Как исправить:** Переписать шапку и все три места на 6-фазный pipeline (0 → 1 → 1.5 → 2 → 3 → 4), добавить в схему unblocker и refine-idea, добавить секцию «/forge:refine-idea (Phase 1.5)» между new-task и plan, обновить handoff у new-task (сейчас пишет «на ОК → /forge:plan», а по CLAUDE.md handoff идёт в /refine-idea).

**Уточнение верификатора:** Мелкое уточнение: Phase 0 (/forge:unblocker) в COMMANDS.md всё же задокументирован отдельной секцией (строка 348 «## 10. /forge:unblocker (Phase 0: Direction)» и строка 877) — полностью отсутствует только refine-idea; Phase 0 не хватает лишь в головной схеме пайплайна (строки 13-17) и в workflow-блоках. Предложение ревью корректно и лучше статус-кво.

## [15] MAJOR / docs-reality — Evals описаны в CLAUDE.md как живые, но это пустой скелет на 4 фазы
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/evals/transition-matrix.tsv:1 (+ CLAUDE.md:192-196)

CLAUDE.md перечисляет «corpus/raw/*.jsonl — реальные сессии», «taxonomy-v1.md — axial coding» — обоих НЕ существует (директории corpus/ нет, taxonomy-v1.md нет); error-analysis.tsv содержит только строку заголовка, ни одного трейса. evals/README.md:9 заявляет карту провалов «на основе 116+ сессий Антона» — данных ноль. Плюс transition-matrix.tsv знает только 4 фазы («from_phase / to_new-task / to_plan / to_critique / to_execute / to_END») и criteria/ содержит только new-task/plan/critique/execute/handoff — переходы unblocker→new-task и new-task→refine-idea→plan, где по опыту всё и ломается, не измеряются в принципе.

**Как исправить:** Либо честно пометить в CLAUDE.md и evals/README статус «скелет, корпус не собран» и убрать «116+ сессий», либо реально собрать корпус. В любом случае расширить transition-matrix.tsv и criteria/ на фазы 0 и 1.5 (unblocker, refine-idea) — иначе eval-сетап меряет несуществующий 4-фазный пайплайн.

**Уточнение верификатора:** Небольшая поправка к тону: скелетность частично осознанная — коммит 9d4106c прямо называет это «eval skeleton», а тело README написано в императиве как инструкция-workflow («Этап 1: Сбор корпуса... Цель: 30 трейсов для старта»), т.е. это план работ, а не имитация результатов. Вводят в заблуждение конкретно две вещи: README.md:9 (настоящее время «показывает... на основе 116+ сессий») и список несуществующих файлов в CLAUDE.md без пометки статуса. Предложение ревью адекватно: пометить статус «скелет, корпус не собран», убрать/переформулировать «116+ сессий» (например, «планируется на базе ~116 сессий») и расширить criteria/ + transition-matrix на фазы 0 и 1.5.

## [16] MAJOR / docs-reality — docs/forge-runtime-flow.md описывает противоположное тому, что делает код хуков
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/docs/forge-runtime-flow.md:14-15,22-25,52,69,167-180

Архитектурный документ (на него ссылается CLAUDE.md: «docs/ — спецификация, архитектура, runtime-flow») противоречит коду: (1) утверждает, что SessionStart «Инжектит полный текст using-forge в контекст», тогда как session-start.sh прямо говорит «Не дампим весь using-forge skill» и шлёт короткое интро; (2) везде фигурирует «.forge/index.md (~400 токенов)», map.json, journal.md — реально index.yml с лимитом 2500 байт (~250 токенов) и *.yml; (3) раздел «The 4-Phase Pipeline» («строгий 4-фазный пайплайн», строка 69) — фаз 6; grep по refine-idea/unblocker/github-sync/roadmap даёт 0 совпадений. Кто откроет этот файл, чтобы понять runtime, получит ложную картину.

**Как исправить:** Переписать под текущий runtime: session-start = короткое интро + ROUTING/DOC DISCIPLINE, context-inject = index.yml (cap 2500 байт) + branch + git log + graph hint, пайплайн 0→1→1.5→2→3→4, добавить github-sync. Синхронно перегенерировать forge-runtime-flow.html.

**Уточнение верификатора:** Две мелочи: (а) .forge/index.md не полностью «противоположен коду» — context-inject.sh:17 всё ещё поддерживает его как legacy fallback, но основной путь — index.yml, так что суть претензии верна; (б) находка недоучла ещё одно расхождение: док (строка 90) называет персоны critique как Architect/Security/UX/Pragmatist, тогда как реальные — Skeptic/Pragmatist/Architect/User Advocate; стоит поправить при переписывании. Оценка «~250 токенов» для 2500 байт занижена (~600-700), но это цитата из CLAUDE.md и на валидность не влияет.

## [17] MAJOR / docs-reality — Три манифеста с разными версиями и авторами: корневой marketplace.json застрял на 6.2.0
**Файл:** /Users/mac/Projects/Plugin/plugin/.claude-plugin/marketplace.json:13

Корневой .claude-plugin/marketplace.json — именно его читает Claude Code при «/plugin marketplace add anton-ai5010/forge» — объявляет «version»: «6.2.0», на мажор позади plugin.json (7.4.0): установка/проверка обновлений покажет древнюю версию. Параллельно forge-plugin/.claude-plugin/marketplace.json называется «forge-dev» с owner/author «Jesse Vincent» (upstream-автор), а plugin.json указывает homepage/repository на https://github.com/obra/forge — чужой upstream, а не anton-ai5010/forge. README при этом говорит «форкнут от obra/forge… дальше переделан», т.е. метаданные противоречат позиционированию.

**Как исправить:** Поднять версию в корневом marketplace.json до 7.4.0 (и добавить bump этого файла в релизный чеклист вместе с plugin.json), заменить homepage/repository в plugin.json на https://github.com/anton-ai5010/forge, унифицировать owner/author. Внутренний forge-plugin/.claude-plugin/marketplace.json («forge-dev», Jesse Vincent) либо удалить, либо привести к тем же данным.

**Уточнение верификатора:** Два уточнения: (1) внутренний forge-dev marketplace.json НЕ отстал по версии — там 7.4.0; претензия к нему только по owner/author Jesse Vincent и тому, что это неиспользуемый остаток апстрима. (2) README (forge-plugin/README.md:36) даёт команду установки «plugin marketplace add anton-ai5010/forge-plugin», хотя репозиторий называется anton-ai5010/forge — дополнительная нестыковка в ту же копилку, стоит поправить вместе с манифестами.

## [18] MAJOR / hooks — bash-safety: `git push -f origin main` (самая частая форма force-push) не блокируется
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/hooks/bash-safety.sh:28

Регэксп `(--force|--force-with-lease|-f[[:space:]])[[:space:]].*` требует ДВА пробельных символа после `-f`: альтернатива `-f[[:space:]]` съедает единственный пробел, а следом обязателен ещё один `[[:space:]]`. Проверено запуском хука: `git push -f origin main` → ALLOWED, `git push --force origin main` → BLOCKED. То есть самое распространённое написание force-push в защищённые ветки проходит насквозь — хук создаёт ложное чувство безопасности ровно на той команде, ради которой написан (перезапись истории на удалёнке). Бонус-дыра: форма `git push origin main -f` (флаг после ветки) тоже не ловится, т.к. паттерн требует флаг ДО имени ветки. И спорное: блокируется `--force-with-lease` — безопасный рекомендованный вариант.

**Как исправить:** Не завязываться на порядок слов — три независимых grep, соединённых &&: (1) `grep -qE 'git[[:space:]]+push'`, (2) `grep -qE '(^|[[:space:]])(-[a-zA-Z]*f[a-zA-Z]*|--force)([[:space:]]|$)'`, (3) `grep -qE '(^|[[:space:]:])(main|master)([[:space:]]|$)'`. Заодно убрать `--force-with-lease` из блокировки (или сделать warn), это штатный безопасный способ.

**Уточнение верификатора:** Основная дыра (-f не ловится) и дыра с флагом после ветки — подтверждены на 100%. Спорный пункт про --force-with-lease — вкусовщина, не баг: он тоже переписывает историю на удалёнке, и блокировать его в main/master для не-кодера — осмысленный консерватизм; предлагать разблокировку не обязательно (максимум warn). Предложенный трёхступенчатый grep-фикс для основного бага корректен и лучше статус-кво.

## [19] MAJOR / hooks — bash-safety: `rm -rf /*`, `rm -r -f /`, `rm -rf "/"` не блокируются
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/hooks/bash-safety.sh:22

Проверено запуском хука: `rm -rf /*` → ALLOWED (классическая и самая частая деструктивная форма — паттерн цели `(/[[:space:]]*$|/[[:space:]]+...)` не допускает `*` после `/`); `rm -r -f /` → ALLOWED (раздельные флаги — паттерн требует r и f в одном токене); `rm -rf "/"` → ALLOWED (кавычки вокруг пути не предусмотрены). Также не ловится `rm --recursive --force /`. Итог: пункт 1 «rm -rf на критический путь» обходится четырьмя тривиальными вариациями, которые Claude вполне может сгенерировать сам без злого умысла.

**Как исправить:** Разбить проверку на два grep: наличие обоих флагов в любой форме `rm(([[:space:]]+-[a-zA-Z]+)*[[:space:]]+)` + `(-[a-zA-Z]*r|--recursive)` и `(-[a-zA-Z]*f|--force)`; цель — допускать кавычки и глоб: `(^|[[:space:]])["'\'']?(/\*?|~/?|\$HOME)["'\'']?([[:space:]]|$)`. Полную защиту от переменных (`X=/; rm -rf $X`) паттернами не дать — честно написать это ограничение в комментарии хука.

**Уточнение верификатора:** Severity адекватна, но предложение доработать: два независимых grep, соединённых по И на всю строку команды, дадут ложные срабатывания на составных командах (например 'rm -rf ./tmp && ls /' — первый grep находит rm с флагами, второй — несвязанный '/'). Лучше один комбинированный regex с расширенными альтернативами флагов (включая раздельные '-r ... -f' и '--recursive/--force') и целей (кавычки, '/*'), либо применять проверку цели только к тексту после найденного вызова rm. Замечание находки о принципиальной необходимости честного комментария про обход через переменные — верное и стоит сохранить (паттернами не закрыть также 'find / -delete', 'sh -c').

## [20] MAJOR / hooks — bash-safety: dd-защита не знает macOS-устройства /dev/disk* — а Антон на macOS
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/hooks/bash-safety.sh:40

Паттерн `of=/dev/(sd[a-z]|nvme[0-9]|hd[a-z])` перечисляет только Linux-имена дисков. На macOS блочные устройства называются `/dev/disk0`, `/dev/rdisk0`. Проверено: `dd if=/dev/zero of=/dev/disk0` → ALLOWED. Плагин при этом явно ориентирован на мак (в hooks.json первым идёт `afplay`, у пользователя Darwin) — т.е. на реальной платформе пользователя пункт 4 «затирание диска» не работает вовсе.

**Как исправить:** Расширить группу устройств: `of=/dev/(r?disk[0-9]|sd[a-z]|nvme[0-9]|hd[a-z])`. Заодно можно добавить `mkfs`/`diskutil eraseDisk` в тот же блок — это те же «затирание диска» одной строкой.

**Уточнение верификатора:** Находка точна, предложенный регэксп `of=/dev/(r?disk[0-9]|sd[a-z]|nvme[0-9]|hd[a-z])` корректен (проверено: матчит disk0/rdisk0, не ломает Linux-имена). Два уточнения: 1) вместе с регэкспом надо обновить и текст сообщения в блоке (сейчас «sd/nvme/hd»); 2) добавление mkfs/diskutil eraseDisk — разумное, но отдельное расширение сверх исходной находки, а не часть бага. Практическая severity умеренная (запись в raw-устройство требует sudo), но это last-line защита, и на целевой платформе она сейчас нулевая.

## [21] MAJOR / manifest — Версия в корневом marketplace.json отстала: 6.2.0 против 7.4.0 в plugin.json
**Файл:** /Users/mac/Projects/Plugin/plugin/.claude-plugin/marketplace.json:12

Корневой marketplace.json (именно его читает Claude Code при "/plugin marketplace add anton-ai5010/forge") заявляет "version": "6.2.0", тогда как plugin.json — "version": "7.4.0". Уже минимум 5 релизов (7.3.0, 7.3.1, 7.4.0 и т.д.) версия в витрине не обновлялась. Пользователь в списке marketplace видит устаревшую версию, а логика определения обновлений может считать, что новых версий нет.

**Как исправить:** Поднять версию до 7.4.0 и убрать дублирование на будущее: либо удалить поле version из записи плагина в marketplace.json (пусть тянется из plugin.json), либо добавить в релизный чек-лист/скрипт синхронную правку обоих файлов.

**Уточнение верификатора:** Основной подтверждённый эффект — устаревшая версия в отображении витрины. Вторая часть претензии ("логика определения обновлений может считать, что новых версий нет") — спекуляция: при установке/обновлении Claude Code перечитывает репозиторий и авторитетным считается plugin.json плагина, так что обновления, скорее всего, доезжают. Severity — низкая (косметика/гигиена релиза), предложение из находки разумно: либо убрать необязательное поле version из записи в marketplace.json, либо добавить синхронный бамп в релизный чек-лист.

## [22] MAJOR / manifest — Внутренний marketplace.json — целиком наследие форка: владелец Jesse Vincent, чужое описание
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/.claude-plugin/marketplace.json

Файл forge-plugin/.claude-plugin/marketplace.json объявляет marketplace "forge-dev" с owner и author "Jesse Vincent" <jesse@fsck.com> и описанием "Core skills library for Claude Code: TDD, debugging, collaboration patterns" — это метаданные оригинального плагина, а не этого проекта (здесь 6-фазный pipeline для не-кодера). В репо получилось ДВА конкурирующих marketplace.json с разными именами (forge-marketplace против forge-dev), разными владельцами и до этого коммита — разными версиями. Кто добавит marketplace по пути forge-plugin/, увидит Джесси владельцем и ложное описание.

**Как исправить:** Удалить forge-plugin/.claude-plugin/marketplace.json — рабочая витрина уже есть в корне репо, второй файл только создаёт конфликт метаданных. Если он нужен для локальной разработки (add по пути ./forge-plugin), переписать owner/author на Антона и описание на реальное, и версию держать в синхроне.

**Уточнение верификатора:** Две поправки. (1) Предложение «удалить файл» — плохой вариант: forge-dev marketplace активно используется для локальной разработки, docs/testing.md:38 и :186 требуют `"forge@forge-dev": true` в ~/.claude/settings.json для запуска тестов. Правильный фикс — только второй вариант из предложения: переписать owner/author на Антона и описание на реальное. (2) Деталь про версии перевёрнута: внутренний файл как раз бампается каждый релиз и сейчас в синхроне с plugin.json (7.4.0), а отстал корневой marketplace.json — застрял на 6.2.0 с коммита b95151b. Синхронизировать версию нужно в корневом файле. Severity умеренная: это dev-витрина, конечных пользователей (корневой путь установки) она не затрагивает.

## [23] MAJOR / manifest — Заявлена лицензия MIT, но файла LICENSE нет нигде в репозитории
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/.claude-plugin/plugin.json:11

plugin.json содержит "license": "MIT", но проверка (ls LICENSE* в корне репо и в forge-plugin/) показала: файла LICENSE не существует вообще. Для форка это двойная проблема: (1) заявление "MIT" без текста лицензии юридически пусто — пользователи не получают формального права использовать/модифицировать код; (2) MIT-лицензия оригинала obra требует сохранения копирайт-нотиса и текста лицензии в производных работах — одной строчки благодарности в README (строка 81) для соблюдения условий MIT недостаточно.

**Как исправить:** Добавить файл LICENSE в корень репо (и/или в forge-plugin/) с текстом MIT и двумя строками копирайта: "Copyright (c) Jesse Vincent (original superpowers/forge)" + "Copyright (c) 2026 Anton (модификации)". Взять точный копирайт-нотис из оригинального репозитория superpowers.

**Уточнение верификатора:** Мелкое уточнение формулировки: «юридически пусто» слегка завышено — декларация "license": "MIT" в метаданных обычно трактуется как намерение лицензировать под MIT, так что права пользователей скорее «юридически неоднозначны», чем нулевые. Главная же часть (нарушение notice-условия MIT оригинала для производной работы) подтверждается полностью. Также точный копирайт-нотис стоит брать из LICENSE репозитория obra/superpowers — ссылка obra/forge из README может не существовать как отдельный репо.

## [24] MAJOR / pipeline — execute создаёт ветку, но никогда не ведёт в finishing-a-development-branch
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/execute/SKILL.md:192

finishing-a-development-branch/SKILL.md:226-228 заявляет «Called by: execute — After implementation completes», а CLAUDE.md обещает «finishing... по команде 'мержим' сам сохранит несохранённое, вольёт в master». Но в execute/SKILL.md нет ни одного упоминания finishing: финальный отчёт (строка 192) предлагает «Открыть в редакторе? Запустить тесты целиком? Сделать коммит?» — ни слова про мерж. Шаг 1.5 молча создал `feat/<slug>`, и не-кодер Антон, который «не должен думать про git» (execute:64), остаётся на фиче-ветке навсегда: он не знает слова «мержим», ему его никто не предложил. Следующая задача начнётся с пункта 5 («ты на чужой ветке») и правки начнут копиться стопкой незамерженных веток. Вдобавок «Сделать коммит?» противоречит git-модели CLAUDE.md («ручные коммиты по ходу не обязательны — finishing сам сохранит»).

**Как исправить:** В финальный отчёт execute (после проверки критерия готовности) добавить явный handoff: заменить «Сделать коммит?» на «Влить в основную ветку? Скажи 'мержим' — сохраню всё и закрою ветку» + инструкцию «при согласии инвокни skill finishing-a-development-branch». Тогда заявленная в finishing интеграция станет реальной, а ветка получит выход.

**Уточнение верификатора:** Один тезис завышен: «"Сделать коммит?" противоречит git-модели CLAUDE.md» — не совсем. CLAUDE.md говорит «ручные коммиты по ходу НЕ ОБЯЗАТЕЛЬНЫ» (не запрещены), и execute:242 сам допускает «Опционально (с подтверждения пользователя): коммит». Это не противоречие, а увод пользователя в сторону от предусмотренного выхода (мержа). Ядро находки — отсутствующий handoff execute → finishing — полностью реально; предложенная правка (добавить в финальный отчёт опцию «мержим» + инвок finishing) адекватна и лучше статус-кво.

## [25] MAJOR / pipeline — Sub-issues создаются ДО критики и не пересоздаются после правок плана
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/plan/SKILL.md:230 + sync.sh:191-196

plan вызывает `add-steps` на шаге 7.5 — до показа плана пользователю (шаг 8) и до правок critique. А critique прямо учит менять состав шагов: «добавить отдельный шаг 3.5», блокеры меняют нумерацию. При этом add_steps в sync.sh:191-196 отказывается пересоздавать: «if [ -f "$mapping_file" ] && [ -s "$mapping_file" ]; then echo "substeps уже созданы"». Итог: mapping `.forge/.github-substeps-<slug>` заморожен на до-критиковой версии плана, а execute закрывает шаги по номерам ПОСЛЕ-критиковой версии — close_step (sync.sh:242) грепает `^$step_num:` и либо закрывает чужой sub-issue (нумерация сдвинулась), либо молча не находит ничего (шаг 3.5). Карта на GitHub показывает неверный прогресс.

**Как исправить:** Перенести вызов `add-steps` из plan (шаг 7.5) в critique — после применения правок и записи Execution Strategy (рядом с существующим шагом 4.5 add-critique), когда состав шагов финален. Либо добавить в sync.sh action `refresh-steps`, который сверяет заголовки шагов плана с mapping и закрывает/пересоздаёт разъехавшиеся sub-issues, и вызывать его из critique.

**Уточнение верификатора:** Две поправки. 1) Ветка «закрывает чужой sub-issue (нумерация сдвинулась)» — маловероятный сценарий: критика документированно добавляет дробные шаги (3.5), сохраняющие номера существующих; сдвиг нумерации возможен лишь при удалении/слиянии шагов (Прагматик). Типичный отказ — тихий: новые шаги без sub-issue, удалённые висят открытыми, прогресс на карте устаревший. Severity умеренная: фича opt-in (github_sync), выполнение задач не ломается — страдает только отображение. 2) Предложение «перенести add-steps в critique» имеет дыру: если пользователь остановился после /plan и не запускал критику, sub-issues не создадутся вовсе. Надёжнее второй вариант — action refresh-steps в sync.sh (сверка шагов плана с mapping), вызываемый из critique после правок, с сохранением текущего add-steps в plan как базового.

## [26] MAJOR / pipeline — refine-idea переписывает задачу, а GitHub Issue остаётся со старым текстом
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/new-task/SKILL.md:98 + refine-idea/SKILL.md:110

new-task создаёт Issue сразу после сохранения task-файла (шаг 10: «выполни шаги github-sync... Процедура для new-task»), и только ПОТОМ (шаг 11) инвокается refine-idea, чья прямая работа — «перепиши `.forge/tasks/...` с учётом доработок: уточнённая Задача, поправленный Критерий» (шаг 7). В sync.sh нет action'а для обновления тела Issue (в списке actions только create/close/reassign), и refine-idea sync не вызывает вообще. Итог: сразу после штатного прохода Phase 1.5 Issue на GitHub — устаревший, критерий готовности в нём не тот, по которому execute будет отчитываться. А если на разборе идея умирает («не стоит делать») — Issue висит открытым навсегда, cancel-пути нет.

**Как исправить:** Добавить в sync.sh action `update-task <task-file>` (по сути `gh issue edit $parent --body-file`) и `cancel-task <task-slug>` (закрыть с label forge:dropped), и вызывать update-task из refine-idea шага 7 после перезаписи файла (тихо, как остальные). Альтернатива проще: перенести create-task из new-task в конец refine-idea — Issue рождается уже из проверенной идеи.

**Уточнение верификатора:** Два уточнения. (1) Дрейф возникает только когда разбор реально изменил задачу; при исходе «идея здравая, находок нет» рассинхрона нет — но изменение задачи и есть назначение фазы 1.5, так что severity адекватна. «Висит открытым навсегда» чуть драматично (руками закрыть можно), но в тулинге cancel-пути действительно нет, а close-task пометит брошенную идею как Done. (2) Альтернатива «перенести create-task в конец refine-idea» хуже основного предложения: в процедуре new-task живут roadmap-init и milestone-матчинг с диалогом, а refine-idea пользователь может остановить «стопом» — Issue тогда не создастся вовсе. Правильный фикс — именно action `update-task` (gh issue edit --body-file, паттерн уже есть в sync_pinned) + `cancel-task`, вызываемые из шага 7 refine-idea.

## [27] MAJOR / pipeline — «Pinned Issue обновляется при каждой фазе» — не реализовано
**Файл:** /Users/mac/Projects/Plugin/plugin/CLAUDE.md:65,74

CLAUDE.md обещает: «каждая фаза публикует артефакты как Issues и обновляет карту проекта» (:65) и «Pinned Issue... обновляется при каждой фазе» (:74). Фактически `sync-all` (sync-readme + sync-pinned) вызывается только в финале execute (execute/SKILL.md:200-201) и из roadmap; в create_task/add_steps/add_critique (sync.sh) вызовов sync_pinned нет, new-task/plan/critique его не зовут. Итог: новая задача появляется на карте (Pinned Issue) и в шапке README только когда она ПОЛНОСТЬЮ выполнена — весь пайплайн задача невидима, «карта, которую Антон не может потерять» показывает вчерашний день. Плюс фазы 0 и 1.5 не синкают вообще ничего, что делает слово «каждая» неправдой дважды.

**Как исправить:** Дешёвый вариант: в конце create_task, add_steps и add_critique в sync.sh дописать вызов sync_pinned (одна gh-команда, идемпотентно). Либо честно поправить CLAUDE.md: «карта обновляется при создании задачи и в финале execute» — но первый вариант лучше отвечает заявленной цели «Антон видит живую карту».

**Уточнение верификатора:** Два уточнения. (1) «Весь пайплайн задача невидима» — преувеличение: Issue задачи создаётся на GitHub сразу в фазе 1 (create_task), в фазе 2 появляются sub-issues, в фазе 3 комментарий критики, лейблы phase-1→2→3 обновляются через relabel_phase. Устаревает только агрегированная карта: тело Pinned Issue (счётчики целей [closed/total]%) и шапка README. (2) Предложение «дописать sync_pinned в create_task, add_steps и add_critique» на 2/3 бесполезно: render_pinned.py рендерит только milestones со счётчиками issues, а sub-issues создаются БЕЗ milestone (sync.sh:205) и комментарии критики счётчиков не меняют — sync_pinned после add_steps/add_critique ничего в карте не изменит. Реально влияет только create_task (новый open issue в milestone меняет счётчик цели). Дешёвый осмысленный фикс: sync_pinned (+sync_readme) в конце create_task, плюс поправить формулировку CLAUDE.md:65,74. Заодно: фраза CLAUDE.md:74 «Issue со всеми задачами» тоже неточна — карта показывает цели с прогресс-счётчиками, а не список задач.

## [28] MAJOR / pipeline — unblocker инвокает new-task, не дав пользователю выбрать направление
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/project-unblocker/SKILL.md:185-212

Фаза 4 заканчивается «Иду по [направление 1]... Не туда — скажи, разверну другое» (строки 185-187), и сразу за ней Фаза 5 велит: «Заканчивай ОДНИМ конкретным первым шагом — и сразу запускай следующую фазу: ...Запускаю /forge:new-task» (строки 205-210). В отличие от new-task (шаг 8: «Заверши ход — дождись ответа») и plan (шаг 8: «заверши ход — дождись ответа»), здесь НЕТ инструкции завершить ход между рекомендацией и хэндоффом. Буквальное исполнение — карта, направления, рекомендация и запуск new-task в ОДНОМ сообщении: пользователь физически не может сказать «не туда». Это противоречит CLAUDE.md («финальный выбор за ним», «Auto-handoff... после 'ОК' пользователя») и собственному принципу скилла «не выбирая молча». Правило «молчание = согласие» осмысленно только когда у человека был ход для молчания.

**Как исправить:** Между Фазой 4 и Фазой 5 добавить явную границу хода, как в new-task/plan: «Показал направления + рекомендацию — ЗАВЕРШИ ХОД, дождись реакции. Любой ответ кроме возражения ('давай', 'ок', молчаливое продолжение) = согласие с дефолтом → Фаза 5 + инвок new-task». Запись памяти (direction.yml/ROADMAP.md) можно делать до паузы, инвок new-task — только после неё.

**Уточнение верификатора:** Severity слегка завышена: выбор не отбирается безвозвратно. Фаза 3 (строки 143-155) гарантирует ходы пользователя раньше (сверка карты, реакции на дыры), а сам new-task завершает ход первым уточняющим вопросом (new-task:89) — «не туда» можно сказать до появления плана/кода. Цена бага — одно перегруженное мегасообщение и зря начатый new-task, а не необратимо украденный выбор. Предложенный фикс верный, но с нюансом: паузу после Фазы 4 надо совместить с философией скилла — после паузы «не знаю»/«давай»/любой не-возражающий ответ = идти по дефолту без повторных вопросов (иначе вернётся «точка пустого выбора», с которой скилл борется). Запись direction.yml/ROADMAP.md до паузы — разумно.

## [29] MAJOR / skills-consistency — hookify врёт, что хука enforcement ещё нет — а он давно существует и зарегистрирован
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/hookify/SKILL.md:96

Секция «Выход» заканчивается: «PreToolUse-хук `bash-safety.sh` (или новый `hooks/user-rules-check.sh` если будет создан) подхватит правило». Это устаревший текст: hooks/user-rules-check.sh уже существует, зарегистрирован в hooks/hooks.json (PreToolUse, matcher "Bash|Edit|Write|NotebookEdit") и именно он читает .forge/hookrules/*.md. А bash-safety.sh правила hookrules вообще не читает. Тело скилла противоречит собственному description («rules are read live on every tool use») — Claude, следуя скиллу, может сказать Антону что механизм ещё не построен, предложить его «создать» заново или полезть дописывать правила в bash-safety.sh.

**Как исправить:** Переписать строку 96: «Файл .forge/hookrules/<slug>.md создан. PreToolUse-хук hooks/user-rules-check.sh подхватит правило при следующем вызове Bash/Edit/Write — restart не нужен.» Упоминание bash-safety.sh оставить только в шаге 6 (опциональное hardcoded-дублирование опасных команд).

**Уточнение верификатора:** Риск-сценарий слегка завышен: шаг 5 того же скилла (SKILL.md:81) уже утверждает «PreToolUse-хук подхватит его на следующем вызове Edit/Write — restart не нужен», и description говорит то же — поэтому «Claude скажет, что механизм не построен, и создаст его заново» маловероятно. Реальный вред скромнее: Claude может назвать не тот файл хука (bash-safety.sh) и, следуя шагу 6 + строке 96, полезть добавлять обычное правило в bash-safety.sh вместо .forge/hookrules/. Сама правка нужна, severity — низкая/средняя, не высокая.

## [30] MAJOR / skills-consistency — forge-context маршрутизирует в .forge/skills-catalog.yml, который никто никогда не создаёт
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/forge-context/SKILL.md:51

Строка роутинг-таблицы L1: «| Find right skill | skill, workflow | `.forge/skills-catalog.yml` |». Но commands/init.md генерирует map/conventions/status/decisions/dead-ends/journal/learnings/direction/infrastructure.yml — skills-catalog.yml в списке генерации нет (grep по всему репо: файл упоминается только здесь и в docs/context-system.md:83,208,309 как задумка). В каждом реальном проекте Claude при вопросе «какой скилл использовать» пойдёт читать несуществующий файл, получит ошибку и потратит ход. Спека (docs) и реализация (init) разошлись, а скилл ссылается на фантом.

**Как исправить:** Убрать строку из таблицы в forge-context/SKILL.md (выбор скилла — задача using-forge с его таблицей Available Skills, каталог в .forge не нужен) и вычистить skills-catalog.yml из docs/context-system.md. Либо, если каталог нужен, добавить его генерацию в commands/init.md — но первый вариант проще и без дублирования.

**Уточнение верификатора:** Severity слегка завышена: фраза «в каждом реальном проекте Claude пойдёт читать несуществующий файл» — преувеличение. По Step 2 того же SKILL.md роутинг идёт через матчинг тегов catalog[].tags из L0 (index.yml), а init не добавляет запись `skills` в catalog, поэтому через теги Claude на файл не выйдет. Промах случается только когда Claude буквально следует таблице в теле скилла (вероятно, но не гарантированно на каждый вопрос «какой скилл»). Суть находки (фантомная ссылка, расхождение спеки и init) верна.

## [31] MAJOR / ux-nekoder — Critique — единственная фаза без правила «простой язык»: Антону показывают технический синтез и просят принять решение
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/critique/SKILL.md:184-198

Во всех остальных фазах есть явное правило простого языка (new-task: «Простой язык. Объясняешь как первокурснику», plan: «Один вопрос за раз. Простой язык», refine-idea: «Простым языком, как первокурснику, без жаргона»). В critique его НЕТ нигде — grep по «прост/жаргон» находит только промпт персоны User Advocate. При этом шаг 4 велит показать пользователю список находок и спросить «Применить блокеры + важное?», а находки персон по формату технические — эталонный пример в самом скилле (строки 287-289): «не обрабатывает случай когда q пустой… упадёт запрос в БД с непредсказуемым LIKE… Добавить в начало handler-а: if not q…». Антон — не-кодер: он не может оценить такие правки, будет штамповать «ок» не понимая, что одобряет. Плюс output style режет ответы >15 строк, а синтез критики не входит в список исключений (forge-concise.md:33) — при 5+ находках Клод обязан «cut half» ровно в момент, когда человеку нужно решение.

**Как исправить:** В шаг 4 добавить явное правило: каждая находка для пользователя — одна строка простыми русскими словами («что сломается по-человечески → что меняем в плане»), технические детали (код, имена функций) остаются только в файле плана. И добавить «critique synthesis» в список исключений из лимита длины в output-styles/forge-concise.md:33.

**Уточнение верификатора:** Severity чуть смягчается тем, что output style активен всегда (force-for-plugin: true), целиком адресован не-кодеру, и его секция choice-моментов (forge-concise.md:23–28) требует «no jargon» и рекомендацию перед вопросом — вопрос «Применить блокеры + важное?» формально под неё подпадает. Так что полного «нуля» защиты нет. Но проект сам следует конвенции дублировать правило простого языка внутри каждого user-facing скилла (3 из 3 проверенных фаз), а явный технический шаблон и пример находки в самом critique на практике перевесят общую строку стиля. Предложенный фикс соответствует существующим паттернам плагина и не хуже статус-кво.

## [32] MAJOR / ux-nekoder — finishing-a-development-branch: англоязычное меню с git-жаргоном и технический вопрос Антону
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/finishing-a-development-branch/SKILL.md:60,68-77,148-155

Скилл срабатывает на «закрой ветку / всё готово». Short-circuit для однозначного «мержим» сделан хорошо, но при неоднозначном намерении шаблоны для пользователя целиком на английском и в git-терминах: строки 68-77 — «Implementation complete. What would you like to do? 1. Merge back to <base-branch> locally 2. Push and create a Pull Request…»; строка 60 — прямой технический вопрос: «Or ask: "This branch split from main - is that correct?"» (Антон не знает, от чего «split» его ветка — это нарушает hard rule «NO technical questions to Anton»); строки 148-155 — подтверждение удаления требует напечатать английское слово: «Type 'discard' to confirm». Output style требует «Russian unless explicitly switched» и запрещает технические вопросы — Клод получит два противоречащих указания, и по цитируемому шаблону скилла победит английское меню.

**Как исправить:** Перевести все user-facing шаблоны на русский без жаргона: «1. Влить в основную ветку — задача станет частью проекта; 2. Отправить на GitHub как заявку (PR) — если нужно ревью; 3. Оставить как есть; 4. Выбросить эту работу» + рекомендация-дефолт («Я бы за 1»). Вопрос про base branch (строка 60) убрать — определять молча тем же кодом $BASE, что уже есть в execute/SKILL.md:71-75. Подтверждение удаления — русским словом («напиши: удалить»).

**Уточнение верификатора:** Проблема уже, чем «весь скилл»: частый путь закрыт short-circuit (строка 64), а после мержа есть русское подтверждение без жаргона (строки 115-116) и русская обработка конфликтов (строка 113). Английскими остались только меню при неоднозначном намерении, вопрос про base branch, discard-подтверждение и пропущенный находкой репорт Option 3 (строка 141: «Keeping branch <name>. Worktree preserved at <path>.») — его тоже стоит перевести. Дополнительный аргумент за фикс строки 60: автоматическая попытка на строке 57 (git merge-base HEAD main) возвращает хэш коммита, а не выбор ветки, т.е. фолбэк-вопрос будет срабатывать регулярно — замена на код $BASE из execute обязательна, а не косметика.

## [33] MAJOR / ux-nekoder — Plan, шаг 8: гейт «ОК» для не-кодера — это два числа и файл, полный кода
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/plan/SKILL.md:238-243

Шаблон показа плана: «План готов: N шагов, M чекпоинтов. Лежит в .forge/plans/... Открой посмотри. Если ОК — запускаю критику». При этом сам скилл обязывает класть в шаги inline-код («Концентрированный код… пиши код в шаге», строки 166-169) — то есть единственный способ для Антона проверить план перед «ОК» — открыть markdown с Python-сниппетами, которые он не читает. Формат «сводки» нигде не определён (сказано только «Покажи сводку плана»), так что Клод честно покажет два числа. Не-кодер либо штампует «ОК» вслепую, либо застревает — это ровно тот провал чекпоинта, о котором сам plan предупреждает на строке 189 («приучает пользователя проштамповывать ОК не глядя»).

**Как исправить:** Определить формат сводки явно: нумерованный список шагов по одной строке простыми русскими словами (без кода и путей), метки чекпоинтов («после шага 4 — пауза, покажу работающий поиск»), открытые вопросы. «Открой посмотри» заменить на «полная версия с деталями лежит в … — открывать не обязательно». Вопрос «ОК?» задавать по этой сводке, а не по файлу.

**Уточнение верификатора:** Утверждение «Клод честно покажет два числа» — худший случай, а не гарантированный: строка 243 отдельно требует «Покажи сводку плана», а output-styles/forge-concise.md:33 явно исключает «plan summaries» из лимита длины, так что на практике Клод скорее покажет и заголовки шагов. Но заголовки шагов по обязательному формату технические («Добавить эндпоинт GET /notes/search», пути файлов), а формат сводки не определён — так что суть проблемы (не-кодер не может осмысленно дать «ОК» без чтения кода) остаётся. Предложение ревью (определить формат сводки простыми словами + «открывать не обязательно») лучше статус-кво.

## [34] MAJOR / ux-nekoder — Execute: чекпоинт не требует, чтобы Клод сам прогнал проверку — Антону предлагают curl «если хочешь сам»
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/execute/SKILL.md:141-154

Формат чекпоинта: «Что сделано: … Как проверить (если хочешь сам): `curl localhost:8000/notes/search?q=test` … Окей продолжать?». Для голосового не-кодера curl — недоступный способ проверки, а требования, чтобы Клод ВЫПОЛНИЛ проверку до показа чекпоинта и процитировал результат, в шаге 4 нет (доказательства обязательны только в финале, шаг 6, строки 172-177). Итог: промежуточные чекпоинты — главный механизм контроля пайплайна — вырождаются в «ок не глядя», и ошибка едет до финального отчёта, где чинить дороже. То же в шаблоне чекпоинта плана (plan/SKILL.md:191-203: «Что показываем: curl … возвращает JSON»).

**Как исправить:** В шаг 4 добавить обязательную строку чекпоинта: «Проверил: [команда] → [результат простыми словами]» — Клод сам запускает проверку из плана до показа. Блок «если хочешь сам» оставить, но для user-facing фич предлагать человеко-наблюдаемый способ (открыть страницу/HTML, скриншот), а не сырой curl.

**Уточнение верификатора:** Небольшое смягчение: в плагине есть отдельный скилл verification-before-completion, чей триггер («BEFORE saying 'готово', 'работает'») формально покрывает и заголовок чекпоинта «X готов» — т.е. полного вакуума нет. Но защита ненадёжная: execute/SKILL.md его не упоминает, а явный шаблон чекпоинта с «если хочешь сам» активно подсказывает противоположное поведение, и конкретный шаблон в активном скилле обычно побеждает общий гардрейл. Фиксить стоит и шаблон в execute (строка «Проверил: …»), и шаблон чекпоинта в plan/SKILL.md:191-203 (например «Что показываем: [команда] → [реальный вывод], прогоняет Клод»), плюс можно добавить в шаг 4 явную отсылку к verification-before-completion.

## [35] MINOR / commands — COMMANDS.md разъехался со скиллами в 4 местах: hookify, session-insights, init, graph
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/COMMANDS.md:96-97,553,656,684

(а) Строка 684: hookify-правило «активным со следующей сессии», а skills/hookify/SKILL.md:81 говорит обратное: «PreToolUse-хук подхватит его на следующем вызове Edit/Write — restart не нужен» (hooks/user-rules-check.sh читает правила live). (б) Строка 656: session-insights «Анализирует историю сессий из .forge/journal.yml» — на деле команда/скилл читают JSONL-логи диалогов (commands/session-insights.md:20: «Extracting user messages from JSONL conversation logs»). (в) Строки 96-97: init «создаёт product.yml — контекст продукта, tech.yml — технический контекст» — init.md эти файлы нигде не создаёт (создаёт map/conventions/status/decisions/dead-ends/journal/direction/infrastructure/structure.md). (г) Строка 553: «--update — инкрементальное обновление (только изменённые файлы)», а commands/graph.md:36 прямо говорит «Both /forge:graph and /forge:graph --update do the same thing». Пользователь получает неверные ожидания, а при правках скиллов дрейф только растёт.

**Как исправить:** Исправить 4 места по фактам из скиллов/команд. Системно: в секциях COMMANDS.md «Что делает» не пересказывать внутренности скилла, а держать 1-2 строки + отсылку «детали — в skills/<имя>/SKILL.md», чтобы был один источник правды.

**Уточнение верификатора:** Мелкий нюанс по пункту (г): часть фразы COMMANDS.md:553 «без LLM» верна (graph.md это подтверждает), а «инкрементальность» может быть внутренним свойством `graphify update` для ОБОИХ вызовов. Ошибка именно в противопоставлении «полная сборка с нуля» (строка 552) vs «инкрементальное обновление» (553) — по graph.md разницы между режимами нет, --update просто алиас.

## [36] MINOR / commands — Ни одна из 25 команд не имеет argument-hint, хотя минимум 6 принимают аргументы
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/commands/graph.md:26-32

grep -l 'argument-hint' commands/*.md → NONE (и $ARGUMENTS нигде не используется). При этом graph.md парсит режимы «--query "question" / --path "A" "B" / --explain "Node"» (строки 26-32), explain ожидает вопрос («/forge:explain "как работает авторизация?"» — пример из COMMANDS.md:617), hookify принимает опциональное описание правила, new-task — сырой запрос, investigate — симптом, roadmap — операцию с целями. Для Антона (не-кодер, голосовой ввод) автокомплит без подсказки аргумента — единственное место, где он мог бы увидеть формат вызова; сейчас там пусто.

**Как исправить:** Добавить frontmatter-поле argument-hint как минимум в 6 команд: graph.md → `[--query "вопрос" | --path "A" "B" | --explain "узел"]`; explain.md → `"как работает X?"`; hookify.md → `[правило — или пусто для автоанализа сессии]`; new-task.md → `<сырая задача своими словами>`; investigate.md → `<что непонятно / симптом>`; roadmap.md → `[добавь/переименуй/удали цель ...]`.

**Уточнение верификатора:** Формулировка «сейчас там пусто» слегка преувеличена: у graph.md description сам перечисляет флаги («Use --query, --path, --explain for navigation»), а у hookify.md description объясняет поведение с/без аргумента — часть формата в автокомплите видна через description, хоть и не в специализированном поле и в усечённом виде. Severity — низкая (полировка UX, не поломка); предложенный фикс из 6 argument-hint корректен и лучше статус-кво.

## [37] MINOR / commands — roadmap.md: битое слово «переcyдить» (латинские буквы внутри кириллицы) в видимом пользователю description
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/commands/roadmap.md:2

description: «...добавить, переименовать, переcyдить, удалить...» — hexdump подтверждает латинские байты `63 79` (c, y) внутри кириллического слова. Это description, который показывается в автокомплите /help при наборе /forge:roadmap — выглядит как мусор, и непонятно, что имелось в виду (вероятно «перепривязать» — в CLAUDE.md функция roadmap описана как «перепривяжи задачу»). Мелочь, но это витрина команды для не-кодера.

**Как исправить:** Заменить «переcyдить» на «перепривязать задачу к другой цели» (в терминах скилла roadmap: 'не туда привязал', 'перепривяжи') и перечитать description целиком на предмет других смешанных раскладок.

**Уточнение верификатора:** Остальная часть description чистая — проверил скриптом, «переcyдить» единственное слово со смешанной раскладкой, так что дополнительная вычитка не нужна. Для симметрии списка глаголов достаточно короткого «перепривязать» вместо длинной формы «перепривязать задачу к другой цели». Severity оценена верно — мелочь, но реальная витринная опечатка.

## [38] MINOR / dead-weight — Осиротевшие промпты writing-plans.txt и executing-plans.txt от скиллов, переименованных ещё в мае
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/skill-triggering/prompts/writing-plans.txt

В prompts/ лежат writing-plans.txt и executing-plans.txt, но скиллов с такими именами нет (ls skills/ — только plan и execute), и run-all.sh их не запускает (в списке SKILLS их нет). Это остатки миграции 2026-05-13 (.forge/plans/2026-05-13-migrate-to-new-pipeline.md прямо мапит writing-plans → plan, executing-plans → execute) — файлы скиллов удалили, промпты забыли. Вреда мало, но при добавлении новых тестов легко по ошибке сослаться на мёртвый промпт вместо актуального plan.txt/execute.txt.

**Как исправить:** Удалить tests/skill-triggering/prompts/writing-plans.txt и tests/skill-triggering/prompts/executing-plans.txt. Опционально — добавить промпты и строки в run-all.sh для новых фаз: project-unblocker и refine-idea, которых в сьюте нет вообще.

**Уточнение верификатора:** Две мелкие неточности: (1) путь к плану миграции — forge-plugin/.forge/plans/2026-05-13-migrate-to-new-pipeline.md (внутри forge-plugin/.forge/, а не в корневом .forge/ репо); (2) миграция датирована планом 2026-05-13, но сам коммит cee1a6a — 14 мая 2026. Severity в находке заявлена честно низкой ("вреда мало") — не завышена. Отсутствие тестов для project-unblocker и refine-idea тоже подтверждается, но это отдельное расширение сьюта, а не часть проблемы dead weight.

## [39] MINOR / dead-weight — ~1.3 МБ дублей mp3 в ideas/ — байт-в-байт копии файлов из forge-plugin/sounds/, закоммичены в git
**Файл:** /Users/mac/Projects/Plugin/plugin/ideas/razreshenie1.mp3

Все 14 звуковых файлов существуют в двух экземплярах: ideas/*.mp3 и forge-plugin/sounds/{stop,permission}/*.mp3. md5 совпадает побайтно (например razreshenie1.mp3: dab2519e37afce0b2e0e972915d47c63 в обоих местах; ElevenLabs_..._12_04_00_VASKO...: 5ba8ddadca5cd4db4a13ecbef7243401 в обоих). Оба комплекта отслеживаются git (git ls-files подтверждает) — это ~1.3 МБ бинарного балласта в истории репо навсегда плюс путаница, какой комплект канонический. Рабочий комплект — sounds/ (hooks.json ссылается на ${CLAUDE_PLUGIN_ROOT}/sounds/stop и /sounds/permission, файлы на месте — тут всё корректно).

**Как исправить:** Удалить из ideas/ все 14 mp3 (7 razreshenie*.mp3 + 7 ElevenLabs*.mp3) — канонический комплект живёт в forge-plugin/sounds/. Из истории git старые блобы уже не убрать без rewrite, но хотя бы остановить дублирование вперёд.

**Уточнение верификатора:** Механика «~1.3 МБ бинарного балласта в истории навсегда» завышена: git дедуплицирует одинаковые блобы — `git rev-parse` показывает, что HEAD:ideas/razreshenie1.mp3 и HEAD:forge-plugin/sounds/permission/razreshenie1.mp3 указывают на ОДИН блоб (b51e4788…). Объектное хранилище .git от дублей почти не выросло; фраза «из истории блобы не убрать без rewrite» тоже беспредметна — лишних блобов нет. Реальная цена: +1.3 МБ дублей в каждом рабочем чекауте/клоне (checkout, не история) плюс путаница о каноничности. Проблема реальна, но severity — minor housekeeping; предложение удалить ideas/*.mp3 корректно и безопасно.

## [40] MINOR / dead-weight — user-rules-check.sh не покрыт тестами — регрессия парсинга молча отключит все hookify-правила
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/tests/hooks/test-bash-safety.sh

В tests/hooks/ единственный тест — test-bash-safety.sh (4 кейса, запускается и проходит — проверено). Но в v7.4.0 на python3-парсинг JSON переписали ДВА хука: bash-safety.sh и user-rules-check.sh, а тест есть только у первого. user-rules-check.sh — механизм enforcement всех правил hookify (.forge/hookrules/*.md, matcher/warn/block из frontmatter): если его парсинг правил или JSON сломается, хук просто перестанет срабатывать, и никто этого не заметит — правила тихо умрут, а Антон будет думать, что они защищают.

**Как исправить:** Добавить tests/hooks/test-user-rules-check.sh по образцу test-bash-safety.sh: во временной директории создать .forge/hookrules/test-rule.md с matcher и action: block, подать хук-у JSON-payload с командой под matcher и проверить exit 2; затем payload мимо matcher'а — exit 0; и кейс с битым frontmatter — хук не должен падать.

**Уточнение верификатора:** Находка даже занижена: предложенный кейс «битый frontmatter — хук не должен падать» уже сегодня провалится. Из-за set -euo pipefail один малформленный файл в .forge/hookrules/ роняет хук с exit 1 и отключает ВСЕ остальные правила (exit 1 — non-blocking, tool call проходит). Поэтому тест нужно добавлять вместе с фиксом (|| true на grep-пайплайны frontmatter, строки 39-42 user-rules-check.sh). Мелкое уточнение: смерть «полностью тихая» только для JSON-парсинга (|| true глотает всё); при битом frontmatter stderr хука с exit 1 попадает в транскрипт, но блокировка всё равно не срабатывает.

## [41] MINOR / docs-reality — docs/Forge spec v2.md и plugin-improvement-proposals.md заморожены на 4-фазной эпохе без пометки «исторические»
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/docs/Forge spec v2.md:194 (и docs/plugin-improvement-proposals.md:4)

«Финальная спецификация v2» предписывает: «For any non-trivial request, route through the 4-phase pipeline», в структуре — только 6 команд (new-task/plan/critique/execute/sync/init) против реальных 25, нет output-styles/, evals/, statusline, github-sync, roadmap. plugin-improvement-proposals.md: «Last review: 2026-05-13 — re-evaluated against new 4-phase pipeline». Ни в одном нет маркера актуальности — читаются как действующая спецификация и противоречат CLAUDE.md.

**Как исправить:** Добавить в шапку обоих файлов явный статус: «Исторический документ, отражает v7.1 (4 фазы). Актуальная архитектура — CLAUDE.md». Либо перенести в docs/archive/. Полную переписку спеки делать не обязательно — важно снять статус «финальная».

**Уточнение верификатора:** Небольшое уточнение: plugin-improvement-proposals.md не читается как «действующая спецификация» — в его шапке явно стоит «Status: Draft — awaiting prioritization», а одна секция (строка 202) даже помечена «Kept for historical reference». Для него проблема — протухшие статусы предложений (уже реализованные скиллы значатся как pending), а не ложная авторитетность. Претензия «читается как действующая спецификация» в полной мере относится только к «Forge spec v2.md». Предложенный фикс (маркер в шапке или перенос в docs/archive/) дешёвый и адекватный, severity не завышена.

## [42] MINOR / docs-reality — Мелкие рассинхроны счётчиков: README обещает 6 фаз, а показывает 5; CLAUDE.md перечисляет 17 команд из 25
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/README.md:3,11-17

README.md:3 — «6-фазный пайплайн», но таблица фаз (строки 11-17) содержит только 5 строк: new-task, refine-idea, plan, critique, execute — Phase 0 (unblocker) из «фазовой» таблицы выпал и упомянут лишь как «полезная команда, если застрял». В CLAUDE.md таблица «Commands Reference» перечисляет 17 команд, тогда как в commands/ их 25 — не упомянуты init, design, deploy, migrate, api-design, security-review, hookify, evolve (при этом init и hookify описаны в других местах CLAUDE.md). «~30 скиллов» при фактических 33 — терпимо из-за тильды, но при следующем правеже стоит заодно уточнить.

**Как исправить:** Добавить строку «🧭 unblocker — Phase 0» в таблицу README (тогда 6 заявленных фаз = 6 строк). В CLAUDE.md либо дописать 8 недостающих команд в таблицу, либо явно озаглавить её «основные команды (полный список — COMMANDS.md)».

**Уточнение верификатора:** Две неточности в деталях: (1) утверждение «init и hookify описаны в других местах CLAUDE.md» неверно — ни одна из 8 команд в CLAUDE.md не упоминается вообще; (2) «~30 скиллов» — формулировка CLAUDE.md, в README стоит «30+ скиллов» (строка 31), при 33 фактических обе корректны. Дополнение к предложению: COMMANDS.md существует (forge-plugin/COMMANDS.md) и покрывает все команды, так что ссылка «полный список — COMMANDS.md» реализуема, но сам COMMANDS.md называет пайплайн «4-фазным» (заголовок «Сердце плагина: 4-фазный pipeline») — третий рассинхрон счётчика фаз, стоит поправить той же правкой.

## [43] MINOR / hooks — context-inject: двойное экранирование — Claude получает литеральные `\n` вместо переводов строк в каждом промпте
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/hooks/context-inject.sh:49

В строке 49 `context="FORGE L0 CONTEXT (auto-injected):\n\n${index_content}..."` последовательности `\n` — это литеральные два символа (в bash внутри двойных кавычек `\n` не интерпретируется). Затем `escape_for_json` (строка 41: `s="${s//\\/\\\\}"`) удваивает бэкслеш → в JSON уходит `\\n` → после декодирования Claude видит текст `FORGE L0 CONTEXT (auto-injected):\n\nproject: ...` с мусорными `\n` между всеми секциями. Проверено запуском хука: repr декодированного additionalContext показывает `'...(auto-injected):\\n\\nproject...'`. Тот же баг в graph_hint (стр. 35), truncate_note (стр. 15) и в session-start.sh:12 (warning). Работает, но структура инжектируемого блока поломана в каждом промпте + лишние токены.

**Как исправить:** Использовать ANSI-C кавычки для переводов строк: `context="FORGE L0 CONTEXT (auto-injected):"$'\n\n'"${index_content}"$'\n\n'"--- Branch: ..."` (и так же в truncate_note, graph_hint, session-start.sh warning) — тогда escape_for_json корректно превратит настоящие \n-символы в JSON-эскейпы. Заодно заменить `head -c 2500` на `head -c 2500 | iconv -f UTF-8 -t UTF-8 -c` (или python3-обрезку по символам), чтобы байтовая обрезка кириллического index.yml не рождала битый UTF-8 в JSON.

**Уточнение верификатора:** Severity умеренная, и находка сама это оговаривает: JSON валиден, хук не падает, ломаются только 4-6 разделителей секций на промпт (содержимое файла проходит с настоящими newlines) — мусор и лишние токены, не функциональная поломка. Вторая часть предложения (UTF-8 обрезка через head -c 2500) — латентный риск, не наблюдаемый баг: текущий index.yml весит 2130 байт < 2500, обрезка не срабатывает и мультибайтовый символ на границе не режется. В session-start.sh warning проявляется только при наличии legacy-папки ~/.config/forge/skills, а graph_hint — только при установленном graphify.

## [44] MINOR / hooks — statusline: разделитель " | " не работает — bash берёт только первый символ IFS
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/hooks/statusline.sh:45

`IFS=" | "` + `"${parts[*]}"` — bash соединяет элементы массива ПЕРВЫМ символом IFS, т.е. одним пробелом. Проверено: `parts=(Fable "🎯 Phase 1" 🌿master 42%)` даёт `Fable 🎯 Phase 1 🌿master 42%` вместо `Fable | 🎯 Phase 1 | 🌿master | 42%`. Задуманные разделители не рендерятся никогда — статусная строка сливается в кашу, особенно с task в кавычках. Вдобавок `head -c 30`/`head -c 35` (строки 20-21) режут русские phase/task по байтам — кириллица 2 байта/символ, высокая вероятность оборванного символа `�` на конце.

**Как исправить:** Заменить IFS-трюк на явный join: `out=""; for p in "${parts[@]}"; do out="${out:+$out | }$p"; done; printf '%s\n' "$out"`. Байтовую обрезку заменить на `awk '{print substr($0,1,30)}'` или `cut -c1-30` (символьная, не байтовая) — task у Антона всегда на русском.

**Уточнение верификатора:** Две поправки. 1) Вес второй части («task всегда на русском») завышен: phase/task в .forge/state.yml пишутся скиллами как ASCII-значения и kebab-case слаги (`phase: plan`, `task: <slug>`), кириллица там — краевой случай, а не норма; основной баг — именно IFS-join. 2) Предложенный фикс через `awk substr` НЕ работает на macOS: BSD awk считает substr по байтам (проверено — вернул 15 байт вместо 15 символов). Рабочая замена — `cut -c1-30` (посимвольная в UTF-8 локали, проверено). Фикс разделителя через явный цикл-join — корректен.

## [45] MINOR / hooks — bash-safety и user-rules-check: fail-open при недоступном python3 — защита молча отключается
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/hooks/bash-safety.sh:14

`cmd=$(... python3 -c "..." 2>/dev/null || true)` — если python3 отсутствует/сломан (свежий macOS без Command Line Tools: вызов python3 падает с ошибкой и предложением установить CLT), `cmd` становится пустым и строка 17 `[ -z "$cmd" ] && exit 0` пропускает ЛЮБУЮ команду. Хук безопасности деградирует в «разрешить всё» без единого сигнала пользователю. Та же схема в user-rules-check.sh:24-27 — все hookify-правила (включая action: block) молча перестают работать.

**Как исправить:** Отличать «поля нет» от «парсер сдох»: `if ! command -v python3 >/dev/null 2>&1; then echo 'forge bash-safety: python3 не найден, проверка команд отключена' >&2; exit 0; fi` — предупреждение хотя бы всплывёт в логах хука. В user-rules-check дополнительно: раз правила пользователь создавал осознанно (action: block), при недоступном парсере честнее выдать warn через additionalContext, чем молча no-op.

**Уточнение верификатора:** Severity адекватна (silent degradation защиты, а не дыра — fail-open сам по себе разумный дефолт, fail-closed заблокировал бы весь Bash). Но предложенный фикс `command -v python3` НЕ ловит именно тот сценарий, который приводится в находке: на свежем macOS без CLT заглушка /usr/bin/python3 существует (command -v успешен), а падает только при исполнении. Нужно проверять реальное выполнение: либо разово `python3 -c 'pass' 2>/dev/null`, либо отличать «парсер упал» от «поля нет» по exit-коду парсинга. Также предупреждение в stderr при exit 0 до Claude не доходит (это признаёт комментарий в user-rules-check.sh:54) — попадёт только в debug-логи; реальный сигнал надо отдавать через JSON stdout (permissionDecisionReason/additionalContext), как хук уже делает для warn-правил.

## [46] MINOR / hooks — hooks.json: timeout 5s режет стоп-звук длиной 6.1s
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/hooks/hooks.json:55

У Stop-хука `"timeout": 5` (секунд), а замер afinfo показал: один из mp3 в sounds/stop/ длится 6.086s (`ElevenLabs_..._12_05_24_VASKO...mp3`), остальные 2.6-4.5s. Это голосовые фразы — при выпадении этого файла в `sort -R` afplay будет убит на полуслове в ~1 случае из 7. Мелко, но заметно на слух каждый раз.

**Как исправить:** Поднять timeout до 10 в обоих звуковых хуках (строки 55 и 68) — они и так `async: true`, на пайплайн не влияют. Либо обрезать длинный mp3 до <5s.

**Уточнение верификатора:** Уточнение по строке 68 (PermissionRequest): все 7 mp3 в sounds/permission/ длятся 2.64–4.55s, т.е. там сейчас ничего не режется — поднятие timeout там чисто превентивное, а не фикс бага. Реально ломается только Stop-хук (строка 55). Предложение поднять до 10 безопасно (оба хука async: true). Оговорка: сам факт kill по timeout — поведение харнесса Claude Code, из файлов репо не проверяем, но это документированная семантика поля timeout.

## [47] MINOR / hooks — user-rules-check: NotebookEdit заявлен в matcher, но правила к нему никогда не применяются
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/hooks/hooks.json:38

Matcher `"Bash|Edit|Write|NotebookEdit"` включает NotebookEdit, но user-rules-check.sh:29-31 извлекает только `command`/`new_string`/`content`. У NotebookEdit контент лежит в `new_source` → tool_content пуст → строка 33 `exit 0`. Любое hookify-правило (даже с action: block) для правок ноутбуков молча не срабатывает, хотя конфиг обещает обратное. Плюс мелочь там же: хук спавнит python3 до 3 раз подряд (строки 29-31) на каждый tool call при наличии .forge/hookrules — можно одним вызовом.

**Как исправить:** Добавить `[ -z "$tool_content" ] && tool_content=$(tool_input_field new_source)` после строки 31 — либо убрать NotebookEdit из matcher в hooks.json, чтобы конфиг не врал. Три python3-вызова схлопнуть в один: `print(ti.get('command') or ti.get('new_string') or ti.get('content') or ti.get('new_source') or '')`.

**Уточнение верификатора:** Severity умеренная, не высокая: плагин заточен под не-кодера с bash/markdown/JS-проектами, Jupyter-ноутбуки в этом воркфлоу редки, так что дыра реальна, но почти не эксплуатируется на практике. Часть про 3 вызова python3 — валидная микрооптимизация, но не проблема: хук рано выходит при отсутствии .forge/hookrules, накладные расходы есть только у пользователей с правилами. Оба предложенных фикса корректны; проще всего добавить fallback на new_source (одна строка), это честнее, чем урезать matcher.

## [48] MINOR / manifest — Фиктивный автор "Forge Contributors" и почта на чужом домене noreply@forge.dev
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/.claude-plugin/plugin.json:5-8

author в plugin.json: "Forge Contributors" <noreply@forge.dev> — вымышленная организация и адрес на домене forge.dev, который проекту не принадлежит (это чужой действующий домен). Тот же noreply@forge.dev продублирован в owner и author корневого marketplace.json (строки 6, 16). Пользователю некуда написать, а указание чужого домена в контактах — плохая практика дистрибуции (письма могут уходить реальному владельцу домена).

**Как исправить:** Указать реального мейнтейнера во всех трёх местах: например "author": {"name": "Anton", "url": "https://github.com/anton-ai5010"} — поле email опустить или поставить реальный адрес; главное — убрать чужой домен forge.dev.

**Уточнение верификатора:** Два уточнения. (1) В корневом marketplace.json имя уже "Anton" — фиктивно там только email; вымышленная организация "Forge Contributors" есть лишь в plugin.json. (2) Проблема шире находки: в plugin.json поля homepage и repository указывают на https://github.com/obra/forge (чужой upstream-репозиторий вместо anton-ai5010/forge), а вложенный forge-plugin/.claude-plugin/marketplace.json до сих пор указывает автором "Jesse Vincent" <jesse@fsck.com> — остатки метаданных форка. Чинить стоит все пять мест разом.

## [49] MINOR / manifest — description и keywords не отражают реальный функционал — остались от форка
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/.claude-plugin/plugin.json:3,12

keywords: ["skills", "tdd", "debugging", "collaboration", "best-practices", "workflows"] — это набор оригинального плагина-родителя. Главные отличительные фичи ЭТОГО плагина нигде не упомянуты: 6-фазный pipeline (unblocker → new-task → refine-idea → plan → critique → execute), русскоязычные триггеры, ориентация на не-кодера, GitHub-sync, L0/L1/L2 контекст. description ("Project knowledge layer and workflow automation...") тоже общий. В поиске marketplace плагин не найдут по его реальным сильным сторонам, а найдут по чужим.

**Как исправить:** Переписать keywords под реальность: ["pipeline", "planning", "context-management", "russian", "non-coder", "github-sync", "workflows", "tdd"] и дополнить description упоминанием 6-фазного pipeline и русскоязычной поддержки. Синхронно обновить описание записи плагина в корневом marketplace.json.

**Уточнение верификатора:** Две поправки. (1) Про description находка перегибает: текст "Project knowledge layer and workflow automation... context management, and intelligent documentation" не взят у родителя (у superpowers было другое описание) и частично отражает реальность (.forge L0/L1/L2 = knowledge layer, pipeline = workflow automation); его проблема — не "остался от форка", а отсутствие отличительных фич (6-фазный pipeline, русскоязычность, не-кодер). Keywords tdd/debugging/workflows тоже не ложны — такие скиллы в плагине есть; они неполны, а не чужды. (2) Severity низкая: плагин распространяется через личный marketplace (source "./forge-plugin"), публичного поиска, где keywords реально влияют, сейчас нет. Зато стоит расширить фикс: заменить homepage/repository на anton-ai5010/forge, вычистить owner "Jesse Vincent" из forge-plugin/.claude-plugin/marketplace.json и синхронизировать версию в корневом marketplace.json (там 6.2.0 против 7.4.0).

## [50] MINOR / pipeline — finishing проверяет несуществующий .forge/map.json — напоминание про /forge:sync мертво
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/finishing-a-development-branch/SKILL.md:48

Step 1.5 «Update Documentation»: «ls .forge/map.json 2>/dev/null... If FORGE docs exist, suggest running /forge:sync». Но forge пишет `map.yml`, не `map.json` — это подтверждают forge-context/SKILL.md:43 (`.forge/map.yml`), CLAUDE.md (L1: map.yml) и реальная директория .forge/ этого репо (map.yml есть, map.json нет). Проверка всегда пуста → предложение обновить доки перед мержем никогда не срабатывает → .forge-память после каждого мержа отстаёт от кода, хотя сам скилл декларирует «A missing doc means the next developer repeats your mistakes».

**Как исправить:** Заменить проверку на `ls .forge/index.yml 2>/dev/null` (index.yml — единственный гарантированный файл L0) или хотя бы `.forge/map.yml`. Однострочная правка.

**Уточнение верификатора:** Severity чуть завышена: скилл исполняет LLM, а не bash, и хук context-inject.sh инжектит L0-контекст в каждый промпт, поэтому Claude часто и так знает о существовании .forge/ и может предложить /forge:sync вопреки пустому ls — шаг деградирован, но не гарантированно мёртв. Правку лучше делать не на index.yml, а по образцу уже существующего паттерна в commands/validate.md:14 — `ls .forge/map.yml .forge/map.json 2>/dev/null` (сохраняет легаси-совместимость и консистентность внутри плагина); вариант с index.yml тоже рабочий.

## [51] MINOR / pipeline — execute и finishing определяют базовую ветку разными и несовместимыми способами
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/finishing-a-development-branch/SKILL.md:55-60

execute (SKILL.md:71-75) определяет базу надёжно: `git symbolic-ref refs/remotes/origin/HEAD` с fallback main→master. finishing Step 2 — «git merge-base HEAD main 2>/dev/null || git merge-base HEAD master» — команда возвращает SHA общего предка, а не имя ветки, и «успешна» для main всякий раз, когда main просто существует, даже если execute ветвился от master. В репо, где есть обе ветки (частый случай после переименования default), finishing вольёт работу не туда, откуда её отвёл execute. Fallback-вопрос «This branch split from main - is that correct?» — git-жаргон на английском тому самому не-кодеру, которого execute бережёт от слов «ветка» и «master».

**Как исправить:** Скопировать в finishing Step 2 сниппет определения BASE из execute шага 1.5 (symbolic-ref origin/HEAD → main → master) — тогда обе стороны git-модели гарантированно говорят об одной ветке, и вопрос пользователю не нужен вовсе.

**Уточнение верификатора:** Два уточнения. (1) Направление опасного сценария обратное примеру ревьювера: после типового переименования default master→main (origin/HEAD → main) оба метода согласны на main; расходятся они когда default = master, а локально болтается лишняя main (execute → master через origin/HEAD, finishing → main) — именно конфигурация репозиториев Антона, так что суть и severity верны. (2) Сниппет Step 2 сам по себе не «выбирает main детерминированно» — он печатает SHA и дальше интерпретируется LLM, то есть строго говоря он недоопределён, а не гарантированно-неверен; но при буквальном прочтении («какая команда прошла — та и база») даёт main при наличии обеих веток, плюс провоцирует fallback-вопрос с английским git-жаргоном.

## [52] MINOR / skills-consistency — problem-investigation тащит в поставку плагина мусор от eval-прогонов skill-creator (23 файла)
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/problem-investigation/problem-investigation-workspace/

В директории скилла лежат evals/evals.json и problem-investigation-workspace/iteration-1/ с тремя сценариями (eval-flaky-tests, eval-module-not-found, eval-silent-form-failure), каждый с eval_metadata.json, grading.json, timing.json и outputs/response.md — итого 23 файла рабочих артефактов тестового прогона. SKILL.md не ссылается ни на один из них (grep 'eval' по SKILL.md — пусто). Это осиротевший отладочный workspace, который уезжает в каждую установку плагина; ни один другой скилл таких артефактов не хранит (тесты живут в forge-plugin/tests/ и forge-plugin/evals/).

**Как исправить:** Удалить skills/problem-investigation/problem-investigation-workspace/ целиком; evals/evals.json либо удалить, либо перенести в forge-plugin/evals/ рядом с остальным eval-сетапом.

**Уточнение верификатора:** Мусора 22 файла, а не 23: 21 в workspace + evals.json; цифра 23 — это все файлы директории скилла вместе с самим SKILL.md. Severity низкая — на работу скилла файлы не влияют (SKILL.md их не подключает), это чисто гигиена репо и поставки, а не функциональный баг. Предложение ревью корректно и не хуже статус-кво.

## [53] MINOR / skills-consistency — ui-ux-design: 212KB осиротевших китайских CSV (design.csv, draft.csv), которые движок не читает
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/ui-ux-design/data/draft.csv:1

design.csv (106KB) и draft.csv (106KB) не упомянуты ни в SKILL.md, ни в CSV_CONFIG/STACK_CONFIG в scripts/core.py, ни в design_system.py (тот использует только ui-reasoning.csv). draft.csv сам честно признаётся в первой строке: «# NOTE: 此文件仅作为设计备份/参考文档，当前搜索引擎与 CLI 不会读取或执行本文件内容» («файл — только бэкап/референс, поисковый движок и CLI его не читают»). Контент — китайскоязычные описания стилей, дублирующие styles.csv. Мёртвый вес в каждой установке плагина, вводит в заблуждение при аудите данных скилла.

**Как исправить:** Удалить data/design.csv и data/draft.csv (ui-reasoning.csv оставить — он используется design_system.py). Если бэкап дорог — вынести за пределы forge-plugin/, например в ideas/.

**Уточнение верификатора:** Уточнения: (1) draft.csv и design.csv — не два разных файла, а байтово-идентичные копии (draft = design + NOTE-заголовок), т.е. контент задублирован дважды; (2) контент смешанный — китайские описания + английские <design-system> блоки, а не чисто китайский; (3) «дублирует styles.csv» — тематически (те же стили), не дословно; (4) severity низкая — гигиена/мёртвый вес ~208KB, ничего не ломает (используемый google-fonts.csv весит 728KB).

## [54] MINOR / skills-consistency — Разнобой в имени инструмента субагентов: «Agent tool» против «Task tool»
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/critique/SKILL.md:44

critique/SKILL.md:44,169 («запусти 4 субагента через Agent tool»), execute/SKILL.md:113,122 и session-insights/SKILL.md:141 называют инструмент «Agent tool», тогда как requesting-code-review/SKILL.md:37 («Use Task tool with forge:code-reviewer type») и subagent-driven-development/implementer-prompt.md:30 («Task tool (general-purpose)») — «Task tool». В Claude Code инструмент диспатча субагентов называется Task; несуществующее имя «Agent tool» в трёх скиллах может заставить модель искать инструмент, которого нет в списке, и деградировать в последовательное выполнение вместо параллельного.

**Как исправить:** Привести к одному каноническому имени «Task tool» во всех пяти местах: critique/SKILL.md:44,169, execute/SKILL.md:113,122, session-insights/SKILL.md:141.

**Уточнение верификатора:** Два уточнения. 1) Список мест для правки неполный: «Agent tool (general-purpose):» также встречается в commands/sync.md:78 и :109 — итого 7 мест, а не 5. 2) Severity слегка завышена: модель почти наверняка смапит «Agent tool» на Task, потому что описание Task начинается с «Launch a new agent...» и конкурирующего инструмента нет; деградация в последовательное выполнение — гипотетический, а не наблюдаемый сбой. Тем не менее унификация на «Task tool» тривиальна и строго лучше статус-кво.

## [55] MINOR / skills-consistency — github-sync приписывает forge-context интеграцию с sync.sh, которой в forge-context нет
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/github-sync/SKILL.md:14

Строка 14: «Существующие скиллы (new-task / plan / critique / execute / forge-context) добавляют в свой процесс однострочный вызов bash $CLAUDE_PLUGIN_ROOT/skills/github-sync/sync.sh». Но в forge-context/SKILL.md нет ни одного упоминания sync.sh/github (grep пустой). Собственная таблица «Когда вызывается» ниже (строки 18-26) forge-context не содержит — там правильно указаны roadmap и forge:start (inline gh в commands/start.md). Claude, читающий скилл, может пойти искать в forge-context несуществующую процедуру синка.

**Как исправить:** В строке 14 заменить перечисление на актуальное: «(new-task / plan / critique / execute / roadmap)» — в точном соответствии с таблицей «Когда вызывается» ниже.

**Уточнение верификатора:** Предложение верно: список в строке 14 должен быть «(new-task / plan / critique / execute / roadmap)». Мелкое уточнение: у new-task вызов не буквально «однострочный bash sync.sh» в его SKILL.md, а ссылка на процедуру github-sync — но это не меняет сути правки. Severity низкая: таблица строками ниже даёт правильную картину, поэтому реальный вред ограничен, но фактическая ошибка есть.

## [56] MINOR / skills-consistency — hookify: лишний «EOF» внутри шаблона правила — уедет в файл при копировании
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/hookify/SKILL.md:76

В примере формата файла правила (кодовый блок «Формат файла», строки 54-77) последней строкой перед закрывающим ``` стоит осиротевший «EOF» — остаток heredoc-а, которым пример когда-то писали. Claude, копируя шаблон дословно (а скилл говорит «Формат файла:»), запишет литеральную строку EOF в каждый .forge/hookrules/<slug>.md. Хук парсит только frontmatter, так что правило работать будет, но мусорная строка размножится по всем правилам пользователя.

**Как исправить:** Удалить строку 76 («EOF») из кодового блока шаблона.

**Уточнение верификатора:** Severity корректно низкая: функциональность правил не страдает (хук читает только frontmatter), вред — только мусорная строка в сгенерированных .forge/hookrules/*.md, и то лишь если Claude скопирует шаблон дословно (вероятно, но не гарантировано). Предложенный фикс — удалить строку 76 — тривиален и безопасен.

## [57] MINOR / skills-consistency — using-forge и github-sync нарушают собственное правило репо: description обязан начинаться с «Use when»
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/using-forge/SKILL.md:3

Правило репо .claude/rules/skills.md: «SKILL.md must have YAML frontmatter: name (kebab-case), description (max 1024 chars, starts with "Use when")». 31 из 33 скиллов соблюдают, но using-forge начинается с «Meta-introduction skill that teaches Claude HOW to operate…», а github-sync/SKILL.md:3 — с «Internal skill — invoked automatically…». Формулировка без «Use when» ещё и хуже триггерится: модель по description решает, когда инвокать скилл, а тут условие использования спрятано в середину текста.

**Как исправить:** Переформулировать оба description с сохранением смысла: «Use when Claude is unsure which forge skill applies or the user asks 'what is forge'…» и «Use when a forge pipeline skill (new-task/plan/critique/execute) instructs to mirror state to GitHub — internal, NOT for manual use…». Либо, если исключения осознанные, зафиксировать их прямо в .claude/rules/skills.md.

**Уточнение верификатора:** Находка верна, но severity низкая, и предложенный фикс годится не для обоих случаев. (1) using-forge: триггерные условия в description есть, просто спрятаны в середину («Use when user asks 'what is forge'…»), так что тезис «хуже триггерится» — правдоподобная гипотеза, а не доказанный факт; перестановка «Use when» в начало — безопасная правка. (2) github-sync: опенер «Internal skill — invoked automatically… NOT for manual use» выглядит намеренно анти-триггерным — скилл в основном вызывается не через Skill tool, а напрямую скриптом (execute/plan зовут `bash $CLAUDE_PLUGIN_ROOT/skills/github-sync/sync.sh …`, см. execute/SKILL.md:129,200; только new-task:98 читает его как скилл). Переписать его на «Use when…» может УХУДШИТЬ поведение (повысить шанс ручного срабатывания); для него правильный фикс — второй вариант из находки: зафиксировать исключение для internal-скиллов в .claude/rules/skills.md. (3) Педантично: «Use proactively when»/«Use during»/«Use ONLY when» у других скиллов тоже не буквально «Use when» — правило в репо соблюдается по духу (начинается с «Use» + условие), и именно по этому стандарту нарушают ровно два флагнутых скилла.

## [58] MINOR / ux-nekoder — «Announce at start» в 4 скиллах противоречит output style (no preamble) и светит жаргон-имена скиллов
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/explaining/SKILL.md:12

forge-concise.md:14,51 запрещает преамбулы («No preamble… Don't say "I will now..." then do it — just do it»), но четыре скилла требуют обратного: explaining:12 «Я использую скилл explaining для визуального объяснения», product-mapping:12 «Я использую скилл product-mapping…», finishing-a-development-branch:17 и using-git-worktrees:17 — вообще по-английски («I'm using the finishing-a-development-branch skill to complete this work»). Для Антона «скилл product-mapping» — жаргон, а английская фраза посреди русского диалога — шум; для Клода — прямой конфликт инструкций.

**Как исправить:** Убрать «Announce at start» или заменить на action-first русскую фразу без имени скилла: «Собираю визуальное объяснение — будет HTML-страница», «Завершаю работу над задачей: проверяю тесты и вливаю в проект» (по образцу session-insights:12, где сделано правильно).

**Уточнение верификатора:** Находка неполная: announce — не случайный остаток, а осознанный протокол плагина, зафиксированный ещё в двух местах, которые ревью не заметило. using-forge/SKILL.md:37,51 предписывает в digraph «Announce: 'Using [skill] to [purpose]'» для КАЖДОГО скилла, а writing-skills/persuasion-principles.md:45 требует «you MUST announce: "I'm using [Skill Name]"». Плюс английский announce продублирован в примерах диалогов: using-git-worktrees/SKILL.md:184 и subagent-driven-development/SKILL.md:112. Если править только 4 строки «Announce at start», конфликт останется — using-forge продолжит требовать имя скилла в announce. Правильный фикс: заменить фразы на action-first русские по образцу session-insights:12 И одновременно обновить формулировку в using-forge:37,51 (например «Announce: действие по-русски без имени скилла»), persuasion-principles.md:45 и примеры диалогов. Полностью убирать announce не стоит — он даёт наблюдаемый след, что скилл сработал (полезно для отладки триггеров).

## [59] MINOR / ux-nekoder — using-git-worktrees задаёт Антону технический вопрос «где создавать worktrees» на английском
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/using-git-worktrees/SKILL.md:41-52

Шаг «3. Ask User»: «No worktree directory found. Where should I create worktrees? 1. .worktrees/ (project-local, hidden) 2. ~/.config/forge/worktrees/<project-name>/ … Which would you prefer?». Это выбор пути на диске — ровно то, что output style (forge-concise.md:18) велит решать молча («If you can decide yourself (file name…) — decide silently and act»), и то, что hard rules запрещают спрашивать у не-кодера. Антон не сможет осознанно выбрать между hidden-папкой и ~/.config.

**Как исправить:** Убрать вопрос: по умолчанию молча создавать .worktrees/ в проекте (с проверкой .gitignore, которая в скилле уже есть) и сообщать одной русской строкой «Отдельную рабочую копию сделал в .worktrees/…». Вопрос оставить только если в CLAUDE.md явное противоречие.

**Уточнение верификатора:** Небольшое уточнение severity: вопрос срабатывает только на первом использовании worktree в проекте — шаги 1-2 (существующая директория / преференс в CLAUDE.md) его гасят. Но для Антона в свежем проекте это как раз типовой путь, так что проблема реальна, просто одноразовая per-проект. Предложение ревью корректно и лучше статус-кво: молчаливый дефолт .worktrees/ ничего не теряет — gitignore-проверка в скилле уже есть (строки 60-72), а глобальная локация остаётся доступной через уже существующий шаг 2 (преференс в CLAUDE.md). При фиксе надо править не только блок 41-52, но и Quick Reference (строка 154 «Neither exists | Check CLAUDE.md → Ask user») и Red Flags (строки 203, 207), иначе останутся противоречащие инструкции внутри одного скилла.

## [60] MINOR / ux-nekoder — Statusline показывает фазы по-английски, а Phase 0 (unblocker) в нём вообще никогда не появляется
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/hooks/statusline.sh:26-34

Единственный постоянно видимый Антону элемент плагина подписан по-английски: «🎯 Phase 1: Understanding», «🔬 Phase 1.5: Idea Check» и т.д. — при правиле «Russian unless explicitly switched». Вдобавок Phase 0 не существует для statusline: в case-маппинге нет ветки для unblocker, и сам project-unblocker/SKILL.md — единственная фаза пайплайна без секции «Process state» (grep state.yml по файлу пуст), т.е. во время навигации статусная строка молчит или показывает хвост прошлой фазы — вводит в заблуждение.

**Как исправить:** Перевести подписи («🎯 Фаза 1: Понимание задачи», «📋 Фаза 2: План», «🚀 Фаза 4: Реализация»), добавить ветку unblocker → «🧭 Фаза 0: Куда двигаться» и вписать в project-unblocker/SKILL.md ту же секцию Process state (запись phase: unblocker в .forge/state.yml), как во всех остальных фазах.

**Уточнение верификатора:** Уточнение механики: в case есть wildcard `*) phase_icon="📌 $phase"` (statusline.sh:33), поэтому корневая причина невидимости Phase 0 — не отсутствие ветки в case (она дала бы хотя бы «📌 unblocker»), а отсутствие секции Process state в project-unblocker/SKILL.md: state.yml во время Phase 0 вообще не пишется. Фикс должен начинаться со скилла, ветка в case — вторично. Бонус: execute при завершении пишет `phase: idle` (execute/SKILL.md:50), которое тоже показывается непереведённым как «📌 idle» — стоит добавить в перевод. Severity адекватна: реальная, но средняя (не поломка, а вводящий в заблуждение индикатор).

## [61] MINOR / ux-nekoder — Финальный отчёт execute заканчивается тремя вопросами разом — против правила «один вопрос за раз»
**Файл:** /Users/mac/Projects/Plugin/plugin/forge-plugin/skills/execute/SKILL.md:192

Шаблон финального отчёта: «Открыть в редакторе? Запустить тесты целиком? Сделать коммит?» — три вопроса одним сообщением, тогда как output style (forge-concise.md:19) требует «One question at a time» и всегда рекомендовать вариант до вопроса. Для голосового не-кодера «Открыть в редакторе?» ещё и мимо кассы — он не работает в редакторе; а «сделать коммит» — жаргон без пояснения. Клод, следуя шаблону дословно, будет каждый раз нарушать стиль ровно в самой важной точке пайплайна.

**Как исправить:** Заменить хвост шаблона на одну рекомендацию с дефолтом в духе стиля: «Я бы сейчас сохранил результат в проект (коммит — снимок изменений). Сохраняем?» — а варианты «прогнать все тесты / посмотреть файлы» предлагать следующим вопросом только после ответа.

**Уточнение верификатора:** Два уточнения: (1) тезис «Антон не работает в редакторе, поэтому "Открыть в редакторе?" мимо кассы» — правдоподобная экстраполяция из «не-кодер», но файлами не подтверждается; (2) предложенная правка корректна, но обязана сохранить вопрос про коммит — SKILL.md:220 прямо требует «Не сворачиваешь автоматически в коммит/push. Спроси пользователя» (вариант «Сохраняем?» с дефолтом это выполняет). Равноценная альтернатива — оформить хвост как 2-3 нумерованных варианта с рекомендацией до вопроса: такой формат стиль явно разрешает для genuine choice (forge-concise.md:23-27).
