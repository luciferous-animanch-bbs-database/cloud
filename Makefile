SHELL = /usr/bin/env bash -xeuo pipefail

format: \
	fmt-terraform

fmt-terraform: \
	fmt-terraform-root \
	fmt-terraform-module-common

fmt-terraform-root:
	terraform fmt

fmt-terraform-module-common:
	cd terraform_modules/common; \
	terraform fmt

.PHONY: \
	format \
	fmt-terraform \
	fmt-terraform-root \
	fmt-terraform-module-common
