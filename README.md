# iconicactions

## Установка werf

Выполнить команду (установит в /usr/local/bin):

`curl -Lo- https://raw.githubusercontent.com/iconicompany/osboxes/refs/heads/master/ubuntu/apps/werf.sh | bash`

## Логин в ghcr.io

Получить токен https://github.com/settings/tokens с доступом к пакетам (`read:packages`):

`echo $CR_PAT | docker login ghcr.io -u USERNAME --password-stdin`

## Настройка репозитория

Выполнить команду в репозитории, она создаст осноые файлы (werf.yaml, .helm, actions)
Входная точка сборки .github/workflows/deployment-${ENV}.yaml

`curl -Lo - https://github.com/iconicompany/iconicactions/raw/main/install.sh | bash -`

## Настроить ключ шифрования для секретов

```
cat $HOME/.werf/global_secret_key | gh secret set WERF_SECRET_KEY
```

