FORCE_PULL := 0
DEV_BUILD  := 0
ARCH       := amd64

include build.conf
include build.conf.$(ARCH)


bin/ros:
	mkdir -p $(dir $@)
	ARCH=$(ARCH) VERSION=$(VERSION) ./scripts/mk-ros.sh $@

build/host_ros: bin/ros
	mkdir -p $(dir $@)
ifeq "$(ARCH)" "amd64"
	ln -sf ../bin/ros $@
else
	ARCH=amd64 VERSION=$(VERSION) ./scripts/mk-ros.sh $@
endif


assets/docker:
	mkdir -p $(dir $@)
	curl -L "$(DOCKER_BINARY_URL)" > $@
	chmod +x $@

assets/selinux/policy.29:
	mkdir -p $(dir $@)
	curl -L "$(SELINUX_POLICY_URL)" > $@

ifdef COMPILED_KERNEL_URL

installer: minimal
	docker build -t $(IMAGE_NAME):$(VERSION) .

dist/artifacts/vmlinuz: build/kernel/
	mkdir -p $(dir $@)
	mv build/kernel/boot/vmlinuz* $@


build/kernel/:
	mkdir -p $@
	curl -L "$(COMPILED_KERNEL_URL)" | tar -xzf - -C $@


dist/artifacts/initrd: bin/ros assets/docker assets/selinux/policy.29 build/kernel/ build/images.tar
	mkdir -p $(dir $@)
	ARCH=$(ARCH) DFS_IMAGE=$(DFS_IMAGE) DEV_BUILD=$(DEV_BUILD) ./scripts/mk-initrd.sh $@


dist/artifacts/rancheros.iso: minimal
	./scripts/mk-rancheros-iso.sh

all: minimal installer iso

initrd: dist/artifacts/initrd

minimal: initrd dist/artifacts/vmlinuz

iso: dist/artifacts/rancheros.iso dist/artifacts/iso-checksums.txt

test: minimal
	cd tests/integration && tox

.PHONY: all minimal initrd iso installer test

endif


build/os-config.yml: build/host_ros
	ARCH=$(ARCH) VERSION=$(VERSION) ./scripts/gen-os-config.sh $@


build/images.tar: build/host_ros build/os-config.yml
	ARCH=$(ARCH) FORCE_PULL=$(FORCE_PULL) ./scripts/mk-images-tar.sh


dist/artifacts/rootfs.tar.gz: bin/ros assets/docker build/images.tar assets/selinux/policy.29
	mkdir -p $(dir $@)
	ARCH=$(ARCH) DFS_IMAGE=$(DFS_IMAGE) DEV_BUILD=$(DEV_BUILD) IS_ROOTFS=1 ./scripts/mk-initrd.sh $@


dist/artifacts/iso-checksums.txt: dist/artifacts/rancheros.iso
	./scripts/mk-iso-checksums-txt.sh


version:
	@echo $(VERSION)

rootfs: dist/artifacts/rootfs.tar.gz

.PHONY: rootfs version bin/ros
