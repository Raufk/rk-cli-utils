Name:           rk-cli-utils
Version:        1.0
Release:        1%{?dist}
Summary:        CLI utilities for DevOps workflows

License:        MIT
BuildArch:      noarch

Requires:       bash, git, curl, jq, openssh-clients

%description
A collection of CLI utilities to simplify developer and DevOps workflows.
Utilities for:
- SSH setup for GitHub/GHE
- Sending Slack messages

%prep
cp -r %{_sourcedir}/* .

%build
# nothing to build

%install
mkdir -p %{buildroot}%{_bindir}
mkdir -p %{buildroot}/usr/lib/rk-cli-utils

# Inject version & Install main CLI
sed "s/@VERSION@/%{version}/g" bin/rk > rk
install -m 0755 rk %{buildroot}%{_bindir}/rk

# Install library scripts
install -m 0644 lib/*.sh %{buildroot}/usr/lib/rk-cli-utils/

# install wrappers
install -m 0755 wrappers/* %{buildroot}%{_bindir}/

%files
%{_bindir}/rk
%{_bindir}/setup-ssh
%{_bindir}/slack-send
%{_bindir}/get-slack-id
/usr/lib/rk-cli-utils/*

%changelog
* Sat May 02 2026 Rauf K - 1.0-1
- Initial release
