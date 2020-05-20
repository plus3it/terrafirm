export SHELL = /bin/bash
export AWS_REGION ?= us-east-1

default: again

again:
ifeq (,$(wildcard ./.terraform/))
	@terraform init $(COLOR_OPTION)
endif
ifneq (,$(wildcard .env))
	@source .env && \
		terraform apply -parallelism=20 $(COLOR_OPTION) -input=false -auto-approve
else
	@terraform apply -parallelism=20 $(COLOR_OPTION) -input=false -auto-approve
endif

clean:
	@terraform destroy $(COLOR_OPTION) -input=false -auto-approve

fresh: clean
	@-rm -rf terraform.tfstate*
	@-rm -rf .terraform/
	@-rm terraform.log

neat:
	@terraform fmt

state:
	@terraform state list $(COLOR_OPTION) | sort

count:
	@echo "State currently has $(shell terraform state list | wc -l | xargs) items"

.PHONY: clean fresh again neat state count
