#
# spec file for package yast2-tftp-server
#
# Copyright (c) 2013 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Name:           yast2-tftp-server
Version:        4.1.2
Release:        0

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        %{name}-%{version}.tar.bz2

Group:	        System/YaST
License:        GPL-2.0-or-later

BuildRequires:	update-desktop-files
BuildRequires:  yast2-devtools >= 3.1.10
BuildRequires:	augeas-lenses
# Yast2::Systemd::Service
BuildRequires:  yast2 >= 4.1.3
BuildRequires:  rubygem(%rb_default_ruby_abi:rspec)
BuildRequires:  rubygem(%rb_default_ruby_abi:yast-rake)
BuildRequires:  rubygem(%rb_default_ruby_abi:cfa)

# Yast2::Systemd::Service
Requires:       yast2 >= 4.1.3
# Namespace Y2Journal
Requires:       yast2-journal >= 4.1.1
Requires:	lsof
Requires:	augeas-lenses
Requires:       rubygem(%rb_default_ruby_abi:cfa)

BuildArchitectures:	noarch

Requires:       yast2-ruby-bindings >= 1.0.0

Summary:	YaST2 - TFTP Server Configuration

%description
The YaST2 component for configuring a TFTP server. TFTP stands for
Trivial File Transfer Protocol. It is used for booting over the
network.

%prep
%setup -n %{name}-%{version}

%check
rake test:unit

%build

%install
rake install DESTDIR="%{buildroot}"


%files
%defattr(-,root,root)
%dir %{yast_yncludedir}/tftp-server
%{yast_yncludedir}/tftp-server/*
%{yast_clientdir}/tftp-server*.rb
%{yast_moduledir}/TftpServer.*
%{yast_libdir}/cfa
%{yast_desktopdir}/tftp-server.desktop
%doc %{yast_docdir}
