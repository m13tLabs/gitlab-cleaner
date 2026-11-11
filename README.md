# gitlab-cleaner

[![CI](https://github.com/m13tLabs/gitlab-cleaner/actions/workflows/ci.yml/badge.svg)](https://github.com/m13tLabs/gitlab-cleaner/actions/workflows/ci.yml)
![Docker Pulls](https://img.shields.io/docker/pulls/m13t/gitlab-cleaner?link=https%3A%2F%2Fhub.docker.com%2Fr%2Fm13t%2Fgitlab-cleaner)

Deletes stale branches across **every GitLab project a token's user can access**, built
on [`glab`](https://gitlab.com/gitlab-org/cli). It ships as a container image and as a
GitLab CI/CD component you can run from a pipeline schedule or by hand.

A branch is stale when its last commit is older than the inactivity period. These are
never deleted:

- the default branch and protected branches (including wildcard protection rules),
- branches that are the source of an open merge request (deleting one closes the MR),
- anything in archived projects, or projects where the user is below Developer.

Dry run is the default everywhere.

## GitLab CI/CD component

```yaml
include:
  - component: $CI_SERVER_FQDN/m13tLabs/gitlab-cleaner/cleanup-branches@<version>
    inputs:
      inactivity: 90d
      dry-run: true
      exclude: '^(release|hotfix)/'   # optional
```

1. Add a masked CI/CD variable `GITLAB_TOKEN`: a personal, group or project access token
   with the `api` scope. The job cleans up every project **that token's user** is a member
   of, so a dedicated bot user or a group access token keeps the scope under control.
2. Create a pipeline schedule (Build > Pipeline schedules), or start the pipeline with
   **Run pipeline**. The job runs only in those two pipeline types by default.
3. Check the job log or the `gitlab-cleaner-report.json` artifact, then switch `dry-run`
   to `false`. To delete once without changing the input, run the pipeline manually with
   the variable `CLEANER_DRY_RUN=false`: pipeline variables override the job's.

### Inputs

| Input | Type | Default | Description |
| --- | --- | --- | --- |
| `inactivity` | string | `90d` | Delete branches whose last commit is older than this: `<n>` plus `h`, `d` (default), `w`, `m` (30 days) or `y` (365 days). |
| `dry-run` | boolean | `true` | Only report the stale branches, delete nothing. |
| `exclude` | string | `""` | Optional regex of branch names that are never deleted, e.g. `^(release\|hotfix)/`. |
| `stage` | string | `test` | Stage of the job. |
| `image` | string | `m13t/gitlab-cleaner` | Image, without the tag. |
| `version` | string | current release | Image tag. |
| `job-name` | string | `cleanup-branches` | Name of the job. |
| `rules` | array | schedule + web | Job `rules`. |

The CLI options below that the component has no input for can still be set as CI/CD
variables (`CLEANER_PROJECTS`, `CLEANER_EXCLUDE_PROJECTS`, …).

## CLI / image

```text
ghcr.io/m13tlabs/gitlab-cleaner:<version>|<major.minor>|latest
m13t/gitlab-cleaner:<version>|<major.minor>|latest
```

`linux/amd64` and `linux/arm64`. `ENTRYPOINT` is `gitlab-cleaner`.

```sh
# report only
docker run --rm -e GITLAB_TOKEN -e GITLAB_HOST=gitlab.example.com \
  m13t/gitlab-cleaner --inactivity 6m

# delete, keeping release branches
docker run --rm -e GITLAB_TOKEN -e GITLAB_HOST=gitlab.example.com \
  m13t/gitlab-cleaner --inactivity 6m --exclude-branches '^release/' --execute
```

The script also runs outside the image with `bash`, `jq` and an authenticated `glab`.

| Option | Env | Default | Description |
| --- | --- | --- | --- |
| `-i, --inactivity` | `CLEANER_INACTIVITY` | `90d` | Inactivity period, `<n>[h\|d\|w\|m\|y]` |
| `-n, --dry-run[=BOOL]` / `-x, --execute` | `CLEANER_DRY_RUN` | `true` | Report only / delete |
| `--min-access-level` | `CLEANER_MIN_ACCESS_LEVEL` | `30` | Minimum access level of the user in a project |
| `--include-open-mr` | `CLEANER_SKIP_OPEN_MR=false` | off | Also delete branches with an open MR |
| `-p, --projects` | `CLEANER_PROJECTS` | | Only projects whose full path matches the regex |
| `--exclude-projects` | `CLEANER_EXCLUDE_PROJECTS` | | Skip projects whose full path matches |
| `-b, --exclude-branches` | `CLEANER_EXCLUDE_BRANCHES` | | Never delete matching branch names |
| `-r, --report` | `CLEANER_REPORT` | | Write a JSON report |

Host: `$GITLAB_HOST`, else `$CI_SERVER_URL` inside GitLab CI, else glab's configured host.
Exit codes: `0` success, `1` at least one deletion failed, `2` bad arguments or no API
access. Projects whose branches or MRs can't be listed are skipped with a warning.

## Development

```sh
shellcheck gitlab-cleaner
bats tests/          # stubs glab, never calls a real instance
docker build -t gitlab-cleaner:dev .
```

## Releasing

Run the **Release** workflow on GitHub (`patch` / `minor` / `major` / `custom`). It bumps
`config.json` and the component's default `version`, updates `CHANGELOG.md` with git-cliff,
pushes the multi-arch image to GHCR and Docker Hub and opens a draft release. The component
is published from the GitLab mirror (`gitlab.com/m13tLabs/gitlab-cleaner`) once the tag
lands there.

## License

MIT, see [LICENSE](LICENSE).
