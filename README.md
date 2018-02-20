![Terrafirm diagram](architecture.png)
# terrafirm
Terrafirm launches Windows and Linux instances and installs [Watchmaker](https://github.com/plus3it/watchmaker) to test that it installs and runs.

This project is designed to work with [AWS CodeBuild](https://aws.amazon.com/codebuild/). In order to use it, you will need to provide environment variables in your CodeBuild project.

## ENVIRONMENT VARIABLES EXPECTED BY TERRAFIRM

Variable | Default | Req/Opt (in CodeBuild) | Description
--- | --- | --- | ---
`TFI_SUBNET_ID` | [empty] | optional | Whether or not to use a subnet. CodeBuild instance must be able to access.
`TFI_WIN_INSTANCES` | [empty] | optional | Acceptable values are "win08", "win12", and/or "win16" (comma separated list). If none are wanted, remove variable from CodeBuild.
`TFI_LX_INSTANCES` | [empty] | optional | Acceptable values are "centos6", "centos7", "rhel6" and/or "rhel7" (comma separated list). If none are wanted, remove variable from CodeBuild.
`TFI_PS_PUBLIC_KEY` | /path/to/parameter/store | REQUIRED | Name of a PS parameter containing the public key used in creating a Key Pair for use by Terrafirm.
`TFI_PS_PRIVATE_KEY` | /path/to/parameter/store | REQUIRED | Name of a PS parameter containing the private key used in authenticating to instances created with the Key Pair.
`TFI_PS_PASSWD_KEY` | /path/to/parameter/store | REQUIRED | Name of a Parameter Store (PS) parameter containing the password used temporarily in WinRM connection to Windows instances.
`TFI_RM_USER` | Administrator | optional | username to use when connecting via WinRM to Windows instances
`TFI_SSH_USER` | root | optional | Which username to use when connecting via SSH to Linux instances.
`TFI_INSTANCE_PROFILE` | [empty] | optional | Instance profile to be used in provisioning resources. This is generally the same as the role if the role is an EC2 role.
`TFI_ASSIGN_PUBLIC_IP` | false | optional | Whether or not to assign a public IP to the instances built by Terraform.
`TFI_WIN_INSTANCE_TYPE` | t2.medium | optional | AWS instance type for Windows instances.
`TFI_LX_INSTANCE_TYPE` | t2.micro | optional | AWS instance type for Linux instances.
`TFI_GIT_REPO` | https://github.com/plus3it/watchmaker.git | optional | Which git repository to use in getting watchmaker code.
`TFI_GIT_REF` | master | optional | Which branch or pull request number of the repository to use in getting watchmaker code.
`TFI_COMMON_ARGS` | -n --log-level debug | optional | Command line arguments used when installing Watchmaker (Windows/Linux).
`TFI_WIN_ARGS` | --log-dir=C:\\Watchmaker\\Logs | optional | Command line arguments used when installing Watchmaker (Windows).
`TFI_LX_ARGS` | --log-dir=/var/log/watchmaker | optional | Command line arguments used when installing Watchmaker (Linux).
`TFI_DESTROY_AFTER_TEST` | true | optional | Whether or not to destroy all resources created after the test. (WARNING: Depending on failure, Terraform may not always be able to destroy provisioned resources.)
`TFI_S3_BUCKET` | mybucket | optional | Which S3 bucket to place logs from installs and output from Terraform.
