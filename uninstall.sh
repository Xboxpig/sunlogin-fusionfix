#!/usr/bin/env bash
set -euo pipefail

[[ $EUID == 0 ]] || { echo 'Run with sudo.' >&2; exit 1; }
STATE=/var/lib/sunlogin-fusionfix
BASE=/usr/local/lib/sunlogin-fusionfix
[[ -d $STATE ]] || { echo 'Sunlogin FusionFix is not installed.' >&2; exit 1; }

restore() {
    local path=$1 key=$2
    if [[ -e $STATE/$key || -L $STATE/$key ]]; then
        rm -f "$path"
        cp -a --no-dereference "$STATE/$key" "$path"
    elif [[ -e $STATE/$key.absent ]]; then
        rm -f "$path"
    fi
}

restore /usr/local/awesun previous-awesun
restore /usr/local/bin/awesun previous-wrapper
restore /usr/local/bin/sunlogin-fusionfix-clipboard previous-clipboard-command
restore /usr/local/share/applications/awesun.desktop previous-desktop
restore /usr/lib/x86_64-linux-gnu/webkit2gtk-4.1 previous-webkit-link
restore /etc/systemd/system/runsunloginclient.service.d/official-path.conf previous-service-dropin
restore /etc/systemd/system/runsunloginclient.service previous-service-unit
if [[ -e $STATE/created-oray-config && -f /etc/orayconfig.conf && ! -s /etc/orayconfig.conf ]]; then
    rm -f /etc/orayconfig.conf
fi
restore /etc/sunlogin-fusionfix-clipboard previous-clipboard-config
systemctl daemon-reload
rm -rf "$BASE"
rm -rf "$STATE"
echo 'Sunlogin FusionFix removed. Restart AweSun to return to the previous launcher.'
