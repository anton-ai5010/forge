---
name: finishing-a-development-branch
description: "Use proactively when a feature/fix is done and the user wants to ship it — triggers: 'закрой ветку', 'готов к мержу', 'влить', 'смержить', 'закончил работу', 'всё готово', 'можно мержить', 'закрыть пр', 'finish the branch', 'ready to merge', 'wrap up this work', 'ship it', 'close the PR', 'merge it in'. Use at the end of a feature when tests pass, at the end of a bugfix before integration, when the user signals work is complete, or when a branch needs to be closed cleanly. Verifies tests actually pass (not 'should pass'), presents structured options (squash merge, PR, rebase, cleanup), updates docs, deletes the branch, and leaves main green. Skipping this skill is how dirty merges break main for the whole team, how stale branches pile up, how 'I thought tests passed' becomes a rollback, and how the next developer repeats your mistakes because docs weren't updated. One disciplined finish is cheaper than one hotfix."
---

# Finishing a Development Branch

**Role:** You are a release manager (8 years, shipped 500+ releases with zero rollback). Verify everything works, documentation is current, and the branch is clean.
**Stakes:** A dirty merge breaks main for the entire team. A missing doc means the next developer repeats your mistakes. Leave nothing unverified.

## Overview

Guide completion of development work by presenting clear options and handling chosen workflow.

**Core principle:** Verify tests → Present options → Execute choice → Clean up.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

## The Process

### Step 1: Verify Tests

**Before presenting options, verify tests pass:**

```bash
# Run project's test suite
npm test / cargo test / pytest / go test ./...
```

**If tests fail:**
```
Tests failing (<N> failures). Must fix before completing:

[Show failures]

Cannot proceed with merge/PR until tests pass.
```

Stop. Don't proceed to Step 2.

**If tests pass:** Continue to Step 1.5.

### Step 1.5: Update Documentation

Before presenting merge options, ensure documentation is current:
```bash
# Check if FORGE docs exist
ls .forge/map.json 2>/dev/null
```

If FORGE docs exist, suggest running `/forge:sync` to update documentation before merge. Documentation should reflect all changes made in this branch.

### Step 2: Determine Base Branch

```bash
# Try common base branches
git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null
```

Or ask: "This branch split from main - is that correct?"

### Step 3: Present Options

**Short-circuit для не-кодера:** если пользователь явно сказал «мержим» / «всё готово» / «влей» / «закрой ветку» / «ship it» (однозначное намерение слить локально) — **НЕ показывай меню**. Сразу иди по Option 1 (локальный мерж) и заверши человеческим подтверждением. Меню из 4 опций — только когда намерение неоднозначно или пользователь явно спросил про PR / «что дальше».

Если намерение неоднозначно — present exactly these 4 options:

```
Implementation complete. What would you like to do?

1. Merge back to <base-branch> locally
2. Push and create a Pull Request
3. Keep the branch as-is (I'll handle it later)
4. Discard this work

Which option?
```

**Don't add explanation** - keep options concise.

### Step 4: Execute Choice

#### Option 1: Merge Locally

```bash
# Auto-commit any uncommitted work on the feature branch BEFORE merge.
# НЕ слепой git add -A: сначала показать пользователю что попадёт в коммит.
if [ -n "$(git status --porcelain)" ]; then
  git status --short        # покажи человеку список файлов
  git add -A
  git reset -q .forge/      # не тащить forge runtime-состояние (часть .forge tracked исторически)
  git commit -m "<краткое описание задачи на русском>"
fi

# Switch to base branch
git checkout <base-branch>

# Pull latest — только если есть upstream/remote; иначе пропусти (не фатально на локальном репо)
git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1 && git pull --ff-only || true

# Merge feature branch
git merge <feature-branch>

# Verify tests on merged result
<test command>

# If tests pass
git branch -d <feature-branch>
```

**Перед авто-коммитом** скажи человеку простой строкой что сохраняешь: *«Сохраняю эти файлы: …»* (перечисли из `git status --short`) — **это единственная защита**: показанный список и есть то, что уйдёт в коммит. (`.gitignore` НЕ спасает уже-отслеживаемые файлы — поэтому forge runtime-состояние `.forge/` выше явно убирается из коммита через `git reset`.) Текст коммита формируй сам из названия задачи, **на русском** — пользователь его не подтверждает, не грузим.

**Если `git merge` упал с конфликтом** — НЕ оставляй репозиторий в полу-смерженном состоянии молча. Останови, объясни человеку простыми словами что две версии файла разошлись, и предложи помочь разрулить. Не-кодер не должен видеть сырой conflict-вывод без объяснения.

**После успешного мержа** дай человеческое подтверждение без жаргона (не говори commit/merge/branch):
> *«Готово. Правки сохранил, задачу влил в master, рабочую ветку убрал. Ты сейчас на master.»*

Then: Cleanup worktree (Step 5)

#### Option 2: Push and Create PR

```bash
# Push branch
git push -u origin <feature-branch>

# Create PR
gh pr create --title "<title>" --body "$(cat <<'EOF'
## Summary
<2-3 bullets of what changed>

## Test Plan
- [ ] <verification steps>
EOF
)"
```

Then: Cleanup worktree (Step 5)

#### Option 3: Keep As-Is

Report: "Keeping branch <name>. Worktree preserved at <path>."

**Don't cleanup worktree.**

#### Option 4: Discard

**Confirm first:**
```
This will permanently delete:
- Branch <name>
- All commits: <commit-list>
- Worktree at <path>

Type 'discard' to confirm.
```

Wait for exact confirmation.

If confirmed:
```bash
git checkout <base-branch>
git branch -D <feature-branch>
```

Then: Cleanup worktree (Step 5)

### Step 5: Cleanup Worktree

**For Options 1, 2, 4:**

Check if in worktree:
```bash
git worktree list | grep $(git branch --show-current)
```

If yes:
```bash
git worktree remove <worktree-path>
```

**For Option 3:** Keep worktree.

## Quick Reference

| Option | Merge | Push | Keep Worktree | Cleanup Branch |
|--------|-------|------|---------------|----------------|
| 1. Merge locally | ✓ | - | - | ✓ |
| 2. Create PR | - | ✓ | ✓ | - |
| 3. Keep as-is | - | - | ✓ | - |
| 4. Discard | - | - | - | ✓ (force) |

## Common Mistakes

**Skipping test verification**
- **Problem:** Merge broken code, create failing PR
- **Fix:** Always verify tests before offering options

**Open-ended questions**
- **Problem:** "What should I do next?" → ambiguous
- **Fix:** When intent is ambiguous, present exactly 4 structured options. On explicit merge intent («мержим» / «ship it») — skip the menu and go straight to Option 1.

**Automatic worktree cleanup**
- **Problem:** Remove worktree when might need it (Option 2, 3)
- **Fix:** Only cleanup for Options 1 and 4

**No confirmation for discard**
- **Problem:** Accidentally delete work
- **Fix:** Require typed "discard" confirmation

## Red Flags

**Never:**
- Proceed with failing tests
- Merge without verifying tests on result
- Delete work without confirmation
- Force-push without explicit request

**Always:**
- Verify tests before offering options
- Present exactly 4 options when intent is ambiguous (on explicit merge intent — skip the menu, go straight to Option 1)
- Get typed confirmation for Option 4
- Clean up worktree for Options 1 & 4 only

## Integration

**Called by:**
- **subagent-driven-development** (Step 7) - After all tasks complete
- **execute** - After implementation completes

> ⚠️ Авто-коммит несохранённого в Option 1 срабатывает при **любом** вызывающем — и из execute, и из subagent-driven-development. В sdd-потоке состояние дерева может отличаться (промежуточные артефакты субагентов), поэтому показ `git status --short` перед коммитом обязателен в обоих случаях — коммить только то, что показал пользователю.

**Pairs with:**
- **using-git-worktrees** - Cleans up worktree created by that skill
