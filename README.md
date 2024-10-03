# iconicactions

## One line installations script

Run this command in project dir:

`curl -Lo - https://github.com/iconicompany/iconicactions/raw/main/install.sh | bash -`

## Configure secrets
Example script to configure repo secrets:

```
cat $HOME/.werf/global_secret_key | gh secret set WERF_SECRET_KEY
```

## Example usage

See .github/workflows/deployment-*.yaml
Copy to project, replace `uses: iconicompany/iconicactions/.github/workflows/deployment.yml@main`

## Use step certificates in Dockerfile

Set COPY_STEP_CERT to true and create werf-giterminism.yaml:

```
giterminismConfigVersion: 1
config:
  dockerfile:
    allowContextAddFiles:
    - .step/
```
