---
description: "Use after /critique when a final plan with Execution Strategy exists in .forge/plans/ and you need to implement it. Phase 4 of the forge dev pipeline. Runs the plan in the main session but delegates heavy work (reading many files, running long tests, analyzing logs) to subagents whose isolated context returns only short summaries — keeping the main session clean. Stops only on the checkpoints defined by the plan, not every N steps. Hands off to verification once the plan's completion criterion is met."
disable-model-invocation: true
---

Invoke the forge:execute skill and follow it exactly.
