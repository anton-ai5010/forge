#!/usr/bin/env python3
"""Forge Plugin — иконка в строке меню macOS с быстрым копированием команд.

Аналог forge-tray.py (Linux/GTK), но под macOS на rumps.
Клик по пункту копирует "/forge:<команда>" в буфер обмена через pbcopy.
"""

import subprocess
import rumps
import AppKit

VERSION = "7.1.3"

COMMANDS = [
    # Инициализация и старт
    ("forge:init", "Инициализация проекта"),
    ("forge:start", "Начало сессии"),
    ("forge:sync", "Синхронизация документации"),
    # 5-фазный pipeline
    ("forge:new-task", "Phase 1 — понять задачу"),
    ("forge:refine-idea", "Phase 1.5 — разбор идеи до плана"),
    ("forge:plan", "Phase 2 — построить план"),
    ("forge:critique", "Phase 3 — критика плана (4 персоны)"),
    ("forge:execute", "Phase 4 — реализация"),
    # Разблокировка и качество
    ("forge:unblocker", "Разблокировка (когда застрял)"),
    ("forge:investigate", "Разбор проблемы (до фикса)"),
    ("forge:cleanup", "Качество кода"),
    ("forge:validate", "Проверка перед мержем"),
    ("forge:hookify", "Превратить повторение в правило"),
    ("forge:evolve", "Кластеризация сквозных болей"),
    # Специализированные
    ("forge:deploy", "Деплой"),
    ("forge:design", "UI/UX дизайн"),
    ("forge:api-design", "Дизайн API"),
    ("forge:security-review", "Секьюрити ревью"),
    ("forge:migrate", "Миграция БД"),
    ("forge:discover", "Поиск в маркетплейсе"),
    ("forge:roadmap", "Карта целей (milestones)"),
    # Визуализация
    ("forge:graph", "Графовая карта кода"),
    ("forge:product-map", "Навигатор проекта (HTML)"),
    ("forge:explain", "Визуальное объяснение 'как работает X'"),
    ("forge:session-insights", "Инсайты сессии"),
]

SKILLS = [
    # Контекст и сессия
    ("forge:using-forge", "Введение в Forge (1% rule)"),
    ("forge:forge-context", "Загрузка контекста L0/L1/L2"),
    ("forge:session-awareness", "Запись в .forge/ файлы"),
    ("forge:session-insights", "Анализ прошлых сессий"),
    # Pipeline
    ("forge:new-task", "Phase 1 — задача + критерий"),
    ("forge:refine-idea", "Phase 1.5 — реалити-чек идеи"),
    ("forge:plan", "Phase 2 — план с чеклистами"),
    ("forge:critique", "Phase 3 — 4 персоны + confidence"),
    ("forge:execute", "Phase 4 — реализация через субагентов"),
    # Разработка
    ("forge:test-driven-development", "TDD (RED-GREEN-REFACTOR)"),
    ("forge:problem-investigation", "Разобраться до фикса"),
    ("forge:systematic-debugging", "Системный дебаг (root cause)"),
    ("forge:project-unblocker", "Разблокировка (застрял)"),
    ("forge:code-cleanup", "Очистка/рефактор"),
    ("forge:hookify", "Захукать повторное исправление"),
    ("forge:evolve", "Кластеризация learnings"),
    ("forge:using-git-worktrees", "Git worktrees (изоляция)"),
    # Агенты
    ("forge:subagent-driven-development", "Двойное ревью через субагентов"),
    ("forge:dispatching-parallel-agents", "Параллельные агенты"),
    # Ревью и завершение
    ("forge:requesting-code-review", "Запрос ревью"),
    ("forge:receiving-code-review", "Принять ревью"),
    ("forge:verification-before-completion", "Проверка готовности"),
    ("forge:finishing-a-development-branch", "Закрытие ветки"),
    # Специализированные
    ("forge:ui-ux-design", "UI/UX дизайн"),
    ("forge:api-design", "API дизайн"),
    ("forge:database-migrations", "Миграции БД"),
    ("forge:deployment", "Деплой и CI/CD"),
    ("forge:security-review", "Секьюрити аудит"),
    ("forge:writing-skills", "Создание новых скиллов"),
    # Визуализация
    ("forge:product-mapping", "Карта проекта (HTML)"),
    ("forge:explaining", "Визуальное объяснение"),
    # GitHub
    ("forge:github-sync", "Синхронизация с GitHub"),
    ("forge:roadmap", "Редактирование карты целей"),
]


def copy_to_clipboard(command):
    """Копирует /<команда> в буфер обмена через pbcopy."""
    text = f"/{command}"
    subprocess.run(["pbcopy"], input=text.encode(), check=False)


class ForgeTray(rumps.App):
    def __init__(self):
        super().__init__("⚒", quit_button=None)
        self._build_menu()
        # Прячем иконку из Dock — живём только в строке меню (accessory app).
        self._dock_timer = rumps.Timer(self._hide_dock, 0.1)
        self._dock_timer.start()

    def _hide_dock(self, timer):
        AppKit.NSApplication.sharedApplication().setActivationPolicy_(
            AppKit.NSApplicationActivationPolicyAccessory
        )
        timer.stop()

    def _make_item(self, command, desc):
        item = rumps.MenuItem(
            f"/{command}  —  {desc}",
            callback=lambda _, c=command: copy_to_clipboard(c),
        )
        return item

    def _build_menu(self):
        self.menu.add(rumps.MenuItem(f"⚒ Forge Plugin v{VERSION}", callback=None))
        self.menu.add(rumps.separator)

        self.menu.add(rumps.MenuItem("📋 Команды", callback=None))
        for cmd, desc in COMMANDS:
            self.menu.add(self._make_item(cmd, desc))

        self.menu.add(rumps.separator)

        self.menu.add(rumps.MenuItem("🎯 Скиллы", callback=None))
        for skill, desc in SKILLS:
            self.menu.add(self._make_item(skill, desc))

        self.menu.add(rumps.separator)
        self.menu.add(rumps.MenuItem("✕ Выход", callback=lambda _: rumps.quit_application()))


if __name__ == "__main__":
    ForgeTray().run()
