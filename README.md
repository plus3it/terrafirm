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

* `centos8stream`
* `ol8`
* `rhel8`
* `win16`
* `win19`

For example, to set the `TF_VAR_source_builds` environment variable in Bash-like shells, use this syntax:

```console
export TF_VAR_source_builds='["centos8stream","win19"]'
```

You would expect Terraform's output to include lines like these if you run Terrafirm with these settings:

```console
aws_instance.source_build["win19"]: Still creating... [1m10s elapsed]
aws_instance.source_build["centos8stream"]: Still creating... [1m10s elapsed]
```

<!-- BEGIN TFDOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 0.12 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0 |
| <a name="requirement_http"></a> [http](#requirement\_http) | >= 3.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | >= 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.0 |
| <a name="provider_http"></a> [http](#provider\_http) | >= 3.0 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.0 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | >= 4.0 |

## Resources

| Name | Type |
|------|------|
| [aws_ami.amis](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_subnet.tfi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |
| [aws_vpc.tfi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |
| [http_http.ip](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | n/a | `list(string)` | n/a | yes |
| <a name="input_assign_public_ip"></a> [assign\_public\_ip](#input\_assign\_public\_ip) | n/a | `bool` | `false` | no |
| <a name="input_availability_zone"></a> [availability\_zone](#input\_availability\_zone) | n/a | `string` | `"us-east-1c"` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | n/a | `string` | `"us-east-1"` | no |
| <a name="input_codebuild_id"></a> [codebuild\_id](#input\_codebuild\_id) | n/a | `string` | `""` | no |
| <a name="input_common_args"></a> [common\_args](#input\_common\_args) | n/a | `string` | `"-n --log-level debug"` | no |
| <a name="input_debug"></a> [debug](#input\_debug) | n/a | `bool` | `true` | no |
| <a name="input_docker_slug"></a> [docker\_slug](#input\_docker\_slug) | n/a | `string` | `""` | no |
| <a name="input_git_ref"></a> [git\_ref](#input\_git\_ref) | n/a | `string` | `"main"` | no |
| <a name="input_git_repo"></a> [git\_repo](#input\_git\_repo) | n/a | `string` | `"https://github.com/plus3it/watchmaker.git"` | no |
| <a name="input_instance_profile"></a> [instance\_profile](#input\_instance\_profile) | n/a | `string` | `""` | no |
| <a name="input_lx_args"></a> [lx\_args](#input\_lx\_args) | n/a | `string` | `"--log-dir=/var/log/watchmaker"` | no |
| <a name="input_lx_instance_type"></a> [lx\_instance\_type](#input\_lx\_instance\_type) | n/a | `string` | `"t2.medium"` | no |
| <a name="input_lx_user"></a> [lx\_user](#input\_lx\_user) | n/a | `string` | `"root"` | no |
| <a name="input_lx_userdata_log"></a> [lx\_userdata\_log](#input\_lx\_userdata\_log) | n/a | `string` | `"/var/log/userdata.log"` | no |
| <a name="input_s3_bucket"></a> [s3\_bucket](#input\_s3\_bucket) | n/a | `string` | `"mybucket"` | no |
| <a name="input_scan_s3_url"></a> [scan\_s3\_url](#input\_scan\_s3\_url) | n/a | `string` | `""` | no |
| <a name="input_source_builds"></a> [source\_builds](#input\_source\_builds) | n/a | `list(string)` | <pre>[<br>  "win16",<br>  "win19",<br>  "win22",<br>  "rhel8",<br>  "centos8stream",<br>  "ol8",<br>  "rhel9",<br>  "centos9stream",<br>  "ol9"<br>]</pre> | no |
| <a name="input_standalone_builds"></a> [standalone\_builds](#input\_standalone\_builds) | n/a | `list(string)` | <pre>[<br>  "win16",<br>  "win19",<br>  "win22",<br>  "rhel8",<br>  "centos8stream",<br>  "ol8",<br>  "rhel9",<br>  "centos9stream",<br>  "ol9"<br>]</pre> | no |
| <a name="input_win_args"></a> [win\_args](#input\_win\_args) | n/a | `string` | `"--log-dir=C:\\Watchmaker\\Logs"` | no |
| <a name="input_win_instance_type"></a> [win\_instance\_type](#input\_win\_instance\_type) | n/a | `string` | `"t2.large"` | no |
| <a name="input_win_user"></a> [win\_user](#input\_win\_user) | n/a | `string` | `"Administrator"` | no |
| <a name="input_win_userdata_log"></a> [win\_userdata\_log](#input\_win\_userdata\_log) | n/a | `string` | `"C:\\Temp\\userdata.log"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_build_date_hm"></a> [build\_date\_hm](#output\_build\_date\_hm) | n/a |
| <a name="output_build_date_ymd"></a> [build\_date\_ymd](#output\_build\_date\_ymd) | n/a |
| <a name="output_build_id"></a> [build\_id](#output\_build\_id) | n/a |
| <a name="output_build_slug"></a> [build\_slug](#output\_build\_slug) | n/a |
| <a name="output_builders"></a> [builders](#output\_builders) | n/a |
| <a name="output_private_key"></a> [private\_key](#output\_private\_key) | n/a |
| <a name="output_public_key"></a> [public\_key](#output\_public\_key) | n/a |
| <a name="output_source_builds"></a> [source\_builds](#output\_source\_builds) | n/a |
| <a name="output_standalone_builds"></a> [standalone\_builds](#output\_standalone\_builds) | n/a |
| <a name="output_unique_builds_needed"></a> [unique\_builds\_needed](#output\_unique\_builds\_needed) | n/a |
| <a name="output_winrm_pass"></a> [winrm\_pass](#output\_winrm\_pass) | n/a |

<!-- END TFDOCS -->

## TERRAFIRM ENVIRONMENT VARIABLES

Variable | Default | Req/Opt (in CodeBuild) | Description
--- | --- | --- | ---
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
