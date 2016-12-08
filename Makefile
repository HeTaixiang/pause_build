# Copyright 2016 The Kubernetes Authors.
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

.PHONY: all push push-legacy container clean

REGISTRY ?= docker.zhimei360.com
IMAGE = $(REGISTRY)/pause-$(ARCH)
LEGACY_AMD64_IMAGE = $(REGISTRY)/pause

TAG = 3.0

# Architectures supported: amd64, arm, arm64 and ppc64le
ARCH ?= amd64

ALL_ARCH = amd64 arm arm64 ppc64le

CFLAGS = -Os -Wall -static
KUBE_CROSS_IMAGE ?= $(REGISTRY)/kube-cross
KUBE_CROSS_VERSION ?= v1.6.3-9

BIN = pause
SRCS = pause.c

ifeq ($(ARCH),amd64)
	TRIPLE ?= x86_64-linux-gnu
endif

ifeq ($(ARCH),arm)
	TRIPLE ?= arm-linux-gnueabi
endif

ifeq ($(ARCH),arm64)
	TRIPLE ?= aarch64-linux-gnu
endif

ifeq ($(ARCH),ppc64le)
	TRIPLE ?= powerpc64le-linux-gnu
endif

# If you want to build AND push all containers, see the 'all-push' rule.
all: all-container

sub-container-%:
	$(MAKE) ARCH=$* container

sub-push-%:
	$(MAKE) ARCH=$* push

all-container: $(addprefix sub-container-,$(ALL_ARCH))

all-push: $(addprefix sub-push-,$(ALL_ARCH))

build: bin/$(BIN)-$(ARCH)

bin/$(BIN)-$(ARCH): $(SRCS)
	mkdir -p bin
	docker run -u $$(id -u):$$(id -g) -v $$(pwd):/build \
		$(KUBE_CROSS_IMAGE):$(KUBE_CROSS_VERSION) \
		/bin/bash -c "\
			cd /build && \
			$(TRIPLE)-gcc $(CFLAGS) -o $@ $^ && \
			$(TRIPLE)-strip $@"

container: .container-$(ARCH)
.container-$(ARCH): bin/$(BIN)-$(ARCH)
	docker build -t $(IMAGE):$(TAG) --build-arg ARCH=$(ARCH) .
ifeq ($(ARCH),amd64)
	docker rmi $(LEGACY_AMD64_IMAGE):$(TAG) || true
	docker tag $(IMAGE):$(TAG) $(LEGACY_AMD64_IMAGE):$(TAG)
endif
	touch $@

push: .push-$(ARCH)
.push-$(ARCH): .container-$(ARCH)
	docker push $(IMAGE):$(TAG)
	touch $@

push-legacy: .push-legacy-$(ARCH)
.push-legacy-$(ARCH): .container-$(ARCH)
ifeq ($(ARCH),amd64)
	docker push $(LEGACY_AMD64_IMAGE):$(TAG)
endif
	touch $@

clean:
	rm -rf .container-* .push-* bin/
