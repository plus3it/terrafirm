![Terrafirm diagram](architecture.png)
# terrafirm
Terrafirm launches Windows and Linux instances and installs [Watchmaker](https://github.com/plus3it/watchmaker) to test that it installs and runs.

This project is designed to work with [AWS CodeBuild](https://aws.amazon.com/codebuild/). In order to use it, you will need to provide environment variables in your CodeBuild project.

## ENVIRONMENT VARIABLES EXPECTED BY TERRAFIRM

Variable | Default | Req/Opt (in CodeBuild) | Description
--- | --- | --- | ---
`TF_VAR_tfi_subnet_id` | [empty] | optional | Whether or not to use a subnet. CodeBuild instance must be able to access.
`TF_VAR_tfi_win_instances` | [empty] | optional | Acceptable values are "win08", "win12", and/or "win16" (comma separated list). If none are wanted, remove variable from CodeBuild.
`TF_VAR_tfi_lx_instances` | [empty] | optional | Acceptable values are "centos6", "centos7", "rhel6" and/or "rhel7" (comma separated list). If none are wanted, remove variable from CodeBuild.
`TF_VAR_tfi_rm_user` | Administrator | optional | username to use when connecting via WinRM to Windows instances
`TF_VAR_tfi_ssh_user` | root | optional | Which username to use when connecting via SSH to Linux instances.
`TF_VAR_tfi_instance_profile` | [empty] | optional | Instance profile to be used in provisioning resources. This is generally the same as the role if the role is an EC2 role.
`TF_VAR_tfi_assign_public_ip` | false | optional | Whether or not to assign a public IP to the instances built by Terraform.
`TF_VAR_tfi_win_instance_type` | t2.medium | optional | AWS instance type for Windows instances.
`TF_VAR_tfi_lx_instance_type` | t2.micro | optional | AWS instance type for Linux instances.
`TF_VAR_tfi_git_repo` | https://github.com/plus3it/watchmaker.git | optional | Which git repository to use in getting watchmaker code.
`TF_VAR_tfi_git_ref` | master | optional | Which branch or pull request number of the repository to use in getting watchmaker code.
`TF_VAR_tfi_common_args` | -n --log-level debug | optional | Command line arguments used when installing Watchmaker (Windows/Linux).
`TF_VAR_tfi_win_args` | --log-dir=C:\\Watchmaker\\Logs | optional | Command line arguments used when installing Watchmaker (Windows).
`TF_VAR_tfi_lx_args` | --log-dir=/var/log/watchmaker | optional | Command line arguments used when installing Watchmaker (Linux).
`TF_VAR_tfi_s3_bucket` | mybucket | optional | Which S3 bucket to place logs from installs and output from Terraform.
`TF_VAR_tfi_docker_slug` | none | optional | Which Docker container to use in building standalones.
`TF_DESTROY_AFTER_TEST` | true | optional | Whether or not to destroy all resources created after the test. (WARNING: Depending on failure, Terraform may not always be able to destroy provisioned resources.)
`TF_LOG` | DEBUG | optional | Log level of Terraform.
`TF_LOG_PATH` | terraform.log | optional | File where Terraform log is stored.

## Development Paths

Terrafirm performs integration tests of Watchmaker. Development of Terrafirm also involves testing: _Terrafirm_ testing. Keep these development paths separate to avoid confusion.

### Terrafirm development, _Terrafirm_ testing

Local testing of a Terrafirm branch involves checking out the development branch on the local system. Environment variables do not indicate the correct Terrafirm reference to test because you have used Git to put the correct Terrafirm code in play on your local development system.

CodeBuild testing of a remote Terrafirm branch involves commenting `go codebuild go` on a _Terrafirm_ repository pull request. Through the Terrafirm webhook, the correct Git reference to Terrafirm is passed to CodeBuild and CodeBuild fetches that Terrafirm reference. You can verify which Terrafirm reference was used by checking the `Build details` of an individual build in Codebuild. This will list, for example, `Source provider: GitHub, Repository: plus3it/terrafirm, Source version: pr/55`.

Additionally, remember that the Terrafirm reference (e.g., pull request) to test is used either on your local system or the CodeBuild test instance but not on each EC2 instance built though Terraform.

### Watchmaker development, _Watchmaker_ testing

On the other hand, integration testing of Watchmaker begins by commenting `go codebuild go` on a _Watchmaker_ repository pull request. The Watchmaker-Terrafirm webhook will set an environment variable to pass the correct Watchmaker reference (e.g., pull request #330) to Terrafirm. On each server that Terrafirm builds, the Watchmaker reference will be used when retrieving Watchmaker with Git.

In contrast to Terrafirm development, the Watchmaker reference (e.g., pull request) to test is used on each EC2 instance built through Terraform but is not used either on your local system or the CodeBuild test instance.
