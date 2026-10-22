#!/bin/sh
BASE=/usr/local/lib/sunlogin-fusionfix/16.6.0.32198
CLIPBOARD=$(cat /etc/sunlogin-fusionfix-clipboard 2>/dev/null || printf 0)
case ${SUNLOGIN_FUSIONFIX_CLIPBOARD_TEXT:-$CLIPBOARD} in
    1) export SUNLOGIN_FUSIONFIX_CLIPBOARD_TEXT=1 ;;
    *) export SUNLOGIN_FUSIONFIX_CLIPBOARD_TEXT=0 ;;
esac
export GDK_BACKEND=x11
export LD_LIBRARY_PATH="$BASE/compat/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LD_PRELOAD="$BASE/libsunlogin-fusionfix.so${LD_PRELOAD:+:$LD_PRELOAD}"
exec /usr/local/awesun/awesun "$@"
