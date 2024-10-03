#/bin/bash
docker run -it --rm --env-file .env -p 3000:3000 \
  -v $HOME/.step/certs/root_ca.crt:/var/run/autocert.step.sm/root.crt \
  -v $HOME/.step/certs/my.crt:/var/run/autocert.step.sm/site.crt \
  -v $HOME/.step/certs/my.key:/var/run/autocert.step.sm/site.key \
  -v $HOME/.step/certs/my.p12:/var/run/autocert.step.sm/site.p12 \
  -v $HOME/.step/certs/my.pem:/var/run/autocert.step.sm/site.pem \
  --add-host=host.docker.internal:host-gateway \
  iconicactions $*
