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


## Вход в кластер: KUBE_AUTH

Вход `KUBE_AUTH` в `deployment.yml` задаёт, как workflow входит в k3s:

- `x509` (по умолчанию) — клиентский сертификат step-ca учётки runner, права на весь кластер.
- `broker` — токен ZITADEL учётки `deployer-<продукт>` от ci-broker; пускает только в namespace'ы продукта.

```yaml
jobs:
  deploy:
    uses: iconicompany/iconicactions/.github/workflows/deployment.yml@main
    with:
      KUBE_AUTH: broker
      WERF_NAMESPACE: 'iconicompany-{1}'   # должен подходить под deploy.namespace продукта
```

Для `broker` продукт заводится в idevops (`deploy.namespace` в его `deployment.json`, затем `bin/seed <продукт> --apply`),
схема — `/opt/idevops/docs/ci-deploy.md`. Production выкатывается только из тега `v*`.
Брокер сам заводит namespace, поэтому `AUTOCERT_ENABLED` с ним несовместим, а `werf dismiss` не удаляет namespace.
Сертификат step-ca для миграций в PostgreSQL — `COPY_STEP_CERT: true`.
Отказ брокера виден в логе шага «ci-broker token» с причиной.
