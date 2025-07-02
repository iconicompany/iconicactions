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

