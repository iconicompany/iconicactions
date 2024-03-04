# iconicactions

## Configure secrets

Example script to configure repo secrets:

```
cat $HOME/.werf/global_secret_key | gh secret set WERF_SECRET_KEY
```

## Example usage

See .github/workflows/deployment-*.yaml
Copy to project, replace `uses: iconicompany/werfactions/.github/workflows/deployment.yml@main`
