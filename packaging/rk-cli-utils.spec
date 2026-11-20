Name:           rk-cli-utils
Version:        1.1
Release:        1%{?dist}
Summary:        CLI utilities for DevOps workflows

License:        MIT
BuildArch:      noarch

Requires:       bash, git, curl, jq, openssh-clients, openssl

%description
A collection of CLI utilities to simplify developer and DevOps workflows.
Utilities for:
- SSH setup for GitHub/GHE
- Sending Slack messages
- Git operations authenticated with a GitHub App installation token

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

# install shell completions (bash, zsh)
install -D -m 0644 completions/git-app.bash %{buildroot}%{_datadir}/bash-completion/completions/git-app
install -D -m 0644 completions/git-app.bash %{buildroot}%{_datadir}/bash-completion/completions/rk
install -D -m 0644 completions/_git-app %{buildroot}%{_datadir}/zsh/site-functions/_git-app

%files
%{_bindir}/rk
%{_bindir}/setup-ssh
%{_bindir}/slack-send
%{_bindir}/get-slack-id
%{_bindir}/git-app
/usr/lib/rk-cli-utils/*
%{_datadir}/bash-completion/completions/git-app
%{_datadir}/bash-completion/completions/rk
%{_datadir}/zsh/site-functions/_git-app

%changelog
* Wed Nov 18 2026 Rauf K - 1.1-1
- Release version 1.1: GitHub App git operations, Slack payload improvements, SSH key setup hardening
