#!/usr/bin/env bash
set -euo pipefail

# install dependencies
echo "===== Installing build dependencies..."
sudo yum install -y rpm-build rpmdevtools

# setup rpmbuild environment
echo "===== Setting up rpmbuild environment..."
rpmdev-setuptree

# copy source files
echo "===== Copying source files..."
cp -r bin lib wrappers ~/rpmbuild/SOURCES/
cp -r packaging/rk-cli-utils.spec ~/rpmbuild/SPECS/

# build the RPM package
echo "===== Building RPM package..."
rpmbuild -ba ~/rpmbuild/SPECS/rk-cli-utils.spec

echo "===== RPM package built successfully..."
ls -l ~/rpmbuild/RPMS/noarch/rk-cli-utils-*.rpm
