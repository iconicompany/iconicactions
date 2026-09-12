# iconicactions

## Установка werf

Выполнить команду (установит в /usr/local/bin):

`curl -Lo- https://raw.githubusercontent.com/iconicompany/osboxes/refs/heads/master/ubuntu/apps/werf.sh | bash`

## Логин в ghcr.io

Получить токен https://github.com/settings/tokens с доступом к пакетам (`read:packages`) и указать его в качестве пароля:

`docker login ghcr.io`

## Настройка репозитория

Выполнить команду в репозитории, она создаст осноые файлы (werf.yaml, .helm, actions)

`curl -Lo - https://github.com/iconicompany/iconicactions/raw/main/install.sh | bash -`

Входная точка сборки .github/workflows/deployment-${ENV}.yaml. 

## Настроить ключ шифрования для секретов

Получит у админа файл .werf_secret_key, добавить его в .gitignore и положить в корень репы.
Чтобы прописать секрет в github actions выполнить: `cat .werf_secret_key | gh secret set WERF_SECRET_KEY`. Требуются права owner.

Для редактирования секретов: `werf helm secret file edit .helm/secret/env-testing`


## Локальная сборка и выкатка

`scripts/werf.sh` собирает и выкатывает проект с машины — тем же порядком,
что делает `deployment.yml` в Actions: вход в реестр, namespace с меткой `autocert.step.sm`,
`werf converge`, метка namespace. Настройки берутся из
`.github/workflows/deployment-<окружение>.{yml,yaml}` самого проекта, чтобы локальная выкатка и CI
не разъезжались. В репозиториях продукта своих копий этих скриптов нет намеренно, и обёрток в
`package.json` тоже: размноженная по проектам команда релиза расходится в каждом по-своему.

```bash
ln -s ~/work/iconicactions/scripts/werf.sh    ~/bin/werf.sh      # один раз
ln -s ~/work/iconicactions/scripts/actions.sh ~/bin/actions.sh

werf.sh production --dry-run   # план целиком: настройки, версия, все команды. Ничего не делает
werf.sh production             # версия → тег → сборка → выкатка → проверка, что приложение отвечает
werf.sh production minor
werf.sh production --ghcr      # образы в ghcr, как делал CI (по умолчанию — реестр на этой машине)
werf.sh testing                # стенд текущей ветки: сборка и выкатка, без тега
```

**Образы по умолчанию идут в локальный реестр, а не в ghcr.** Пуш в ghcr — единственное долгое
место выкатки: замер 11.09.2026 — образ 1.9 ГБ не уложился туда за 20 минут, тогда как локальный
путь дал 6.3 мин сборки и 2.1 мин переноса. Стадии ложатся в `registry:2` на `localhost:5000` (без
TLS и учётных данных), образ уезжает на ноду по ssh прямо в containerd, converge идёт
`--skip-build`. Режим требует одной ноды в кластере: импорт кладёт образ в containerd одной машины.
Образ на ноде закрепляется (`io.cri-containerd.pinned`), иначе kubelet вычистит его между импортом
и стартом пода; закрепление предыдущего при этом снимается, иначе диск ноды кончится молча.

## Выключить и включить воркфлоу

`scripts/actions.sh` снимает и возвращает триггеры **правкой `on:`**, а не переименованием файла.

```bash
actions.sh status                     # какие воркфлоу есть, чем запускаются и какие выключены
actions.sh off deployment-production  # снять триггеры, оставив ручной запуск
actions.sh on  deployment-production  # вернуть ровно то, что было
```

Снятое сохраняется комментарием над `on:`, поэтому возврат даёт прежний файл байт в байт, а не
пересказ по памяти. Переименование в `.txt` для этого не годится: файл воркфлоу — ещё и источник
настроек выкатки, и переименованный он заставляет искать себя по расширениям, то есть выключение
Actions начинает молча ломать соседний инструмент.

Окружение — обязательный первый аргумент, умолчания у него нет. Версия, тег и требование «с main и
вровень с origin/main» — только у `production`. Токен ghcr берётся из `GITHUB_TOKEN` или `gh auth token`.
