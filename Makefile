SHELL = /usr/bin/env bash -xeuo pipefail

format: \
	fmt-python \
	fmt-terraform

fmt-python: \
	fmt-python-isort \
	fmt-python-black

fmt-python-isort:
	poetry run isort --profile=black src/

fmt-python-black:
	poetry run black src/

fmt-terraform: \
	fmt-terraform-root \
	fmt-terraform-module-common \
	fmt-terraform-module-lambda-function-basic

fmt-terraform-root:
	terraform fmt

fmt-terraform-module-common:
	cd terraform_modules/common; \
	terraform fmt

fmt-terraform-module-lambda-function-basic:
	cd terraform_modules/lambda_function_basic; \
	terraform fmt

.PHONY: \
	format \
	fmt-python \
	fmt-python-isort \
	fmt-python-black \
	fmt-terraform \
	fmt-terraform-root \
	fmt-terraform-module-common \
	fmt-terraform-module-lambda-function-basic
