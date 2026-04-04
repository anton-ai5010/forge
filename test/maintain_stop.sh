# Найти все процессы maintain.sh и дочерние claude
ps aux | grep -E 'maintain\.sh|claude.*-p' | grep -v grep

# Потом:

# Убить всё дерево процессов
pkill -f 'maintain\.sh'
pkill -f 'claude.*--no-session-persistence'

# Если не помогает:

pkill -9 -f 'maintain\.sh'
pkill -9 -f 'claude.*--no-session-persistence'
