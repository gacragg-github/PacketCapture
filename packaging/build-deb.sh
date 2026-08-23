#!/bin/bash
set -euo pipefail

#Build the packetcapture-wifi-tools .deb from the scripts in ../Code and this dir's
#DEBIAN/control. Bump the Version: line in DEBIAN/control before a release that changes
#behavior - dpkg won't let you reinstall the same version over itself with new content.

scriptdir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
codedir="${scriptdir}/../Code"
staging=$(mktemp -d)
trap 'rm -rf "${staging}"' EXIT

mkdir -p "${staging}/DEBIAN" "${staging}/usr/local/bin"
cp "${scriptdir}/DEBIAN/control" "${staging}/DEBIAN/control"
cp "${codedir}/interfaces.sh" "${codedir}/wifisetup.sh" "${staging}/usr/local/bin/"
chmod 755 "${staging}/usr/local/bin/"*.sh
chmod 644 "${staging}/DEBIAN/control"

name=$(awk '/^Package:/ {print $2}' "${scriptdir}/DEBIAN/control")
version=$(awk '/^Version:/ {print $2}' "${scriptdir}/DEBIAN/control")
outfile="${scriptdir}/${name}_${version}_all.deb"

dpkg-deb --build --root-owner-group "${staging}" "${outfile}"
echo "Built ${outfile}"
echo "Install with: sudo apt install ${outfile}"
