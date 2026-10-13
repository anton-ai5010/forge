# Замер: модели и расходы
## До (integration, с 2026-10-12 по 2026-10-13, week.py)
Команда: `/usr/bin/python3 2026-10-12-scripts/week.py --project Ya--Market-integration --since 2026-10-12`
Попавшие папки: только `-Users-mac-Projects-Ya--Market-integration` (папок `-platform` и `-rescue` с данными за период не нашлось).
Примечание: колонка share в BY ROLE считается от всего расхода (включая main и обычных субагентов); «agents» у main = число сессий.

```
TOTAL 2026-10-12 .. now project=Ya--Market-integration ~$636 (API-equivalent)
folders: -Users-mac-Projects-Ya--Market-integration

BY PROJECT
  100.0% $   636 Ya--Market-integration

BY KIND
  91.4% workflow
   7.0% main
   1.6% agent

BY MODEL
  100.0% claude-opus-5-5

TOP SESSIONS (main + their agents merged)
  81.2% $  516 Ya--Market-integration f6a50a6f
  18.8% $  120 Ya--Market-integration 9be57649

BY ROLE (workflow agents)  [доля от расхода после фильтра]
  group                   share       $ agents steps/ag ctx k/step  models
  review                  29.2%     186     48     69.0        178  claude-opus-5-5 100%
  fix                     22.3%     142     27     87.3        215  claude-opus-5-5 100%
  implement               19.3%     123     20     94.3        231  claude-opus-5-5 100%
  final-review            11.2%      71     12     86.7        237  claude-opus-5-5 100%
  main                     7.0%      45      2    118.5        386  claude-opus-5-5 100%
  explore/scout            5.0%      32      7     82.7        187  claude-opus-5-5 100%
  other-known              2.3%      15      2     93.0        232  claude-opus-5-5 100%
  verify                   2.0%      13      6     54.3        120  claude-opus-5-5 100%
  agent (non-workflow)     1.6%      10      2     84.0        180  claude-opus-5-5 100%

не распознано: 0.0% расхода воркфлоу-помощников
```
Итог одной фразой: проверка (review+verify+final-review) = 42.4% расхода integration; проверяющий в среднем ~71 шаг, ~187 тыс. токенов памяти на шаг.
