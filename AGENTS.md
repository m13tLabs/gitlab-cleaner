# gitlab-cleaner

Deletes stale branches across all GitLab projects a token's user can access. One bash
script on top of `glab api`, shipped as a Docker image and a GitLab CI/CD component.
GitHub (`origin`) is the primary repo; GitLab hosts the component (mirror).

- `gitlab-cleaner`: the CLI. Options have `CLEANER_*` env equivalents (the component
  passes its inputs that way). Dry run is the default and must stay the default.
- `Dockerfile`: Alpine + glab copied from `gitlab/glab` + the script.
- `templates/cleanup-branches.yml`: the component. Its `version` default carries the
  `# x-release-version` marker that the Release workflow's `bump_command` rewrites; keep it.
- `tests/gitlab-cleaner.bats`: runs the script against a stub `glab`. Never test against a
  real instance with `--execute`.
- `.github/workflows/`: CI and release via `m13tLabs/gh-actions-templates` docker templates.
- `.gitlab-ci.yml`: the GitLab mirror's pipeline (lint + component from `$CI_COMMIT_SHA`).

## Rules

- Before done: `shellcheck gitlab-cleaner`, `bats tests/`, `yamllint -c .yamllint.yml .`.
- A changed component input needs its `description:` and the README table updated. The
  spec `description` must stay under 256 characters (GitLab rejects longer ones).
- Never delete default or protected branches, and keep skipping branches with open MRs by
  default.
