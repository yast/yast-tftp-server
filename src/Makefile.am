# Makefile.am for source/tftp-server/src

yncludedir = @yncludedir@/tftp-server

client_DATA =			\
	tftp-server.ycp		\
	tftp-server_auto.ycp	\
	tftp-server_write.ycp


ynclude_DATA =			\
	wizards.ycp		\
	dialogs.ycp

module_DATA =			\
	TftpServer.ycp

desktop_DATA =                  \
	tftp-server.desktop

tftp-server:
	ln -sf . $@

ycpchook = tftp-server

EXTRA_DIST = $(client_DATA) $(ynclude_DATA) $(module_DATA) $(desktop_DATA)

include $(top_srcdir)/Makefile.am.common
