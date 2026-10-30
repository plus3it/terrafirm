# Agent Instructions

Before starting any task in this repository:

1. Run `make agents/sync`. It writes the shared Plus3 IT instructions for this repository's tardigrade-ci version to `.agents/plus3it/AGENTS.md`.
2. Read `.agents/plus3it/AGENTS.md` and follow it together with this file. If the sync fails, tell the user, and don't guess the conventions.

These rules always apply, even without the shared instructions:

- Don't push, open pull requests, publish releases, or apply infrastructure changes unless the user asks. List those steps for a person in your final report.
- Don't edit files under `.agents/plus3it/`; they are generated and overwritten by the sync.

@.agents/plus3it/AGENTS.md

## Repository-specific

### Purpose

Terrafirm performs integration tests of [Watchmaker](https://github.com/plus3it/watchmaker) using Terraform to launch Windows and Linux builds. It can be run locally or with AWS CodeBuild, and it needs AWS credentials and environment variables (see the README) to do so.

This repository is a Terraform configuration that launches real test instances. It is not a reusable module, so the conventions used by Plus3 IT's Terraform module repositories (README table generation, `moved` blocks, mockstack tests) do not apply here.

### What not to run

Terrafirm creates and destroys real AWS resources. Do not run:

- `make` or `make again` (the default target): it runs `terraform apply` with `-auto-approve`.
- `make clean` or `make fresh`: they run `terraform destroy` with `-auto-approve`, and `fresh` also deletes the local state files, the provider plugins, and the log.
- The integration tests in `.github/workflows/test.yml`: they run against real AWS on CodeBuild runners. A person starts them, with `workflow_dispatch` or with a pull request review comment that contains `/build`.

List these as steps for a person in your final report.

### Checks you can run

- `make lint`, the tardigrade-ci lint targets.
- `make valid`: runs `terraform init` if `.terraform/` is missing, then `terraform validate`; it sources `.env` first if one exists (`.env` is not committed).
- `make neat`: runs `terraform fmt`.
- `make state` and `make count` read the Terraform state; use them only when asked.

### Files

- `GNUmakefile` — the repository's makefile (there is no `Makefile`); it includes tardigrade-ci and adds `again` (the default target), `valid`, `clean`, `fresh`, `neat`, `state`, and `count`
- `templates/` — Linux and Windows user-data and test scripts used by the instances
- `buildspec.yml` — CodeBuild build specification
- `.github/actions/test/` — composite action that runs the integration test; used by `.github/workflows/test.yml`
- `example.env` — example environment variables

### Testing

There are no tests an agent can run here: the integration tests need real AWS and a person starts them. Run `make lint` and `make valid`.

### CI/CD

Pull requests run `lint.yml`. `test.yml` runs the integration tests on demand, as described above.

### Releases

This repository is not versioned or released: it has no release workflow, `.bumpversion.cfg`, or `CHANGELOG.md`. Skip the version-bump steps in "Before you finish".
