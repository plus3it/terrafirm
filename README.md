# terrafirm_win
Terrafirm tests watchmaker on Windows and Linux

This project is designed to work with **AWS CodeBuild**. In order to use it, you will need to provide certain environment variables.

## ENVIRONMENT VARIABLES EXPECTED BY TERRAFIRM

- `REGION`            : AWS region. E.g., us-east-1
- `PS_PUBLIC_KEY`     : Name of a Parameter Store parameter containing the public key used in creating a Key Pair for use by Terrafirm. E.g., /CodeBuild/public_key
- `PS_PASSWD_KEY`     : Name of a Parameter Store parameter containing the private key used in authenticating to instances created with the Key Pair. E.g., /CodeBuild/private_key
- `PS_SSH_KEY`        : Name of a Parameter Store parameter containing the private key used in authenticating to instances created with the Key Pair. E.g., /CodeBuild/private_key
- `NAMED_PROFILE`    : Name of AWS profile that will be used by Terraform. E.g., terraform
- `ASSIGN_PUBLIC_IP`  : Whether or not to assign a public IP to the instances built by Terraform. E.g., true
- `GIT_BRANCH`        : Which branch of the repository to use in getting watchmaker code. E.g., https://github.com/plus3it/watchmaker.git
- `GIT_REPO`          : Which git repository to use in getting watchmaker code. E.g., master
- `SSH_USER`          : Which username to use when connecting via SSH to Linux instances. E.g., root
- `WINRM_USER`        : Which username to use when connecting via WinRM to Windows instances. E.g., Administrator
- `KEY_PAIR_NAME`     : The name to use for the Key Pair created and maintained by Terrafirm (this key will be created and destroyed). E.g., terrafirm_key
