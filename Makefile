include mk/common.mk

ARCH?=	amd64

.PHONY: all build builder image docker-login src test-src push lint clean

all: build

docker-login:
	@docker login

builder:
	@make -C image-builder builder

image:
	@make -C image-builder image ARCH=$(ARCH)

test-src:
	@make -C src test

src:
	@make -C src

Dockerfile: Dockerfile.in
	@$(SED) -e 's|@INIT_SCRIPT_PATH@|$(INIT_SCRIPT_PATH)|g' \
		-e 's|@ENTRYPOINT_PATH@|$(ENTRYPOINT_PATH)|g' \
		-e 's|@API_KEY_GENERATOR_PATH@|$(API_KEY_GENERATOR_PATH)|g' \
		$< > $@

build: Dockerfile src check-vars
	@docker build . -t ${REPO}:${VERSION}-${ARCH} --build-arg OPNSENSE_VERSION=${VERSION} --build-arg OPNSENSE_ARCH=${ARCH}

push: check-vars
	@docker push ${REPO}:${VERSION}-${ARCH}

lint:
	@hadolint Dockerfile	

clean:
	@rm -f Dockerfile