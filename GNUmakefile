export SHELL = /bin/bash
export AWS_REGION ?= us-east-1
export TERRAFORM_PARALLELISM ?= 20

default: again

again: neat valid
ifeq (,$(wildcard ./.terraform/))
	@terraform init $(COLOR_OPTION)
endif
ifneq (,$(wildcard .env))
	@source .env && \
		terraform apply \
			-parallelism=$(TERRAFORM_PARALLELISM) $(COLOR_OPTION) \
			-input=false \
			-auto-approve
else
	@terraform apply \
		-parallelism=$(TERRAFORM_PARALLELISM) $(COLOR_OPTION) \
		-input=false \
		-auto-approve
endif

valid:
ifeq (,$(wildcard ./.terraform/))
	@terraform init $(COLOR_OPTION)
endif
ifneq (,$(wildcard .env))
	@source .env && \
		terraform validate $(COLOR_OPTION)
else
	@terraform validate $(COLOR_OPTION)
endif

clean:
	@terraform destroy \
		-input=false $(COLOR_OPTION) \
		-auto-approve

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

.PHONY: again valid clean fresh neat state count
