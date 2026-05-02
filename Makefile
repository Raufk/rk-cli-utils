# =========== Config ===========
NAME := rk-cli-utils
VERSION := 1.0
RELEASE := 1

BUILD_DIR := build
RPMBUILD := $(HOME)/rpmbuild

DEB_DIR := $(BUILD_DIR)/deb/$(NAME)-$(VERSION)
BIN_DIR := $(DEB_DIR)/usr/bin
LIB_DIR := $(DEB_DIR)/usr/lib/rk-cli-utils

# =========== Default ===========
all: clean rpm deb

# =========== Prepare common files ===========
prepare:
	@echo "==========================================="
	@echo "Preparing build..."
	rm -rf $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)

	@echo "==========================================="
	@echo "Injecting version..."
	sed "s/@VERSION@/$(VERSION)/g" bin/rk > $(BUILD_DIR)/rk

# =========== RPM ===========
rpm: prepare
	@echo "==========================================="
	@echo "Setting up RPM build environment..."
	sudo yum install -y rpm-build rpmdevtools
	rpmdev-setuptree

	@echo "==========================================="
	@echo "Building RPM..."

	mkdir -p $(RPMBUILD)/SOURCES/$(NAME)-$(VERSION)
	cp -r bin lib wrappers $(RPMBUILD)/SOURCES/$(NAME)-$(VERSION)/
	cp $(BUILD_DIR)/rk $(RPMBUILD)/SOURCES/$(NAME)-$(VERSION)/bin/rk

	cd $(RPMBUILD)/SOURCES && tar -czf $(NAME)-$(VERSION).tar.gz $(NAME)-$(VERSION)

	cp packaging/$(NAME).spec $(RPMBUILD)/SPECS/

	rpmbuild -ba $(RPMBUILD)/SPECS/$(NAME).spec

	@echo "==========================================="
	@echo "RPM created in $(RPMBUILD)/RPMS/"

# =========== DEB ===========
deb: prepare
	@echo "==========================================="
	@echo "Building DEB..."

	mkdir -p $(BIN_DIR)
	mkdir -p $(LIB_DIR)
	mkdir -p $(DEB_DIR)/DEBIAN

	# Install files
	install -m 0755 $(BUILD_DIR)/rk $(BIN_DIR)/rk
	install -m 0755 wrappers/* $(BIN_DIR)/
	install -m 0644 lib/*.sh $(LIB_DIR)/

	# Control file
	echo "Package: $(NAME)" > $(DEB_DIR)/DEBIAN/control
	echo "Version: $(VERSION)" >> $(DEB_DIR)/DEBIAN/control
	echo "Section: utils" >> $(DEB_DIR)/DEBIAN/control
	echo "Priority: optional" >> $(DEB_DIR)/DEBIAN/control
	echo "Architecture: all" >> $(DEB_DIR)/DEBIAN/control
	echo "Depends: bash, git, curl, jq, openssh-client" >> $(DEB_DIR)/DEBIAN/control
	echo "Maintainer: Rauf K" >> $(DEB_DIR)/DEBIAN/control
	echo "Description: CLI utilities for DevOps workflows" >> $(DEB_DIR)/DEBIAN/control

	dpkg-deb --build $(DEB_DIR)

	@echo "==========================================="
	@echo "DEB created in : $(BUILD_DIR)/deb/"

# =========== Clean ===========
clean:
	rm -rf $(BUILD_DIR)

.PHONY: all rpm deb clean prepare