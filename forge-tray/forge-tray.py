#!/usr/bin/env python3
"""Forge Plugin — системный трей с быстрым копированием команд."""

import subprocess
import gi
gi.require_version('Gtk', '3.0')
gi.require_version('AyatanaAppIndicator3', '0.1')
from gi.repository import Gtk, AyatanaAppIndicator3, Gdk, GLib

COMMANDS = [
    # Инициализация и старт
    ("forge:init", "Инициализация проекта"),
    ("forge:start", "Начало сессии"),
    ("forge:sync", "Синхронизация документации"),
    # Планирование
    ("forge:brainstorm", "Обсуждение идеи"),
    ("forge:write-plan", "Написание плана"),
    ("forge:execute-plan", "Выполнение плана"),
    # Разблокировка и качество
    ("forge:unblocker", "Разблокировка проекта"),
    ("forge:cleanup", "Качество кода"),
    ("forge:validate", "Проверка перед мержем"),
    # Специализированные
    ("forge:deploy", "Деплой"),
    ("forge:design", "UI/UX дизайн"),
    ("forge:api-design", "Дизайн API"),
    ("forge:security-review", "Секьюрити ревью"),
    ("forge:migrate", "Миграция"),
    ("forge:discover", "Поиск в маркетплейсе"),
]

SKILLS = [
    # Контекст и сессия
    ("forge:forge-context", "Загрузка контекста"),
    ("forge:session-awareness", "Осознанность сессии"),
    ("forge:using-forge", "Использование Forge"),
    ("forge:daily-planner", "Планировщик дня"),
    # Планирование и исполнение
    ("forge:brainstorming", "Брейнсторм перед фичей"),
    ("forge:writing-plans", "Написание планов"),
    ("forge:executing-plans", "Исполнение планов"),
    ("forge:dispatching-parallel-agents", "Параллельные агенты"),
    ("forge:subagent-driven-development", "Субагентная разработка"),
    # Разработка
    ("forge:test-driven-development", "TDD"),
    ("forge:problem-investigation", "Разбор проблемы"),
    ("forge:systematic-debugging", "Системный дебаг"),
    ("forge:using-git-worktrees", "Git worktrees"),
    ("forge:project-unblocker", "Разблокировка"),
    # Ревью и завершение
    ("forge:requesting-code-review", "Запрос ревью"),
    ("forge:receiving-code-review", "Получение ревью"),
    ("forge:verification-before-completion", "Верификация"),
    ("forge:finishing-a-development-branch", "Завершение ветки"),
    # Специализированные
    ("forge:code-cleanup", "Очистка кода"),
    ("forge:ui-ux-design", "UI/UX дизайн"),
    ("forge:api-design", "API дизайн"),
    ("forge:deployment", "Деплой и CI/CD"),
    ("forge:database-migrations", "Миграции БД"),
    ("forge:security-review", "Секьюрити ревью"),
    ("forge:writing-skills", "Создание скиллов"),
]


def copy_to_clipboard(widget, command):
    """Копирует команду в буфер обмена через xclip."""
    text = f"/{command}"
    subprocess.Popen(
        ["xclip", "-selection", "clipboard"],
        stdin=subprocess.PIPE,
    ).communicate(text.encode())


def build_menu():
    menu = Gtk.Menu()

    # Заголовок
    header = Gtk.MenuItem(label="⚒ Forge Plugin v5.5.0")
    header.set_sensitive(False)
    menu.append(header)
    menu.append(Gtk.SeparatorMenuItem())

    # Команды
    cmd_header = Gtk.MenuItem(label="📋 Команды")
    cmd_header.set_sensitive(False)
    menu.append(cmd_header)

    for cmd, desc in COMMANDS:
        item = Gtk.MenuItem(label=f"  /{cmd}  —  {desc}")
        item.connect("activate", copy_to_clipboard, cmd)
        menu.append(item)

    menu.append(Gtk.SeparatorMenuItem())

    # Скиллы
    skill_header = Gtk.MenuItem(label="🎯 Скиллы")
    skill_header.set_sensitive(False)
    menu.append(skill_header)

    for skill, desc in SKILLS:
        item = Gtk.MenuItem(label=f"  /{skill}  —  {desc}")
        item.connect("activate", copy_to_clipboard, skill)
        menu.append(item)

    menu.append(Gtk.SeparatorMenuItem())

    # Выход
    quit_item = Gtk.MenuItem(label="✕ Закрыть")
    quit_item.connect("activate", lambda _: Gtk.main_quit())
    menu.append(quit_item)

    menu.show_all()
    return menu


def main():
    indicator = AyatanaAppIndicator3.Indicator.new(
        "forge-tray",
        "accessories-text-editor",
        AyatanaAppIndicator3.IndicatorCategory.APPLICATION_STATUS,
    )
    indicator.set_status(AyatanaAppIndicator3.IndicatorStatus.ACTIVE)
    indicator.set_title("Forge Commands")
    indicator.set_menu(build_menu())

    Gtk.main()


if __name__ == "__main__":
    main()
