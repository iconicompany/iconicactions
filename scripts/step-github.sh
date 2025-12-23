#!/bin/bash
set -e -v

# 1. Определение переменных и путей
export STEPPATH=$HOME/.step
export STEPCERTPATH=$HOME/.step/certs
export STEP_PROVISIONER=${STEP_PROVISIONER:-"github-actions"}
export STEP_NOT_AFTER=${STEP_NOT_AFTER:-"1h"}
OIDC_CLIENT_ID=${OIDC_CLIENT_ID:-"api://SmallstepCAProvisioner"}

CERT_LOCATION=${STEPCERTPATH}/my.crt
KEY_LOCATION=${STEPCERTPATH}/my.key
PEM_LOCATION=${STEPCERTPATH}/my.pem

PGCERTPATH=$HOME/.postgresql
CERT_LOCATION_PG=${PGCERTPATH}/postgresql.crt
KEY_LOCATION_PG=${PGCERTPATH}/postgresql.key
CA_LOCATION=${STEPPATH}/certs/root_ca.crt
CA_LOCATION_PG=${PGCERTPATH}/root.crt

# 2. Установка step CLI (если не найден)
if ! command -v step > /dev/null; then
    curl -Lo step-cli_amd64.deb https://dl.smallstep.com/gh-release/cli/gh-release-header/v0.29.0/step-cli_0.29.0-1_amd64.deb
    sudo dpkg -i step-cli_amd64.deb
    rm -f step-cli_amd64.deb
fi

# 3. Bootstrap и получение токена
step ca bootstrap --force
echo ACTIONS_ID_TOKEN_REQUEST_TOKEN=${ACTIONS_ID_TOKEN_REQUEST_TOKEN}

TOKEN=$(curl -s -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=${OIDC_CLIENT_ID}" | jq -r .value)

# 4. Верификация токена (для отладки)
curl -sLO https://token.actions.githubusercontent.com/.well-known/jwks
echo $TOKEN | step crypto jwt verify \
    --jwks jwks \
    --aud ${OIDC_CLIENT_ID} \
    --iss "https://token.actions.githubusercontent.com"

SUBSCRIBER=$(echo $TOKEN | step crypto jwt inspect --insecure | jq -r .payload.sub)

# 5. Создание директорий и генерация сертификата
mkdir -p $STEPCERTPATH $PGCERTPATH
step ca certificate $SUBSCRIBER ${CERT_LOCATION} ${KEY_LOCATION} --token "$TOKEN" --force
step certificate inspect ${CERT_LOCATION}

# Объединение в PEM и создание симлинков для Postgres
cat ${CERT_LOCATION} ${KEY_LOCATION} > ${PEM_LOCATION}
ln -vfs ${KEY_LOCATION} ${KEY_LOCATION_PG}
ln -vfs ${CERT_LOCATION} ${CERT_LOCATION_PG}
ln -vfs ${CA_LOCATION} ${CA_LOCATION_PG}

# 6. Подготовка переменных для Kubeconfig
CERTIFICATEAUTHORITY_BASE64=$(cat ${HOME}/.step/certs/root_ca.crt | base64 -w0)
CERTIFICATE_BASE64=$(cat ${STEPCERTPATH}/my.crt | base64 -w0)
PRIVATEKEY_BASE64=$(cat ${STEPCERTPATH}/my.key | base64 -w0)

mkdir -p $HOME/.kube
cat << EOF > $HOME/.kube/config
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ${CERTIFICATEAUTHORITY_BASE64}
    server: ${CLUSTER_URL}
  name: default
contexts:
- context:
    cluster: default
    user: default
  name: default
current-context: default
kind: Config
preferences: {}
users:
- name: default
  user:
    client-certificate-data: ${CERTIFICATE_BASE64}
    client-key-data: ${PRIVATEKEY_BASE64}
EOF

# 7. Вывод переменных в GITHUB_OUTPUT
# Это позволит использовать их в других шагах (steps.bootstrap.outputs...)
echo "--- Exporting outputs ---"
CERTIFICATE_CN=$(step certificate inspect ${CERT_LOCATION}  --format=json | jq -r .subject.common_name[0])

# Вывод CN
echo "CERTIFICATE_CN=$CERTIFICATE_CN" >> $GITHUB_OUTPUT

# Вывод путей к файлам (Добавлено по запросу)
echo "CA_LOCATION=${CA_LOCATION}" >> $GITHUB_OUTPUT
echo "KEY_LOCATION=${KEY_LOCATION}" >> $GITHUB_OUTPUT
echo "CERT_LOCATION=${CERT_LOCATION}" >> $GITHUB_OUTPUT

# Вывод Kubeconfig
echo 'KUBE_CONFIG<<EOF' >> $GITHUB_OUTPUT
cat $HOME/.kube/config | base64 >> $GITHUB_OUTPUT
echo 'EOF' >> $GITHUB_OUTPUT
