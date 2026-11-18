#!/usr/bin/env bash
set -euo pipefail

# install dependencies
printf "\n======================================================"
printf "\n===== Installing build dependencies..."
sudo yum install -y rpm-build rpmdevtools

# setup rpmbuild environment
printf "\n======================================================"
printf "\n===== Setting up rpmbuild environment..."
rpmdev-setuptree

# copy source files
printf "\n======================================================"
printf "\n===== Copying source files..."
cp -r bin lib wrappers completions ~/rpmbuild/SOURCES/
cp -r packaging/rk-cli-utils.spec ~/rpmbuild/SPECS/

# build the RPM package
printf "\n======================================================"
printf "\n===== Building RPM package..."
rpmbuild -ba ~/rpmbuild/SPECS/rk-cli-utils.spec

printf "\n======================================================"
printf "\n===== RPM package built successfully..."
ls -l ~/rpmbuild/RPMS/noarch/rk-cli-utils-*.rpm

printf "\n======================================================"
printf "\n===== To install the package, run:"
printf "\n   sudo yum remove rk-cli-utils || true"
printf "\n   sudo yum localinstall ~/rpmbuild/RPMS/noarch/rk-cli-utils*.rpm"
