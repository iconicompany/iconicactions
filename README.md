# werfactions

## Configure secrets

Example script to configure repo secrets:

```
cat $HOME/.werf/registry_password | gh secret set REGISTRY_PASSWORD
cat $HOME/.werf/kube-config-github|base64 |  gh secret set KUBE_CONFIG
cat $HOME/.werf/global_secret_key | gh secret set WERF_SECRET_KEY
```

$HOME/.werf/kube-config-github should contain required contexts (production,testing,etc)

Script to create empty gitlab project to host container registry.:

```
lab project create  `gh repo view --json name,owner -q '.owner.login  + "/"  + .name'`
```

## Example usage

### Production deployment

```
name: Production Deployment
on:
  push:
    tags: ['*']

jobs:

  call-converge:
    uses: iconicompany/werfactions/.github/workflows/deployment.yml@main
    secrets: inherit
    with:
      registry: registry.gitlab.com
      context: production
      domain: iconicompany.ru
```

### Testing deployment

```
name: Testing Deployment
on:
  push:
    branches: ['main','sandbox']

jobs:

  call-converge:
    uses: iconicompany/werfactions/.github/workflows/deployment.yml@main
    secrets: inherit
    with:
      registry: registry.gitlab.com
      context: testing
      domain: ${{ github.head_ref || github.ref_name }}.${{ github.repository_owner }}.icncd.ru
```

### Pull request deployment

Deploy pull request labelled 'Review'

```
name: Pull Request Deployment
on: pull_request

jobs:

  call-converge:
    uses: iconicompany/werfactions/.github/workflows/deployment.yml@main
    secrets: inherit
    with:
      registry: registry.gitlab.com
      context: testing
      domain: ${{ github.head_ref || github.ref_name }}.${{ github.repository_owner }}.icncd.ru

```