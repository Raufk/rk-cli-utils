Name:           rk-cli-utils
Version:        1.0
Release:        1%{?dist}
Summary:        CLI utilities for DevOps workflows

License:        MIT
BuildArch:      noarch

Source0:        rk-cli-utils

Requires:       bash, git, curl, jq, openssh-clients

%description
A collection of CLI utilities to simplify developer and DevOps workflows.
Utilities for:
- SSH setup for GitHub/GHE
- Sending Slack messages

%prep
# nothing to build

%build
# nothing to build

%install
mkdir -p %{buildroot}%{_bindir}
mkdir -p %{buildroot}%{_libdir}/rk-cli-utils

# Inject version into script
sed "s/@VERSION@/%{version}/g" bin/rk > rk

# Install main CLI
install -m 0755 bin/rk %{buildroot}%{_bindir}/rk

# Install library scripts
install -m 0644 lib/*.sh %{buildroot}%{_libdir}/rk-cli-utils/

# Wrapper commands
install -m 0755 wrappers/setup-ssh %{buildroot}%{_bindir}/setup-ssh
install -m 0755 wrappers/slack-send %{buildroot}%{_bindir}/slack-send
install -m 0755 wrappers/get-slack-id %{buildroot}%{_bindir}/get-slack-id

%files
%{_bindir}/rk
%{_bindir}/setup-ssh
%{_bindir}/slack-send
%{_bindir}/get-slack-id
%{_libdir}/rk-cli-utils/*

%changelog
* Sat May 02 2026 Rauf K - 1.0-1
- Initial release
