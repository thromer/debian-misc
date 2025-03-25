#!/bin/bash

# Prerequisites
# sudo apt install -y packaging-dev debian-keyring devscripts equivs sbuild schroot debootstrap
# sudo sbuild-adduser ${USER}


RELEASE=bookworm
RELEASE_FOR_SCHROOT=testing
PACKAGE=emacs-non-dfsg
WORKDIR=${HOME}/build-backports/${PACKAGE}
DCH_COMMENT=""    # Or something more interesting

COMPONENT=non-free
SBUILD_DIR_SUFFIX=""
SBUILD_TARGET_DIR="${RELEASE}-backports${SBUILD_DIR_SUFFIX}"
SBUILD_EXTRA_REPOS=(
)
SBUILD_EXTRA_PACKAGES=(
)
VERSION=$(curl -s "https://api.ftp-master.debian.org/madison?package=emacs-non-dfsg&s=testing&f=json" | jq -r '.[0]|to_entries[0].value|to_entries[0].value|to_entries[0].key' | perl -p -e 's@[0-9]+:@@')
PACKAGE_DIR="${PACKAGE}-$(echo ${VERSION} | perl -p -e 's@-[0-9]+$@@')"

LAST_VERSION=${VERSION}   # might be trickier if there were changelog entries from past backport versions.

URL="http://deb.debian.org/debian/pool/${COMPONENT}/$(echo $PACKAGE|cut -c 1)/${PACKAGE}/${PACKAGE}_${VERSION}.dsc"

cat <<EOF
#!/bin/bash -e

if [[ ("\${DEBEMAIL}" == "") || ("\${DEBFULLNAME}" == "") ]] ; then
  echo Please set DEBEMAIL and DEBFULLNAME
  fail=1
fi
if [[ -e "${WORKDIR}" ]] ; then
  echo ${WORKDIR} is in the way
  fail=1
fi
if [[ -e "/srv/chroot/${SBUILD_TARGET_DIR}" ]] ; then
  echo /srv/chroot/${SBUILD_TARGET_DIR} is in the way. For assistance: run sbuild-destroychroot ${SBUILD_TARGET_DIR}. And check /etc/sbuild/chroot/${SBUILD_TARGET_DIR}*.
  fail=1
fi
if [[ \$fail ]] ; then
  exit 1
fi

mkdir -p "${WORKDIR}" && cd "${WORKDIR}"
dget "$URL"
cd "${PACKAGE}-$(echo ${VERSION} | perl -p -e 's@-[0-9]+$@@')"
dch --bpo "${DCH_COMMENT}"

EOF

if [[ ${RELEASE_FOR_SCHROOT} != ${RELEASE} ]]; then
    echo "# NOTE! The chroot is for release $RELEASE_FOR_SCHROOT, but the package is for $RELEASE"
fi

cat <<EOF
sudo sbuild-createchroot --chroot-prefix=${RELEASE}-backports ${RELEASE_FOR_SCHROOT} /srv/chroot/${SBUILD_TARGET_DIR} http://deb.debian.org/debian
EOF

if [[ ${#SBUILD_EXTRA_PACKAGES[@]} > 0 ]]; then
  for REPO in "${SBUILD_EXTRA_REPOS[@]}"; do
    cat <<EOF
echo "echo '${REPO}' | cat >> /etc/apt/sources.list" | sudo sbuild-shell ${SBUILD_TARGET_DIR}
EOF
  done

  cat <<EOF
echo "apt update && apt install -y ${SBUILD_EXTRA_PACKAGES[@]}" | sudo sbuild-shell ${SBUILD_TARGET_DIR}
EOF
fi

cat <<EOF
sbuild --build-dep-resolver=aptitude --debbuildopts="-v${LAST_VERSION}"
EOF
