# iconicactions

## Установка werf

Выполнить команду (установит в /usr/local/bin)
`curl -Lo- https://raw.githubusercontent.com/iconicompany/osboxes/refs/heads/master/ubuntu/apps/werf.sh | bash`


## Настройка репозитория

Выполнить команду в репозитории, она создаст осноые файлы (werf.yaml, .helm, actions)
Входная точка сборки .github/workflows/deployment-${ENV}.yaml

`curl -Lo - https://github.com/iconicompany/iconicactions/raw/main/install.sh | bash -`

## Настроить ключ шифрования для секретов

```
cat $HOME/.werf/global_secret_key | gh secret set WERF_SECRET_KEY
```

