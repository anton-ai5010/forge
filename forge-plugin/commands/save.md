---
description: Сохранить память проекта (.forge — задачи, планы, решения, журнал) в git и на GitHub
argument-hint: "[что сохраняем — опционально, пойдёт в сообщение коммита]"
---

# /forge:save — сохранить память проекта

Invoke the `forge:memory-backup` skill via the Skill tool and follow its procedure.

If `$ARGUMENTS` is non-empty — pass it to `backup.sh` as the commit description. Otherwise let the script use its default.
