---
description: "Сканит историю текущей сессии, находит места где пользователь исправлял Claude по одной и той же теме, генерит правило-хук в .forge/hookrules/*.md. Без аргументов — анализирует автоматически. С аргументом — создаёт правило из явного описания."
argument-hint: "[правило своими словами — или пусто для автоанализа сессии]"
disable-model-invocation: true
---

Invoke the forge:hookify skill and follow it exactly.
