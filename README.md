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

`scripts/werf.sh` собирает и выкатывает проект с машины — тем же порядком, что делает
`deployment.yml` в Actions: вход в ghcr, namespace с меткой `autocert.step.sm`, `werf converge`,
метка namespace. Настройки берёт из `.github/workflows/deployment-<окружение>.{yml,yaml,txt}`
самого проекта, чтобы локальная выкатка и CI не разъезжались.

```bash
ln -s ~/work/iconicactions/scripts/werf.sh ~/bin/werf.sh   # один раз

werf.sh production --dry-run   # план целиком: настройки, версия, все команды. Ничего не делает
werf.sh production             # версия → тег → сборка → выкатка → проверка, что приложение отвечает
werf.sh production minor
werf.sh testing                # стенд текущей ветки: сборка и выкатка, без тега
```

Окружение — обязательный первый аргумент, умолчания у него нет. Версия, тег и требование «с main и
вровень с origin/main» — только у `production`. Токен ghcr берётся из `GITHUB_TOKEN` или `gh auth token`.
