#!/bin/bash

# Prerequisites
# sudo apt install -y packaging-dev debian-keyring devscripts equivs sbuild schroot debootstrap
# sudo sbuild-adduser ${USER}


WORKDIR=${HOME}/build-backports
RELEASE=bookworm
PACKAGE=emacs-non-dfsg
DCH_COMMENT=""    # Or something more interesting

COMPONENT=non-free
SBUILD_DIR_SUFFIX=""
SBUILD_TARGET_DIR="${RELEASE}-backports${SBUILD_DIR_SUFFIX}"
SBUILD_EXTRA_REPOS=(
    "deb http://deb.debian.org/debian ${RELEASE}-backports main" 
    "deb http://deb.debian.org/debian testing main"
)
SBUILD_EXTRA_PACKAGES=(
    msmtp-mta
    emacs-el/bookworm-backports
    emacs-nox/bookworm-backports
    texinfo-lib/testing
    texinfo/testing
)
VERSION=$(curl -s "https://api.ftp-master.debian.org/madison?package=emacs-non-dfsg&s=testing&f=json" | jq -r '.[0]|to_entries[0].value|to_entries[0].value|to_entries[0].key' | perl -p -e 's@[0-9]+:@@')

LAST_VERSION=${VERSION}   # might be trickier if there were changelog entries from past backport versions.

URL="http://deb.debian.org/debian/pool/${COMPONENT}/$(echo $PACKAGE|cut -c 1)/${PACKAGE}/${PACKAGE}_${VERSION}.dsc"

cat <<EOF
#!/bin/bash -e

if [[ ("\${DEBEMAIL}" == "") || ("\${DEBFULLNAME}" == "") ]] ;
  then echo Please set DEBEMAIL and DEBFULLNAME
  exit 1
fi

mkdir -p "${WORKDIR}/${PACKAGE}"
cd "${WORKDIR}/${PACKAGE}"
dget "$URL"
cd "${PACKAGE}-$(echo ${VERSION} | perl -p -e 's@-[0-9]+$@@')"
dch --bpo "${DCH_COMMENT}"

sudo sbuild-createchroot --chroot-prefix=${RELEASE}-backports ${RELEASE} /srv/chroot/${SBUILD_TARGET_DIR} http://deb.debian.org/debian
EOF
for REPO in "${SBUILD_EXTRA_REPOS[@]}"; do
    cat <<EOF
echo "'${REPO}' | cat >> /etc/apt/sources.list" | sudo sbuild-shell ${SBUILD_TARGET_DIR}
EOF
done

cat <<EOF
echo "apt update && apt install -y ${SBUILD_EXTRA_PACKAGES[@]}" | sudo sbuild-shell ${SBUILD_TARGET_DIR}
sbuild --build-dep-resolver=aptitude --debbuildopts="-v${LAST_VERSION}"
EOF
