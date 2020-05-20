![Terrafirm diagram](architecture.png)
# terrafirm
Terrafirm performs integration tests of [Watchmaker](https://github.com/plus3it/watchmaker) using Terraform to launch Windows and Linux instances.

Terrafirm can be run locally or with [AWS CodeBuild](https://aws.amazon.com/codebuild/). In order to use it, you will need AWS credentials and to provide environment variables.

## May 2020 Changes

* Previously, `pkg` was used in S3 prefixes, environment variables, and code to indicate something related to standalone packages. Now `sa` is used for that purpose.
* To maintain better consistency with the way Terraform displays things during creation and destruction (e.g., `aws_instance.lx_src["rhel6"]: Still creating...`), refer to instance types and OSs as `<instance type>-<OS>` (e.g., `lx_src-rhel6`, `win_sa-win19`). This nomenclature is consistently used in error messages, log files, S3 prefixes, EC2 instance names, and code.
* You can create multiples of the test instances by setting the `TF_VAR_tfi_instance_multiplier` to a value greater than 1. See an example below of using the multiplier. **Caution**: This could result in many instances being created. For example, if all instances are chosen and you use a multiplier of 20, 282 instances would be created!
* A GNUMakefile now provides shortcuts for Terrafirm tasks:
  - `make` (a/k/a `make again`) - using environment variables or a .env file, apply the configuration (perform init if needed)
  - `make clean` - destroy the configuration
  - `make fresh` - `clean` actions plus delete the log, state files, and provider plugins
  - `make neat` - format the .tf files
  - `make state` - show what is in the Terraform state
  - `make count` - count the items in the Terraform state

## Instance Test Options

The `TF_VAR_tfi_instances` environment variable can be set to one or more the following values, where `lx`/`win` refers to the Linux or Windows platforms, `sa`/`src` refers to a standalone package or from source test, and the part after the dash refers to the operating system (e.g., `centos6`):

* `lx_sa-centos6`
* `lx_sa-centos7`
* `lx_sa-rhel6`
* `lx_sa-rhel7`
* `lx_src-centos6`
* `lx_src-centos7`
* `lx_src-rhel6`
* `lx_src-rhel7`
* `win_sa-win12`
* `win_sa-win16`
* `win_sa-win19`
* `win_src-win12`
* `win_src-win16`
* `win_src-win19`

To set the `TF_VAR_tfi_instances` environment variable in Bash-like shells, use this syntax:

```console
export TF_VAR_tfi_instances='["lx_src-rhel6","win_sa-win12"]'
```

When the `TF_VAR_tfi_instance_multiplier` variable is set to a value greater than 1, multiple of each instance requested in `TF_VAR_tfi_instances` will be created.

**Caution**: This could result in many instances being created. For example, if all instances are chosen and you use a multiplier of 20, 282 instances would be created!

This is an example of using the `TF_VAR_tfi_instance_multiplier` variable. Given these environment variables:

```console
export TF_VAR_tfi_instances='["lx_src-rhel6","win_sa-win12"]'
export TF_VAR_tfi_instance_multiplier=2'
```

The result is five instances being created, two Linux from source test instances, two Windows standalone package test instances, and the Windows standalone package builder.

## TERRAFIRM ENVIRONMENT VARIABLES

Variable | Default | Req/Opt (in CodeBuild) | Description
--- | --- | --- | ---
`TF_VAR_tfi_az` | us-east-1c | optional | AZ to use for tests.
`TF_VAR_tfi_subnet_id` | [empty] | optional | Subnet to use. CodeBuild instance must be able to access.
`TF_VAR_tfi_instances` | [empty] | optional | See above for details on setting this variable.
`TF_VAR_tfi_instance_multiplier` | 1 | optional | Number of each instance type to create.
`TF_VAR_tfi_rm_user` | Administrator | optional | Username to use when connecting via WinRM to Windows instances
`TF_VAR_tfi_ssh_user` | root | optional | Username to use when connecting via SSH to Linux instances.
`TF_VAR_tfi_instance_profile` | [empty] | optional | IAM instance profile to be used in provisioning resources.
`TF_VAR_tfi_assign_public_ip` | false | optional | Whether or not to assign a public IP to the instances.
`TF_VAR_tfi_win_instance_type` | t2.large | optional | AWS instance type for Windows instances.
`TF_VAR_tfi_lx_instance_type` | t2.medium | optional | AWS instance type for Linux instances.
`TF_VAR_tfi_git_repo` | https://github.com/plus3it/watchmaker.git | optional | Git repository to use in getting watchmaker code.
`TF_VAR_tfi_git_ref` | develop | optional | Branch or pull request number to use in getting watchmaker code.
`TF_VAR_tfi_common_args` | -n --log-level debug | optional | Command line arguments used when installing Watchmaker on Windows and Linux.
`TF_VAR_tfi_win_args` | --log-dir=C:\\Watchmaker\\Logs | optional | Command line arguments used when installing Watchmaker on Windows.
`TF_VAR_tfi_lx_args` | --log-dir=/var/log/watchmaker | optional | Command line arguments used when installing Watchmaker on Linux.
`TF_VAR_tfi_win_userdata_log` | C:\\Temp\\userdata.log | optional | File path for Watchmaker log on Windows.
`TF_VAR_tfi_lx_userdata_log` | /var/log/userdata.log | optional | File path for Watchmaker log on Linux.
`TF_VAR_tfi_s3_bucket` | mybucket | optional | S3 bucket to place logs from installs and output.
`TF_VAR_tfi_codebuild_id` | none | optional | CodeBuild build ID (helpful in identifying jobs).
`TF_VAR_tfi_docker_slug` | none | optional | Docker container to use in building standalones.
`TF_VAR_tfi_aws_region` | us-east-1 | optional | Region where tests should be performed.
`TF_VAR_tfi_debug` | 1 | optional | Whether or not to debug.
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
