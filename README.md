![Terrafirm diagram](architecture.png)
# terrafirm
Terrafirm performs integration tests of [Watchmaker](https://github.com/plus3it/watchmaker) using Terraform to launch Windows and Linux builds.

Terrafirm can be run locally or with [AWS CodeBuild](https://aws.amazon.com/codebuild/). In order to use it, you will need AWS credentials and to provide environment variables.

## May 2020 Changes

* Previously, `pkg` was used in S3 prefixes, environment variables, and code to indicate something related to standalone packages. Now `standalone` is used for that purpose.
* There are two separate input variables for source and standalone builds: `TF_VAR_source_builds` and `TF_VAR_standalone_builds`. See below for more information.
* A GNUMakefile now provides shortcuts for Terrafirm tasks:
  - `make` (a/k/a `make again`) - using environment/Terraform variables or a .env file, apply the configuration (perform init if needed)
  - `make valid` - using environment/Terraform variables or a .env file, validate the configuration (perform init if needed)
  - `make clean` - destroy the configuration
  - `make fresh` - `clean` actions plus delete the log, state files, and provider plugins
  - `make neat` - format the .tf files
  - `make state` - show what is in the Terraform state
  - `make count` - count of the items in the Terraform state
* If you prefer to disable color in Terraform's output while using the GNUMakefile, set the environment variable `COLOR_OPTION` to `-no-color`.

## Instance Test Options

Several environment variables allow you to control what builds Terrafirm runs. Each of them is described in more detail in this section.

### TF_VAR_source_builds and TF_VAR_standalone_builds

To pick specific operating system builds, set the `TF_VAR_source_builds` and `TF_VAR_standalone_builds` environment variables to one or more the following operating system values. In the variable names, `standalone`/`source` refers to the standalone package test or the from source test.

* `centos7`
* `rhel7`
* `win12`
* `win16`
* `win19`

For example, to set the `TF_VAR_source_builds` environment variable in Bash-like shells, use this syntax:

```console
export TF_VAR_source_builds='["centos7","win12"]'
```

You would expect Terraform's output to include lines like these if you run Terrafirm with these settings:

```console
aws_instance.source_build["win12"]: Still creating... [1m10s elapsed]
aws_instance.source_build["centos7"]: Still creating... [1m10s elapsed]
```

## TERRAFIRM ENVIRONMENT VARIABLES

Variable | Default | Req/Opt (in CodeBuild) | Description
--- | --- | --- | ---
`TF_VAR_assign_public_ip` | false | optional | Whether or not to assign a public IP to the builds.
`TF_VAR_availability_zone` | us-east-1c | optional | availability_zone to use for builds.
`TF_VAR_aws_region` | us-east-1 | optional | Region where builds should be performed.
`TF_VAR_codebuild_id` | none | optional | CodeBuild build ID (helpful in identifying jobs).
`TF_VAR_common_args` | -n --log-level debug | optional | Command line arguments used when installing Watchmaker on Windows and Linux.
`TF_VAR_debug` | false | optional | Whether or not to debug.
`TF_VAR_docker_slug` | none | optional | Docker container to use in building standalones.
`TF_VAR_git_ref` | main | optional | Branch or pull request number to use in getting watchmaker code.
`TF_VAR_git_repo` | https://github.com/plus3it/watchmaker.git | optional | Git repository to use in getting watchmaker code.
`TF_VAR_instance_profile` | [empty] | optional | IAM instance profile to be used in provisioning resources.
`TF_VAR_lx_args` | --log-dir=/var/log/watchmaker | optional | Command line arguments used when installing Watchmaker on Linux.
`TF_VAR_lx_instance_type` | t2.medium | optional | AWS instance type for Linux builds.
`TF_VAR_lx_userdata_log` | /var/log/userdata.log | optional | File path for Watchmaker log on Linux.
`TF_VAR_s3_bucket` | mybucket | optional | S3 bucket to place logs from installs and output.
`TF_VAR_s3_scan_bucket` | mybucket | optional | S3 bucket where SCAP scans are published if `wam_version` exists.
`TF_VAR_source_builds` | ["win12", "win16", "win19", "rhel7", "centos7"] | optional | See above for details on setting this variable.
`TF_VAR_lx_user` | root | optional | Username to use when connecting via SSH to Linux builds.
`TF_VAR_standalone_builds` | ["win12", "win16", "win19", "rhel7", "centos7"] | optional | See above for details on setting this variable.
`TF_VAR_subnet_id` | [empty] | optional | Subnet to use. CodeBuild instance must be able to access.
`TF_VAR_wam_version` | [empty] | optional | If provided, SCAP scan results will be copied to the S3 bucket under this version number.
`TF_VAR_win_args` | --log-dir=C:\\Watchmaker\\Logs | optional | Command line arguments used when installing Watchmaker on Windows.
`TF_VAR_win_instance_type` | t2.large | optional | AWS instance type for Windows builds.
`TF_VAR_win_user` | Administrator | optional | Username to use when connecting via WinRM to Windows builds
`TF_VAR_win_userdata_log` | C:\\Temp\\userdata.log | optional | File path for Watchmaker log on Windows.
`TF_DESTROY_AFTER_TEST` | true | optional | (CodeBuild only) Whether or not to destroy all resources created after the test. (WARNING: Depending on failure, Terraform may not always be able to destroy provisioned resources.)

## Development Paths

Terrafirm performs integration tests of Watchmaker. Development of Terrafirm also involves testing: _Terrafirm_ testing. Keep these development paths separate to avoid confusion.

### Terrafirm development, _Terrafirm_ testing

Local testing of a Terrafirm branch involves checking out the development branch on the local system. Environment variables do not indicate the correct Terrafirm reference to test because you have used Git to put the correct Terrafirm code in play on your local development system.

CodeBuild testing of a remote Terrafirm branch involves commenting `go codebuild go` on a _Terrafirm_ repository pull request. Through the Terrafirm webhook, the correct Git reference to Terrafirm is passed to CodeBuild and CodeBuild fetches that Terrafirm reference. You can verify which Terrafirm reference was used by checking the `Build details` of an individual build in Codebuild. This will list, for example, `Source provider: GitHub, Repository: plus3it/terrafirm, Source version: pr/55`.

Additionally, remember that the Terrafirm reference (e.g., pull request) to test is used either on your local system or the CodeBuild test instance but not on each EC2 instance built though Terraform.

### Watchmaker development, _Watchmaker_ testing

On the other hand, integration testing of Watchmaker begins by commenting `go codebuild go` on a _Watchmaker_ repository pull request. The Watchmaker-Terrafirm webhook will set an environment variable to pass the correct Watchmaker reference (e.g., pull request #330) to Terrafirm. On each server that Terrafirm builds, the Watchmaker reference will be used when retrieving Watchmaker with Git.

In contrast to Terrafirm development, the Watchmaker reference (e.g., pull request) to test is used on each EC2 instance built through Terraform but is not used either on your local system or the CodeBuild test instance.
