# Terraform Azure Infrastructure Makefile

.PHONY: help init validate plan apply destroy clean docs

# Default environment
ENV ?= dev

help:
	@echo "Available commands:"
	@echo "  make init ENV=dev    - Initialize Terraform for specified environment"
	@echo "  make validate ENV=dev - Validate Terraform configuration"
	@echo "  make plan ENV=dev    - Run Terraform plan"
	@echo "  make apply ENV=dev   - Apply Terraform changes"
	@echo "  make destroy ENV=dev - Destroy infrastructure"
	@echo "  make clean           - Clean temporary files"
	@echo "  make docs            - Generate documentation"

init:
	cd environments/$(ENV) && terraform init

validate:
	cd environments/$(ENV) && terraform validate

plan:
	cd environments/$(ENV) && terraform plan

apply:
	cd environments/$(ENV) && terraform apply

destroy:
	cd environments/$(ENV) && terraform destroy

clean:
	find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	find . -name "*.tfplan" -delete
	find . -name "*.tfstate.backup" -delete
	find . -name ".terraform.lock.hcl" -delete

docs:
	terraform-docs markdown table --output-file docs/terraform-docs.md .