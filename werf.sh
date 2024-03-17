DOCKER_BUILDKIT=true \
WERF_ENV=main \
WERF_SET_DOMAIN=env.DOMAIN=main.iconicompany.icncd.ru \
WERF_REPO=ghcr.io/iconicompany/iconicactions/iconicactions \
werf $*
