# Copyright 2019 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Enable Go modules.
export GO111MODULE=on

DOCKER ?= docker
# TOP is the current directory where this Makefile lives.
TOP := $(dir $(firstword $(MAKEFILE_LIST)))
# ROOT is the root of the mkdocs tree.
ROOT := $(abspath $(TOP))

CONTROLLER_GEN=go run sigs.k8s.io/controller-tools/cmd/controller-gen

all: generate vet fmt verify

# Run generators for protos, Deepcopy funcs, CRDs, and docs.
.PHONY: generate
generate:
	$(CONTROLLER_GEN) \
		object:headerFile=./hack/boilerplate/boilerplate.go.txt,year=$$(date +%Y) \
		crd:crdVersions=v1 \
		output:crd:artifacts:config=config/crd/bases \
		paths=./...
	$(MAKE) docs
	hack/update-codegen.sh

# Run go fmt against code
fmt:
	go fmt ./...

# Run go vet against code
vet:
	go vet ./...

# Install CRD's and example resources to a pre-existing cluster.
.PHONY: install
install: crd example

# Install the CRD's to a pre-existing cluster.
.PHONY: crd
crd:
	kubectl kustomize config/crd | kubectl apply -f -

# Install the example resources to a pre-existing cluster.
.PHONY: example
example:
	hack/install-examples.sh

# Remove installed CRD's and CR's.
.PHONY: uninstall
uninstall:
	hack/delete-crds.sh

# Run static analysis.
.PHONY: verify
verify:
	hack/verify-all.sh -v

# Build the documentation.
.PHONY: docs
docs:
	# Generate API docs first
	./hack/api-docs/generate.sh docs-src/spec.md
	# The docs image must be built locally until issue #141 is fixed.
	docker build --tag k8s.gcr.io/service-apis-mkdocs:latest -f mkdocs.dockerfile .
	$(MAKE) -f docs.mk

# Serve the docs site locally at http://localhost:8000.
.PHONY: serve
serve:
	$(MAKE) -f docs.mk serve

# Clean deletes generated documentation files.
.PHONY: clean
clean:
	$(MAKE) -f docs.mk clean
