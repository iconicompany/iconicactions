#!/usr/bin/env bash
# Локальная сборка и выкатка проекта платформы одной командой: для production ещё и версия с тегом,
# а в конце — проверка, что приложение отвечает. Нужен, когда выкатка в GitHub Actions отключена.
#
# Настройки скрипт ЧИТАЕТ из workflow-файла окружения, а не хранит у себя: так локальная выкатка и
# CI не разъедутся, и возврат к Actions не потребует переносить настройки обратно. Умолчания входов
# берутся из переиспользуемого deployment.yml, лежащего рядом с этим скриптом.
#
# Usage: werf.sh <окружение> [patch|minor|major] [--dry-run] [--deploy-only]
#          <окружение>    production | testing | development — обязательно, без умолчания
#          patch|…        шаг версии, только для production (по умолчанию patch)
#          --dry-run      напечатать настройки, версию и все команды; ничего не выполнять
#          --deploy-only  повторить сборку и выкатку последнего тега, не выпуская новый
set -euo pipefail

die() {
  echo "ОТКАЗ: $*" >&2
  exit 1
}

usage() {
  echo "Usage: werf.sh <production|testing|development> [patch|minor|major] [--dry-run] [--deploy-only]" >&2
}

ENVIRONMENT=""
BUMP="patch"
DRY_RUN=""
DEPLOY_ONLY=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN="1" ;;
    --deploy-only) DEPLOY_ONLY="1" ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*)
      usage
      die "неизвестный флаг: $arg"
      ;;
    *)
      # Первое позиционное слово — окружение, второе — шаг версии.
      if [ -z "$ENVIRONMENT" ]; then
        ENVIRONMENT="$arg"
      else
        case "$arg" in
          patch | minor | major) BUMP="$arg" ;;
          *)
            usage
            die "неизвестный аргумент: $arg"
            ;;
        esac
      fi
      ;;
  esac
done

# Умолчания у окружения нет намеренно: «по умолчанию production» однажды приедет в прод с чужого
# терминала, и узнают об этом по факту.
[ -n "$ENVIRONMENT" ] || {
  usage
  die "первым аргументом назовите окружение: production, testing или development"
}
[[ "$ENVIRONMENT" =~ ^[a-z][a-z0-9-]*$ ]] || die "окружение «$ENVIRONMENT» не похоже на имя окружения"

# Прежний werf.sh был обёрткой (`werf $*`), и привычка набрать `./werf.sh converge` переживёт замену.
# Здесь первым аргументом ждут ОКРУЖЕНИЕ, и отказ обязан сказать это, а не искать несуществующий
# файл настроек `deployment-converge.*`.
case " converge build dismiss render plan publish bundle cleanup purge kubectl helm cr ci-env run compose export slugify synchronize config version stage host docs completion " in
  *" $ENVIRONMENT "*)
    die "«$ENVIRONMENT» — команда werf, а первым аргументом здесь ждут окружение. Это не обёртка над werf:
       нужно 'werf.sh production' или 'werf.sh testing'; саму werf зовите напрямую — 'werf $ENVIRONMENT'"
    ;;
esac

IS_PRODUCTION=""
[ "$ENVIRONMENT" = "production" ] && IS_PRODUCTION="1"

[ -z "$DEPLOY_ONLY" ] || [ -n "$IS_PRODUCTION" ] ||
  die "--deploy-only имеет смысл только для production: на стендах тег и не выпускается"

# На --dry-run шаг печатается и не выполняется — один и тот же список команд служит и планом,
# и самой выкаткой, поэтому разойтись им негде.
run() {
  echo "+ $*"
  [ -n "$DRY_RUN" ] && return 0
  "$@"
}

# То же для конвейера, который через argv не выражается.
run_shell() {
  echo "+ $1"
  [ -n "$DRY_RUN" ] && return 0
  bash -o pipefail -c "$1"
}

# --- где мы и чем собираем ----------------------------------------------------------------------

PROJECT_DIR=$(git rev-parse --show-toplevel 2>/dev/null) ||
  die "запускать из корня git-репозитория проекта — здесь git-репозитория нет"
cd "$PROJECT_DIR"

command -v werf >/dev/null || die "werf не найден в PATH — без него нечем ни собрать, ни выкатить"

[ -f werf.yaml ] || die "в корне проекта ($PROJECT_DIR) нет werf.yaml — это не проект werf"
WERF_PROJECT=$(sed -nE 's/^project:[[:space:]]*"?([A-Za-z0-9_.-]+)"?.*/\1/p' werf.yaml | head -1)
[ -n "$WERF_PROJECT" ] || die "в werf.yaml не нашлось строки 'project:' — имя проекта взять неоткуда"

ORIGIN_URL=$(git remote get-url origin 2>/dev/null) || die "у репозитория нет remote 'origin'"
REPO_SLUG=$(echo "$ORIGIN_URL" | sed -E 's#^.*github\.com[:/]##; s#\.git$##')
case "$REPO_SLUG" in
  */*) ;;
  *) die "адрес origin ($ORIGIN_URL) не разбирается как owner/repo на github.com" ;;
esac
OWNER="${REPO_SLUG%%/*}"
REPO="${REPO_SLUG##*/}"
BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Отключённый воркфлоу в этих репозиториях переименовывают в .txt (так уже сделано с testing), а
# настройки в нём остаются те же. Поэтому перебираем расширения: иначе отключение Actions молча
# лишало бы локальную выкатку настроек.
WORKFLOW=""
for candidate in "${DEPLOY_WORKFLOW:-}" \
  ".github/workflows/deployment-$ENVIRONMENT.yml" \
  ".github/workflows/deployment-$ENVIRONMENT.yaml" \
  ".github/workflows/deployment-$ENVIRONMENT.txt"; do
  if [ -n "$candidate" ] && [ -f "$candidate" ]; then
    WORKFLOW="$candidate"
    break
  fi
done
[ -n "$WORKFLOW" ] ||
  die "нет .github/workflows/deployment-$ENVIRONMENT.* — настройки окружения «$ENVIRONMENT» брать неоткуда"

SELF=$(readlink -f "${BASH_SOURCE[0]}")
REUSABLE_WORKFLOW="$(dirname "$(dirname "$SELF")")/.github/workflows/deployment.yml"

# --- настройки из workflow-файла ----------------------------------------------------------------

# Второй подстановкой в шаблоны (namespace) CI кладёт 'production' для тега и имя ветки для ветки.
NAMESPACE_SLOT="$BRANCH"
[ -n "$IS_PRODUCTION" ] && NAMESPACE_SLOT="production"

SETTINGS=$(
  WORKFLOW_FILE="$WORKFLOW" REUSABLE_WORKFLOW="$REUSABLE_WORKFLOW" \
    OWNER="$OWNER" REPO="$REPO" WERF_ENV="$ENVIRONMENT" NAMESPACE_SLOT="$NAMESPACE_SLOT" \
    python3 - <<'PY'
import os, re, shlex, sys

import yaml

workflow_path = os.environ['WORKFLOW_FILE']
reusable_path = os.environ['REUSABLE_WORKFLOW']
owner = os.environ['OWNER']
repo = os.environ['REPO']
werf_env = os.environ['WERF_ENV']
namespace_slot = os.environ['NAMESPACE_SLOT']


def die(message):
    sys.stderr.write('ОТКАЗ: ' + message + '\n')
    sys.exit(1)


def load(path):
    try:
        with open(path, encoding='utf-8') as handle:
            return yaml.safe_load(handle) or {}
    except FileNotFoundError:
        return {}


workflow = load(workflow_path)
if not workflow:
    die(f'{workflow_path} пустой или не читается как YAML')

# Берётся только блок `with:`. На `on:` не смотрим вовсе, поэтому воркфлоу с вырезанным триггером
# (так Actions и отключают) остаётся верным источником настроек.
settings = {}
for job in (workflow.get('jobs') or {}).values():
    if isinstance(job, dict) and isinstance(job.get('with'), dict):
        settings = job['with']
        break
if not settings:
    die(f'в {workflow_path} нет джоба с блоком `with:` — настройки выкатки брать неоткуда')

# Умолчания входов живут в переиспользуемом воркфлоу; PyYAML разбирает ключ `on:` как True.
reusable = load(reusable_path)
declared = ((reusable.get('on') or reusable.get(True) or {}).get('workflow_call') or {}).get('inputs') or {}
defaults = {key: value.get('default') for key, value in declared.items() if isinstance(value, dict)}

EXPRESSION = re.compile(r'\$\{\{\s*(.+?)\s*\}\}')
KNOWN = {
    'github.repository_owner': owner,
    'github.event.repository.name': repo,
    'github.repository': f'{owner}/{repo}',
}


def text(key, raw):
    if raw is None:
        return ''
    if isinstance(raw, bool):
        return 'true' if raw else 'false'

    def replace(match):
        expression = match.group(1)
        if expression in KNOWN:
            return KNOWN[expression]
        die(f'{key} в {workflow_path} задан выражением GitHub «{expression}» — локально его вычислить'
            ' нечем; задайте значение явно')

    return EXPRESSION.sub(replace, str(raw))


def setting(key):
    return text(key, settings[key] if key in settings else defaults.get(key))


def fmt(key, template, *args):
    try:
        return template.format(*args)
    except (IndexError, KeyError, ValueError):
        die(f'шаблон {key}="{template}" из {workflow_path} не разворачивается подстановками {args}')


def slug(value):
    return re.sub(r'-+', '-', re.sub(r'[^a-z0-9]', '-', value.lower())).strip('-')


namespace = slug(fmt('WERF_NAMESPACE', setting('WERF_NAMESPACE') or '{0}-{1}', repo, namespace_slot))
domain = fmt('DOMAIN', setting('DOMAIN'), namespace)
domain2 = fmt('DOMAIN2', setting('DOMAIN2'), namespace)


def database_url(raw):
    """Тот же разбор, что шаги «Parse DATABASE_URL» и «Setup database» переиспользуемого воркфлоу."""
    if not raw:
        return ''
    protocol, rest = '', raw
    if '://' in raw:
        head, rest = raw.split('://', 1)
        protocol = head.lower() + '://'
    hostpart, _, path = rest.partition('/')
    userpass, _, hostport = hostpart.rpartition('@')
    host = hostport.split(':', 1)[0]
    if not host:
        return ''
    # Умолчание CI: WERF_NAME + WERF_ENV, где WERF_NAME — имя репозитория.
    user = userpass.split(':', 1)[0] or f'{repo}{werf_env}'
    name = path or f'{repo}{werf_env}'
    return f'{protocol}{user}@{host}/{name}'


for key, value in {
    'WERF_NAMESPACE': namespace,
    'DOMAIN': domain,
    'DOMAIN2': domain2,
    'DATABASE_URL': database_url(setting('DATABASE_URL')),
    'REGISTRY': setting('REGISTRY'),
    'CLUSTER_URL': setting('CLUSTER_URL'),
    'BUILD_ONLY': setting('BUILD_ONLY'),
    'DOCKER_BUILDKIT': setting('DOCKER_BUILDKIT'),
}.items():
    print(f'{key}={shlex.quote(value)}')
PY
)
eval "$SETTINGS"

# Окружение задаёт аргумент, а не воркфлоу: в testing-файлах WERF_ENV — выражение GitHub, которое
# локально не вычислить, да и выбор окружения принадлежит тому, кто запускает.
WERF_ENV="$ENVIRONMENT"

# Адрес образов CI получает от `werf ci-env github`; локально его надо назвать. Схема та же:
# ghcr.io/<владелец>/<репозиторий>/<проект werf>.
WERF_REPO="${WERF_REPO:-${REGISTRY:-ghcr.io/$OWNER/$REPO/$WERF_PROJECT}}"
WERF_REPO=$(echo "$WERF_REPO" | tr '[:upper:]' '[:lower:]')
REGISTRY_HOST="${WERF_REPO%%/*}"

# kubectl в системе может оказаться клиентом k3s со своим конфигом, поэтому KUBECONFIG задаём явно,
# а кластерные команды идём через `werf kubectl` — как и CI.
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

# Контекст выбираем ПО АДРЕСУ КЛАСТЕРА из воркфлоу. Вход KUBE_CONTEXT там называет контекст внутри
# secrets.KUBE_CONFIG, то есть чужого конфига, и локально означал бы не тот кластер.
KUBE_CONTEXT="${WERF_KUBE_CONTEXT:-}"
if [ -z "$KUBE_CONTEXT" ]; then
  KUBE_CONTEXT=$(
    werf kubectl config view -o json 2>/dev/null | CLUSTER_URL="$CLUSTER_URL" python3 -c '
import json, os, sys

config = json.load(sys.stdin)
wanted = os.environ["CLUSTER_URL"].rstrip("/")
clusters = {c["name"] for c in config.get("clusters") or [] if c["cluster"].get("server", "").rstrip("/") == wanted}
for context in config.get("contexts") or []:
    if context["context"].get("cluster") in clusters:
        print(context["name"])
        break
' || true
  )
fi
[ -n "$KUBE_CONTEXT" ] ||
  die "в $KUBECONFIG нет контекста на кластер $CLUSTER_URL — задайте его переменной WERF_KUBE_CONTEXT"

# --- предполётные проверки ----------------------------------------------------------------------

echo "== Предполётные проверки ($ENVIRONMENT)"
PREFLIGHT_FAILED=0

pass_check() { echo "  ok  $*"; }

# На холостом прогоне отказ не обрывает работу: план должен показать сразу всё, что мешает.
fail_check() {
  if [ -n "$DRY_RUN" ]; then
    echo "  НЕ ПРОЙДЕНО: $*"
    PREFLIGHT_FAILED=1
  else
    die "$*"
  fi
}

# Ветку и совпадение с origin требует только production: стенд затем и нужен, чтобы выкатить ветку.
LOCAL=$(git rev-parse HEAD)
if [ -n "$IS_PRODUCTION" ]; then
  if [ "$BRANCH" = "main" ]; then
    pass_check "ветка main"
  else
    fail_check "production выкатывается с main, а сейчас $BRANCH"
  fi

  git fetch --quiet origin main || true
  REMOTE=$(git rev-parse origin/main)
  if [ "$LOCAL" = "$REMOTE" ]; then
    pass_check "main совпадает с origin/main (${LOCAL:0:8})"
  else
    fail_check "main разошёлся с origin/main (локально ${LOCAL:0:8}, на сервере ${REMOTE:0:8}) — выкатится не тот код"
  fi
else
  pass_check "ветка $BRANCH (${LOCAL:0:8}) — для $ENVIRONMENT подойдёт любая"
fi

# Дерево проверяется всегда: werf собирает образ из коммита, и незакоммиченная правка в него не попадёт.
if [ -z "$(git status --porcelain)" ]; then
  pass_check "рабочая копия чистая"
else
  fail_check "рабочая копия грязная — незакоммиченное в образ не попадёт; закоммитьте или уберите"
fi

pass_check "werf $(werf version 2>/dev/null | head -1)"

if [ -f .werf_secret_key ] || [ -n "${WERF_SECRET_KEY:-}" ]; then
  pass_check "ключ werf-секретов на месте"
else
  fail_check "нет .werf_secret_key в корне проекта и пустой WERF_SECRET_KEY — секретные значения helm не расшифруются"
fi

# Кластер отвечает. Первый отказ бывает транзиентным сбоем локального DNS, поэтому одна повторная
# попытка; повторившийся отказ — это уже протухший сертификат или потерянный доступ.
CLUSTER_ANSWER=""
for attempt in 1 2; do
  # Спрашиваем /version у сервера, а не `kubectl version`: встроенный в werf клиент спотыкается на
  # разборе собственной версии и отказывает даже на живом кластере.
  if CLUSTER_ANSWER=$(werf kubectl --context "$KUBE_CONTEXT" get --raw /version 2>&1); then
    break
  fi
  CLUSTER_ANSWER="${CLUSTER_ANSWER##*$'\n'}"
  [ "$attempt" = 1 ] && sleep 3
done
if echo "$CLUSTER_ANSWER" | grep -q '"gitVersion"'; then
  pass_check "кластер $CLUSTER_URL отвечает (контекст $KUBE_CONTEXT)"
else
  fail_check "кластер $CLUSTER_URL не отвечает на контексте $KUBE_CONTEXT: $CLUSTER_ANSWER"
fi

# Токен реестра. Образы собираются локально и кладутся в ghcr — без входа выкатка упадёт на пуше.
REGISTRY_USER="${REGISTRY_USERNAME:-$OWNER}"
REGISTRY_TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
if [ -z "$REGISTRY_TOKEN" ] && command -v gh >/dev/null; then
  REGISTRY_TOKEN=$(gh auth token 2>/dev/null || true)
  REGISTRY_USER="${REGISTRY_USERNAME:-$(gh api user --jq .login 2>/dev/null || echo "$OWNER")}"
fi
if [ -n "$REGISTRY_TOKEN" ]; then
  # Наличия токена МАЛО. `werf cr login` принимает любой токен и отвечает «Successful login», а
  # отказ по правам приезжает только на первом обращении к репозиторию — из середины converge,
  # уже ПОСЛЕ созданного тега и релиза. Поэтому право читать теги проверяется здесь, запросом.
  REGISTRY_PATH="${WERF_REPO#*/}"
  REGISTRY_CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 \
    -H "Authorization: Bearer $(printf '%s' "$REGISTRY_TOKEN" | base64 -w0)" \
    "https://$REGISTRY_HOST/v2/$REGISTRY_PATH/tags/list?n=1" 2>/dev/null || echo 000)
  case "$REGISTRY_CODE" in
    200|404) pass_check "токен для $REGISTRY_HOST читает $WERF_REPO (пользователь $REGISTRY_USER)" ;;
    403|401) fail_check "токен для $REGISTRY_HOST есть, но прав на $WERF_REPO нет (HTTP $REGISTRY_CODE) — нужны scope write:packages и read:packages: gh auth refresh -h github.com -s write:packages,read:packages" ;;
    000) pass_check "токен для $REGISTRY_HOST есть; права не проверены — $REGISTRY_HOST не ответил" ;;
    *) fail_check "$REGISTRY_HOST ответил HTTP $REGISTRY_CODE на список тегов $WERF_REPO" ;;
  esac
else
  fail_check "нет токена для $REGISTRY_HOST — задайте GITHUB_TOKEN или авторизуйтесь: gh auth login"
fi

# werf.yaml может требовать BUILD_TOKEN на стадии сборки; пустой даст непонятный отказ внутри сборки.
if grep -q 'BUILD_TOKEN' werf.yaml; then
  if [ -n "${BUILD_TOKEN:-}" ]; then
    pass_check "BUILD_TOKEN задан (его требует werf.yaml)"
  else
    fail_check "werf.yaml объявляет секрет BUILD_TOKEN, а переменная пустая — сборка не достанет приватный источник"
  fi
fi

# --- версия и тег: только production --------------------------------------------------------------

CURRENT_TAG=""
NEW_TAG=""
if [ -n "$IS_PRODUCTION" ]; then
  # Теги нужны целиком и от origin: версия считается от последнего опубликованного. --force
  # обязателен, иначе разошедшийся локальный тег отказывает весь fetch («would clobber existing tag»).
  git fetch --quiet --tags --force origin || true

  # Самый старший тег ПО ВЕРСИИ, а не ближайший достижимый: `git describe` не видит тегов вне
  # предков HEAD и однажды уже предложил занятый номер.
  CURRENT_TAG=$(git tag --list 'v*' --sort=-v:refname | head -1)
  [ -n "$CURRENT_TAG" ] || CURRENT_TAG="v0.0.0"

  if [ -n "$DEPLOY_ONLY" ]; then
    NEW_TAG="$CURRENT_TAG"
  else
    # Точка после `v` снимается вместе с префиксом: тег однажды поставили как `v.0.14.7`.
    RAW=$(echo "$CURRENT_TAG" | sed -E 's/^v\.?//')
    IFS='.' read -r MAJOR MINOR PATCH <<<"$RAW"
    for part in "$MAJOR" "$MINOR" "$PATCH"; do
      [[ "$part" =~ ^[0-9]+$ ]] ||
        die "версию из тега $CURRENT_TAG разобрать не удалось: получилось [$MAJOR][$MINOR][$PATCH]"
    done

    case "$BUMP" in
      major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
      minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
      patch) PATCH=$((PATCH + 1)) ;;
    esac
    NEW_TAG="v$MAJOR.$MINOR.$PATCH"

    git rev-parse -q --verify "refs/tags/$NEW_TAG" >/dev/null && die "тег $NEW_TAG уже существует"
  fi
fi

# Теги образов — как в шаге «Sanitize and set custom tags»: при нескольких образах werf требует
# префикс %image%, иначе они перезапишут друг друга. Тег `latest` CI ставит только на релиз.
IMAGE_COUNT=$(grep -c '^image:' werf.yaml || true)
TAG_PREFIX=""
[ "$IMAGE_COUNT" -gt 1 ] && TAG_PREFIX="%image%-"
sanitize_tag() {
  echo "$1" | sed -e 's/[^a-zA-Z0-9.-]/-/g' -e 's/^[._-]//' -e 's/[._-]$//' | cut -c 1-128
}
if [ -n "$IS_PRODUCTION" ]; then
  WERF_ADD_CUSTOM_TAG_BRANCH="${TAG_PREFIX}$(sanitize_tag "$NEW_TAG")"
  WERF_ADD_CUSTOM_TAG_LATEST="${TAG_PREFIX}latest"
else
  WERF_ADD_CUSTOM_TAG_BRANCH="${TAG_PREFIX}$(sanitize_tag "$BRANCH")"
  WERF_ADD_CUSTOM_TAG_LATEST=""
fi

HEALTH_URL="${DEPLOY_HEALTH_URL:-https://$DOMAIN/$WERF_PROJECT/}"

echo
echo "== Настройки выкатки (из $WORKFLOW)"
echo "  проект werf:     $WERF_PROJECT ($OWNER/$REPO)"
echo "  WERF_ENV:        $WERF_ENV"
echo "  WERF_NAMESPACE:  $WERF_NAMESPACE"
echo "  DOMAIN:          $DOMAIN"
echo "  DOMAIN2:         $DOMAIN2"
echo "  DATABASE_URL:    ${DATABASE_URL:-—}"
echo "  WERF_REPO:       $WERF_REPO"
echo "  кластер:         $CLUSTER_URL (контекст $KUBE_CONTEXT)"
echo "  теги образов:    $WERF_ADD_CUSTOM_TAG_BRANCH${WERF_ADD_CUSTOM_TAG_LATEST:+, $WERF_ADD_CUSTOM_TAG_LATEST}"
echo "  проверка ответа: $HEALTH_URL"

echo
echo "== Что выкатывается"
echo "  коммит:          ${LOCAL:0:8} $(git log -1 --pretty=%s)"
if [ -n "$IS_PRODUCTION" ]; then
  echo "  текущий тег:     $CURRENT_TAG"
  if [ -n "$DEPLOY_ONLY" ]; then
    echo "  новый тег:       не выпускается (--deploy-only)"
  else
    echo "  новый тег:       $NEW_TAG ($BUMP)"
    echo "  войдёт в релиз:"
    git log --oneline "$CURRENT_TAG..HEAD" | sed 's/^/    /'
  fi
else
  echo "  тег:             не выпускается — версии нумеруются только на production"
fi

if [ -n "$DRY_RUN" ]; then
  echo
  echo "== Будет выполнено (--dry-run: ничего не запускается)"
fi

# --- выпуск тега --------------------------------------------------------------------------------

if [ -n "$IS_PRODUCTION" ] && [ -z "$DEPLOY_ONLY" ]; then
  echo
  # Заметки собираются из замерженных PR — тем же механизмом, что кнопка «Generate release notes».
  # Граница задаётся явно: по именам тегов GitHub однажды выбрал не тот предыдущий.
  if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
    run gh release create "$NEW_TAG" \
      --target "$LOCAL" \
      --title "Release $NEW_TAG" \
      --generate-notes \
      --notes-start-tag "$CURRENT_TAG"
  else
    echo "gh недоступен — тег ставится без заметок к релизу"
    run git tag -a "$NEW_TAG" -m "Release $NEW_TAG" "$LOCAL"
    run git push origin "$NEW_TAG"
  fi
fi

# --- сборка и выкатка ---------------------------------------------------------------------------

export WERF_ENV WERF_NAMESPACE WERF_REPO
export WERF_KUBE_CONTEXT="$KUBE_CONTEXT"
export WERF_SET_DOMAIN="env.DOMAIN=$DOMAIN"
export WERF_SET_DOMAIN2="env.DOMAIN2=$DOMAIN2"
export WERF_SET_BASE_URL="env.BASE_URL=https://$DOMAIN"
export WERF_SET_BASE_URL2="env.BASE_URL2=https://$DOMAIN2"
export WERF_SET_DATABASE_URL="env.DATABASE_URL=$DATABASE_URL"
export WERF_ADD_CUSTOM_TAG_BRANCH
[ -n "$WERF_ADD_CUSTOM_TAG_LATEST" ] && export WERF_ADD_CUSTOM_TAG_LATEST
[ "$DOCKER_BUILDKIT" = "true" ] && export DOCKER_BUILDKIT=1

echo
echo "+ werf cr login -u $REGISTRY_USER -p <токен> $REGISTRY_HOST"
if [ -z "$DRY_RUN" ]; then
  werf cr login -u "$REGISTRY_USER" -p "$REGISTRY_TOKEN" "$REGISTRY_HOST" ||
    die "вход в реестр $REGISTRY_HOST не прошёл — проверьте права токена (нужен write:packages)"
fi

NAMESPACE_COMMAND="werf kubectl --context $KUBE_CONTEXT create namespace $WERF_NAMESPACE --dry-run=client -o yaml"
NAMESPACE_COMMAND="$NAMESPACE_COMMAND | sed '/^metadata:/a\\ \\ labels: {\"autocert.step.sm\":\"enabled\"}'"
NAMESPACE_COMMAND="$NAMESPACE_COMMAND | werf kubectl --context $KUBE_CONTEXT apply -f -"
run_shell "$NAMESPACE_COMMAND"

if [ "$BUILD_ONLY" = "true" ]; then
  run werf build
  echo "BUILD_ONLY: образы собраны и выложены, выкатка не запускалась."
  exit 0
fi

run werf converge
run werf kubectl --context "$KUBE_CONTEXT" label namespace --overwrite "$WERF_NAMESPACE" autocert.step.sm=enabled

# --- приложение отвечает ------------------------------------------------------------------------

# Успешный converge означает лишь «манифесты применены»: под может бесконечно перезапускаться на
# миграции, и по коду возврата это неотличимо от рабочей выкатки. Поэтому проверяем ответ.
HEALTH_WAIT_SECONDS="${DEPLOY_HEALTH_WAIT:-600}"
if [ -n "$DRY_RUN" ]; then
  echo "+ curl $HEALTH_URL — ждать ответа 2xx/3xx до $((HEALTH_WAIT_SECONDS / 60)) минут"
  echo
  echo "--dry-run: ничего не выполнено."
  [ "$PREFLIGHT_FAILED" = "1" ] && echo "Предполётные проверки НЕ пройдены — на боевом запуске это отказ."
  exit 0
fi

echo
echo "Жду, пока приложение ответит: $HEALTH_URL"
waited=0
while :; do
  CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$HEALTH_URL" || echo "000")
  case "$CODE" in
    2* | 3*)
      echo "Приложение отвечает ($CODE). Выкатка $ENVIRONMENT${NEW_TAG:+ $NEW_TAG} завершена."
      exit 0
      ;;
  esac
  [ "$waited" -ge "$HEALTH_WAIT_SECONDS" ] &&
    die "ПРИЛОЖЕНИЕ НЕ ПОДНЯЛОСЬ за $((HEALTH_WAIT_SECONDS / 60)) минут: $HEALTH_URL отвечает $CODE.
       Выкатка при этом прошла — значит под не стартует, чаще всего это миграция. Смотреть:
       werf kubectl --context $KUBE_CONTEXT -n $WERF_NAMESPACE logs -l app=$WERF_PROJECT -c app --tail=50"
  echo "  ещё не отвечает ($CODE), жду… (${waited}s)"
  sleep 15
  waited=$((waited + 15))
done
