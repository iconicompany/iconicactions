WORK_DIR=`mktemp -d`
curl -Lo $WORK_DIR/iconicactions.zip https://github.com/iconicompany/iconicactions/archive/refs/heads/main.zip
unzip $WORK_DIR/iconicactions.zip -d $WORK_DIR
TARGET_PROJECT=$(basename $(readlink -f .))
grep -Rl iconicactions $WORK_DIR/iconicactions-main|xargs sed -i "s/iconicactions/$TARGET_PROJECT/g"
mkdir -p .github/workflows/
sed -i 's^./.github/workflows/deployment.yml^iconicompany/iconicactions/.github/workflows/deployment.yml@main^' $WORK_DIR/iconicactions-main/.github/workflows/deployment-*.yml
cp $WORK_DIR/iconicactions-main/.github/workflows/deployment-*.yml .github/workflows/
# werf.sh больше не раздаётся проектам: команда выкатки одна на платформу —
# iconicactions/scripts/werf.sh (симлинк ~/bin/werf.sh), а настройки она берёт из deployment-<окружение>.yml.
cp -r $WORK_DIR/iconicactions-main/{.helm,werf.yaml,build.sh,runit.sh,Dockerfile} .
