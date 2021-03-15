# release-nexus-staging-repo Github Action

This action closes an existing staged repository, and if the sonatype process ends by closing the staged repository properly it will release the artifacts on Maven Central.

# How to use it

Here is an example of how to use this action in your workflows.

```yaml
on: [push]

jobs:
  create_staging_repository:
    #...
  build:
    needs: create_staging_repository
    # ...
  release:
    runs-on: ubuntu-latest
    needs: [create_staging_repository, build]
    if: ${{ always() && needs.build.result == 'success' }}
    steps:
      - name: Release
        uses: nexus-actions/release-nexus-staging-repo@main
        with:
          username: ${{ secrets.SONATYPE_USERNAME }}
          password: ${{ secrets.SONATYPE_PASSWORD }}
          staged_repository_id: ${{ needs.create_staging_repository.outputs.repository-id }}
          [close_only]: 'true'
```

The different arguments are:

- `username`: Your Sonatype username, same the Sonatype Jira one
- `password`: Your Sonatype password, same the Sonatype Jira one
- `staged_repository_id`: The ID of the staged repository to drop.
- `base_url`: The url of your nexus repository, default to OSSRH (https://oss.sonatype.org/service/local/)
- `close_only`: This option disable the auto-release process, default is `'false'`

See the [nexus-actions-demo](https://github.com/nexus-actions/nexus-actions-demo) repo for more details and use cases.

----------

# This action is brought to you by ...

- Martin Bonnin from [Apollo GraphQL](https://www.apollographql.com)
- Romain Boisselle from [Kodein Koders](https://kodein.net)