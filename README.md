# terrafirm
Terrafirm launches Windows and Linux instances and installs [Watchmaker](https://github.com/plus3it/watchmaker) to test that it installs and runs.

This project is designed to work with **AWS CodeBuild**. In order to use it, you will need to provide certain environment variables.

## ENVIRONMENT VARIABLES EXPECTED BY TERRAFIRM

Variable | Default | Req/Opt (in CodeBuild) | Description
--- | --- | --- | ---
`REGION` | us-east-1 | optional | AWS region
`WINRM_USER` | Administrator | optional | username to use when connecting via WinRM to Windows instances
`PS_PASSWD_KEY` | /path/to/parameter/store | REQUIRED | Ab
`PS_PRIVATE_KEY` | /path/to/parameter/store | REQUIRED | Ab
`PS_PUBLIC_KEY` | /path/to/parameter/store | REQUIRED | Ab
`SSH_USER` | root | optional | Ab
`ASSIGN_PUBLIC_IP` | false | optional | Ab
`GIT_REPO` | https://github.com/plus3it/watchmaker.git | optional | Ab
`GIT_BRANCH` | master | optional | Ab
`DESTROY_AFTER_TEST` | true | optional | Ab
`INSTANCE_PROFILE` | none | optional | Ab
`LX_INSTANCE_TYPE` | t2.micro | optional | Ab
`WIN_INSTANCE_TYPE` | t2.medium | optional | Ab
`LX_WM_ARGS` | --log-dir=/var/log/watchmaker | optional | Ab
`WIN_WM_ARGS` | --log-dir=C:\\Watchmaker\\Logs | optional | Ab
`COMMON_WM_ARGS` | -n --log-level debug | optional | Ab
`SUBNET_ID` | none | optional | Ab
`BUILD_WIN` | all | optional | Ab
`BUILD_LX` | all | optional | Ab


- `REGION`            : . E.g., us-east-1
- `PS_PUBLIC_KEY`     : Name of a Parameter Store parameter containing the public key used in creating a Key Pair for use by Terrafirm. E.g., /CodeBuild/public_key
- `PS_PASSWD_KEY`     : Name of a Parameter Store parameter containing the private key used in authenticating to instances created with the Key Pair. E.g., /CodeBuild/private_key
- `PS_SSH_KEY`        : Name of a Parameter Store parameter containing the private key used in authenticating to instances created with the Key Pair. E.g., /CodeBuild/private_key
- `NAMED_PROFILE`    : Name of AWS profile that will be used by Terraform. E.g., terraform
- `ASSIGN_PUBLIC_IP`  : Whether or not to assign a public IP to the instances built by Terraform. E.g., true
- `GIT_REPO`          : Which git repository to use in getting watchmaker code. E.g., https://github.com/plus3it/watchmaker.git
- `GIT_BRANCH`        : Which branch of the repository to use in getting watchmaker code. E.g., master
- `SSH_USER`          : Which username to use when connecting via SSH to Linux instances. E.g., root
- `WINRM_USER`        : Which username to use when connecting via WinRM to Windows instances. E.g., Administrator
- `KEY_PAIR_NAME`     : The name to use for the Key Pair created and maintained by Terrafirm (this key will be created and destroyed). E.g., terrafirm_key
