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
Version:        3.1.2
Release:        0

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        %{name}-%{version}.tar.bz2

Group:	        System/YaST
License:        GPL-2.0+

BuildRequires:	perl-XML-Writer update-desktop-files yast2-testsuite
BuildRequires:  yast2-devtools >= 3.1.10
# SuSEfirewall2_* scripts merget into one in yast2-2.23.17
BuildRequires:	yast2 >= 2.23.17

# Wizard::SetDesktopTitleAndIcon
Requires:	yast2 >= 2.21.22
Requires:	lsof

BuildArchitectures:	noarch

Requires:       yast2-ruby-bindings >= 1.0.0

Summary:	YaST2 - TFTP Server Configuration

%description
The YaST2 component for configuring a TFTP server. TFTP stands for
Trivial File Transfer Protocol. It is used for booting over the
network.

%prep
%setup -n %{name}-%{version}

%build
%yast_build

%install
%yast_install


%files
%defattr(-,root,root)
%dir %{yast_yncludedir}/tftp-server
%{yast_yncludedir}/tftp-server/*
%{yast_clientdir}/tftp-server*.rb
%{yast_moduledir}/TftpServer.*
%{yast_desktopdir}/tftp-server.desktop
%{yast_scrconfdir}/etc_xinetd_d_tftp.scr
%doc %{yast_docdir}
