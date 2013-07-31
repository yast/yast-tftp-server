# Sources for tftp-server

module_DATA = \
  modules/TftpServer.rb

client_DATA = \
  clients/tftp-server.rb \
  clients/tftp-server_auto.rb

yncludedir = @yncludedir@/tftp-server
ynclude_DATA = \
  include/tftp-server/wizards.rb \
  include/tftp-server/dialogs.rb

scrconf_DATA = \
  scrconf/etc_xinetd_d_tftp.scr

desktop_DATA = \
  desktop/tftp-server.desktop

EXTRA_DIST = $(module_DATA) $(client_DATA) $(ynclude_DATA) $(scrconf_DATA) $(desktop_DATA)

include $(top_srcdir)/Makefile.am.common