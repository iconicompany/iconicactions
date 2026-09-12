#!/usr/bin/env bash
# Выключить и включить запуск воркфлоу в GitHub Actions — правкой `on:`, а не переименованием файла.
#
#   actions.sh status                     # какие воркфлоу есть и чем запускаются
#   actions.sh off deployment-production  # снять триггеры, оставив ручной запуск
#   actions.sh on  deployment-production  # вернуть снятые триггеры
#
# ПОЧЕМУ НЕ ПЕРЕИМЕНОВАНИЕМ. Файл воркфлоу — ещё и источник настроек выкатки: `werf.sh` читает из
# него namespace, домен и адрес базы, чтобы локальная выкатка и CI не разъехались. Переименованный
# в `.txt` файл перестаёт быть воркфлоу для GitHub, но остаётся нужным всем остальным, и его
# приходится искать по расширениям — отключение Actions начинает молча ломать соседние инструменты.
#
# Снятые триггеры сохраняются комментарием прямо над `on:`, поэтому `on` возвращает ровно то, что
# было, а не то, что помнит автор. Ручной запуск (`workflow_dispatch`) остаётся всегда: иначе
# выключенный воркфлоу нельзя ни проверить, ни запустить в обход.
set -euo pipefail

BEGIN_MARK="# actions-off-begin"
END_MARK="# actions-off-end"

die() {
  echo "ОТКАЗ: $*" >&2
  exit 1
}

usage() {
  echo "Usage: actions.sh <status|off|on> [воркфлоу]" >&2
}

COMMAND="${1:-}"
TARGET="${2:-}"
[ -n "$COMMAND" ] || {
  usage
  exit 2
}

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || die "не репозиторий git"
cd "$ROOT"
DIR=".github/workflows"
[ -d "$DIR" ] || die "в $ROOT нет $DIR"

# Имя можно давать коротким: `deployment-production` вместо полного пути с расширением.
resolve() {
  local name="$1"
  for candidate in "$name" "$DIR/$name" "$DIR/$name.yml" "$DIR/$name.yaml"; do
    [ -f "$candidate" ] && {
      echo "$candidate"
      return 0
    }
  done
  die "воркфлоу не найден: $name (смотрите actions.sh status)"
}

if [ "$COMMAND" = "status" ]; then
  for file in "$DIR"/*.yml "$DIR"/*.yaml; do
    [ -f "$file" ] || continue
    BEGIN_MARK="$BEGIN_MARK" python3 - "$file" <<'PY'
import os, re, sys

path = sys.argv[1]
lines = open(path).read().split('\n')
name = next((l.split(':', 1)[1].strip() for l in lines if l.startswith('name:')), os.path.basename(path))
disabled = any(l.strip() == os.environ['BEGIN_MARK'] for l in lines)

triggers = []
inside = False
for line in lines:
    if re.match(r"""^["']?on["']?:""", line):
        inside = True
        tail = line.split(':', 1)[1].strip()
        if tail:
            triggers.append(tail)
        continue
    if inside:
        if line.strip() and not line.startswith((' ', '\t')):
            break
        if line.startswith('  ') and not line.startswith('   ') and line.strip().endswith(':'):
            triggers.append(line.strip().rstrip(':'))

mark = 'ВЫКЛЮЧЕН' if disabled else 'включён'
print(f"  {os.path.basename(path):34} {mark:9} {', '.join(triggers) or '—'}   ({name})")
PY
  done
  exit 0
fi

case "$COMMAND" in
  off | on) ;;
  *)
    usage
    die "неизвестная команда: $COMMAND"
    ;;
esac
[ -n "$TARGET" ] || {
  usage
  die "не назван воркфлоу"
}
FILE=$(resolve "$TARGET")

BEGIN_MARK="$BEGIN_MARK" END_MARK="$END_MARK" python3 - "$COMMAND" "$FILE" <<'PY'
import os, re, sys

command, path = sys.argv[1], sys.argv[2]
begin, end = os.environ['BEGIN_MARK'], os.environ['END_MARK']
lines = open(path).read().split('\n')


def find_on(lines):
    """Границы блока `on:` — от самой строки до первого ключа верхнего уровня после неё."""
    for i, line in enumerate(lines):
        if re.match(r"""^["']?on["']?:""", line):
            j = i + 1
            while j < len(lines) and (not lines[j].strip() or lines[j].startswith((' ', '\t'))):
                j += 1
            # Пустые строки в хвосте принадлежат не блоку, а разделению секций.
            while j > i + 1 and not lines[j - 1].strip():
                j -= 1
            return i, j
    return None, None


start, stop = find_on(lines)
if start is None:
    sys.exit(f"ОТКАЗ: в {path} нет ключа on:")

saved_start = next((i for i, l in enumerate(lines) if l.strip() == begin), None)
saved_stop = next((i for i, l in enumerate(lines) if l.strip() == end), None)
disabled = saved_start is not None and saved_stop is not None

if command == 'off':
    if disabled:
        sys.exit(f"{os.path.basename(path)}: триггеры уже сняты, ничего не делаю")
    body = lines[start:stop]
    # Сохраняем ДОСЛОВНО, вместе с отступами: возврат обязан дать тот же файл, а не пересказ.
    saved = [begin] + ['# ' + l if l else '#' for l in body] + [end]
    note = [
        '# ТРИГГЕРЫ СНЯТЫ: сборка и выкатка идут локально (werf.sh).',
        '# Вернуть ровно то, что было: actions.sh on ' + os.path.basename(path),
    ]
    replacement = note + saved + ['on:', '  workflow_dispatch:']
    lines[start:stop] = replacement
    result = 'триггеры сняты, остался workflow_dispatch'
else:
    if not disabled:
        sys.exit(f"{os.path.basename(path)}: триггеры не сняты, возвращать нечего")
    body = [l[2:] if l.startswith('# ') else ('' if l.strip() == '#' else l) for l in lines[saved_start + 1:saved_stop]]
    # Заметку над сохранённым блоком убираем вместе с ним — она про снятое состояние.
    note_start = saved_start
    notes = ('# ТРИГГЕРЫ СНЯТЫ', '# Вернуть ровно то')
    while note_start > 0 and lines[note_start - 1].lstrip().startswith(notes):
        note_start -= 1
    start, stop = find_on(lines)
    lines[note_start:stop] = body
    result = 'триггеры возвращены'

open(path, 'w').write('\n'.join(lines))
print(f"{os.path.basename(path)}: {result}")
PY
