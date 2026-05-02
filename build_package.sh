#!/usr/bin/env bash
set -euo pipefail

# install dependencies
printf "\n======================================================"
printf "===== Installing build dependencies..."
sudo yum install -y rpm-build rpmdevtools

# setup rpmbuild environment
printf "\n======================================================"
printf "===== Setting up rpmbuild environment..."
rpmdev-setuptree

# copy source files
printf "\n======================================================"
printf "===== Copying source files..."
cp -r bin lib wrappers ~/rpmbuild/SOURCES/
cp -r packaging/rk-cli-utils.spec ~/rpmbuild/SPECS/

# build the RPM package
printf "\n======================================================"
printf "===== Building RPM package..."
rpmbuild -ba ~/rpmbuild/SPECS/rk-cli-utils.spec

printf "\n======================================================"
printf "===== RPM package built successfully..."
ls -l ~/rpmbuild/RPMS/noarch/rk-cli-utils-*.rpm

printf "\n======================================================"
printf "===== To install the package, run:"
printf "   sudo yum remove rk-cli-utils || true"
printf "   sudo yum localinstall ~/rpmbuild/RPMS/noarch/rk-cli-utils*.rpm"
