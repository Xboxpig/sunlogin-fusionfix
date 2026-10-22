#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
VERSION=16.6.0.32198
BASE=/usr/local/lib/sunlogin-fusionfix
STATE=/var/lib/sunlogin-fusionfix
CACHE=${XDG_CACHE_HOME:-$HOME/.cache}/sunlogin-fusionfix
CLIPBOARD=0
WEBKIT_LINK=/usr/lib/x86_64-linux-gnu/webkit2gtk-4.1

usage() {
    echo "Usage: sudo ./install.sh [--enable-clipboard] [--cache-dir DIR]" >&2
}

while (($#)); do
    case $1 in
        --enable-clipboard) CLIPBOARD=1; shift ;;
        --cache-dir) CACHE=$2; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) usage; exit 2 ;;
    esac
done

[[ $EUID == 0 ]] || { echo 'Run with sudo.' >&2; exit 1; }
[[ $(uname -m) == x86_64 ]] || { echo 'Only x86_64 is supported.' >&2; exit 1; }
if [[ -e $WEBKIT_LINK && ! -L $WEBKIT_LINK ]]; then
    echo "$WEBKIT_LINK is an existing directory; cannot replace it safely." >&2
    exit 1
fi
for tool in curl sha256sum ar bsdtar cc pkg-config systemctl; do
    command -v "$tool" >/dev/null || { echo "Missing: $tool" >&2; exit 1; }
done
pkg-config --exists x11 || { echo 'Missing X11 development headers (libx11).' >&2; exit 1; }

mkdir -p "$CACHE" "$STATE"
while read -r name sha url; do
    [[ -z ${name:-} || $name == \#* ]] && continue
    file=$CACHE/$name
    if [[ ! -f $file ]] || ! echo "$sha  $file" | sha256sum -c --status; then
        echo "Downloading $name"
        curl --fail --location --retry 2 --connect-timeout 10 --max-time 600 \
            --output "$file.part" "$url"
        mv -f "$file.part" "$file"
        echo "$sha  $file" | sha256sum -c --status || {
            rm -f "$file"
            echo "Checksum mismatch: $name" >&2
            exit 1
        }
    fi
done < "$ROOT/sources.lock"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
extract_deb() {
    local deb=$1 dest=$2 member
    member=$(ar t "$deb" | awk '/^data\.tar\./ {print; exit}')
    [[ -n $member ]] || { echo "Missing data.tar in $deb" >&2; exit 1; }
    mkdir -p "$dest"
    ar p "$deb" "$member" | bsdtar -xf - -C "$dest"
}

extract_deb "$CACHE/awesun_${VERSION}_amd64.deb" "$tmp/vendor"
while read -r name sha url; do
    [[ -z ${name:-} || $name == \#* || $name == awesun_* ]] && continue
    extract_deb "$CACHE/$name" "$tmp/compat"
done < "$ROOT/sources.lock"

[[ -x $tmp/vendor/usr/local/awesun/awesun ]] || { echo 'Unexpected AweSun package layout.' >&2; exit 1; }
compat_source=$tmp/compat/usr/lib/x86_64-linux-gnu
[[ -f $compat_source/libwebkit2gtk-4.1.so.0.19.7 ]] || {
    echo 'Unexpected WebKit package layout.' >&2; exit 1;
}

make -C "$ROOT" clean all
install -d -m 755 "$BASE" /usr/local/bin /usr/local/share/applications
incoming=$BASE/.incoming-$$
install -d -m 755 "$incoming/compat/lib"
cp -a "$tmp/vendor/usr/local/awesun" "$incoming/awesun"
cp -a "$compat_source"/libwebkit2gtk-4.1.so* "$incoming/compat/lib/"
cp -a "$compat_source"/libjavascriptcoregtk-4.1.so* "$incoming/compat/lib/"
cp -a "$compat_source"/libicu*.so* "$incoming/compat/lib/"
cp -a "$compat_source"/libjxl*.so* "$incoming/compat/lib/"
cp -a "$compat_source"/libxml2.so* "$incoming/compat/lib/"
cp -a "$compat_source/webkit2gtk-4.1" "$incoming/compat/lib/"
install -m 755 "$ROOT/libsunlogin-fusionfix.so" "$incoming/libsunlogin-fusionfix.so"

save_once() {
    local path=$1 key=$2
    if [[ ! -e $STATE/$key && ! -L $STATE/$key && ! -e $STATE/$key.absent ]]; then
        if [[ -e $path || -L $path ]]; then
            cp -a --no-dereference "$path" "$STATE/$key"
        else
            : > "$STATE/$key.absent"
        fi
    fi
}

save_once /usr/local/awesun previous-awesun
save_once /usr/local/bin/awesun previous-wrapper
save_once /usr/local/share/applications/awesun.desktop previous-desktop
save_once "$WEBKIT_LINK" previous-webkit-link
save_once /etc/systemd/system/runsunloginclient.service.d/official-path.conf previous-service-dropin
save_once /etc/systemd/system/runsunloginclient.service previous-service-unit
save_once /etc/sunlogin-fusionfix-clipboard previous-clipboard-config
save_once /usr/local/bin/sunlogin-fusionfix-clipboard previous-clipboard-command

target=$BASE/$VERSION
if [[ -e $target ]]; then
    mv "$target" "$BASE/.previous-$$"
fi
mv "$incoming" "$target"
if [[ -d /usr/local/awesun && ! -L /usr/local/awesun ]]; then
    rm -rf /usr/local/awesun
fi
ln -sfn "$target/awesun" /usr/local/awesun

install -d -m 755 "$(dirname "$WEBKIT_LINK")"
ln -sfn "$target/compat/lib/webkit2gtk-4.1" "$WEBKIT_LINK"

rm -f /usr/local/bin/awesun /usr/local/bin/sunlogin-fusionfix-clipboard
install -m 755 "$ROOT/awesun-wrapper.sh" /usr/local/bin/awesun
install -m 755 "$ROOT/sunlogin-fusionfix-clipboard" /usr/local/bin/sunlogin-fusionfix-clipboard
rm -f /usr/local/share/applications/awesun.desktop
sed 's#^Exec=.*#Exec=/usr/local/bin/awesun#' \
    "$tmp/vendor/usr/share/applications/awesun.desktop" \
    | sed 's#^Icon=.*#Icon=/usr/local/awesun/awesun.png#' \
    > /usr/local/share/applications/awesun.desktop
chmod 644 /usr/local/share/applications/awesun.desktop
printf '%s\n' "$CLIPBOARD" > /etc/sunlogin-fusionfix-clipboard
chmod 644 /etc/sunlogin-fusionfix-clipboard

install -d -m 755 /etc/systemd/system/runsunloginclient.service.d
if ! systemctl cat runsunloginclient.service >/dev/null 2>&1; then
    cat > /etc/systemd/system/runsunloginclient.service <<'EOF'
[Unit]
Description=AweSun daemon for Sunlogin FusionFix
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/awesun/bin/awesun_daemon -m server -name awesun
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
fi
if [[ ! -e /etc/orayconfig.conf ]]; then
    : > /etc/orayconfig.conf
    : > "$STATE/created-oray-config"
fi
rm -f /etc/systemd/system/runsunloginclient.service.d/official-path.conf
cat > /etc/systemd/system/runsunloginclient.service.d/official-path.conf <<'EOF'
[Service]
ExecStart=
ExecStart=/usr/local/awesun/bin/awesun_daemon -m server -name awesun
EOF
systemctl daemon-reload
systemctl is-active --quiet runsunloginclient.service || systemctl start runsunloginclient.service
echo "Installed Sunlogin FusionFix for AweSun $VERSION."
echo 'Restart the AweSun GUI to load the shim; active sessions were not interrupted.'
echo "Clipboard text opt-in: $CLIPBOARD (change with sudo sunlogin-fusionfix-clipboard on|off)."
