# terrafirm
Terrafirm launches Windows and Linux instances and installs [Watchmaker](https://github.com/plus3it/watchmaker) to test that it installs and runs.

This project is designed to work with **AWS CodeBuild**. In order to use it, you will need to provide certain environment variables.

## ENVIRONMENT VARIABLES EXPECTED BY TERRAFIRM

Variable | Default | Req/Opt (in CodeBuild) | Description
--- | --- | --- | ---
`REGION` | us-east-1 | optional | AWS region
`WINRM_USER` | Administrator | optional | username to use when connecting via WinRM to Windows instances
`PS_PASSWD_KEY` | /path/to/parameter/store | REQUIRED | Name of a Parameter Store (PS) parameter containing the password used temporarily in WinRM connection to Windows instances.
`PS_PRIVATE_KEY` | /path/to/parameter/store | REQUIRED | Name of a PS parameter containing the private key used in authenticating to instances created with the Key Pair.
`PS_PUBLIC_KEY` | /path/to/parameter/store | REQUIRED | Name of a PS parameter containing the public key used in creating a Key Pair for use by Terrafirm.
`SSH_USER` | root | optional | Which username to use when connecting via SSH to Linux instances.
`ASSIGN_PUBLIC_IP` | false | optional | Whether or not to assign a public IP to the instances built by Terraform.
`GIT_REPO` | https://github.com/plus3it/watchmaker.git | optional | Which git repository to use in getting watchmaker code.
`GIT_BRANCH` | master | optional | Which branch of the repository to use in getting watchmaker code.
`DESTROY_AFTER_TEST` | true | optional | Whether or not to destroy all resources created after the test. (WARNING: Depending on failure, Terraform may not always be able to destroy provisioned resources.)
`INSTANCE_PROFILE` | none | optional | Instance profile to be used in provisioning resources. This is generally the same as the role if the role is an EC2 role.
`LX_INSTANCE_TYPE` | t2.micro | optional | AWS instance type for Linux instances.
`WIN_INSTANCE_TYPE` | t2.medium | optional | AWS instance type for Windows instances.
`LX_WM_ARGS` | --log-dir=/var/log/watchmaker | optional | Command line arguments used when installing Watchmaker (Linux).
`WIN_WM_ARGS` | --log-dir=C:\\Watchmaker\\Logs | optional | Command line arguments used when installing Watchmaker (Windows).
`COMMON_WM_ARGS` | -n --log-level debug | optional | Command line arguments used when installing Watchmaker (Windows/Linux).
`SUBNET_ID` | none | optional | Whether or not to use a subnet. CodeBuild instance must be able to access.
`BUILD_WIN` | all | optional | Whether or not to build all possible Windows instances. Acceptable values are "all", "one", or "none".
`BUILD_LX` | all | optional | Whether or not to build all possible Linux instances. Acceptable values are "all", "one", or "none".

