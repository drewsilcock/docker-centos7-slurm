#!/bin/bash
set -o errexit

PYTHON_VERSION="$1"

function cleanup ()
{
    yum clean all
    rm -rf /var/yum/cache
}

trap "cleanup" TERM EXIT

function install_from_source ()
{
    declare -A VERSIONS

    VERSIONS=( ["3.7"]="3.7.9" ["3.8"]="3.8.6" ["3.9"]="3.9.0" )
    PYVER="${VERSIONS[$PYTHON_VERSION]}"
    PYURL="https://www.python.org/ftp/python/${PYVER}/Python-${PYVER}.tgz"

    case "${PYTHON_VERSION}" in
        3.7|3.8|3.9) BUILD_ARGS=("--enable-optimizations" "--with-ensurepip=install") ;;
    esac

    wget "${PYURL}"
    tar xzf "Python-${PYVER}.tgz"
    pushd Python-"${PYVER}"

    export CFLAGS="-D_GNU_SOURCE -fPIC -fwrapv"
    export CXXFLAGS="-D_GNU_SOURCE -fPIC -fwrapv"
    export OPT="-D_GNU_SOURCE -fPIC -fwrapv"
    export LINKCC="gcc"
    export CC="gcc"

    ./configure --enable-ipv6 --enable-shared --with-system-ffi "${BUILD_ARGS[@]}"

    case "${PYTHON_VERSION}" in
        3.7|3.8|3.9) make altinstall ;;
    esac

    unset CFLAGS CXXFLAGS OPT LINKCC CC
    popd
    rm -rf Python-"${PYVER}"*

    echo "/usr/local/lib" > /etc/ld.so.conf.d/python.conf
    chmod 0644 /etc/ld.so.conf.d/python.conf
    /sbin/ldconfig

    "pip${PYTHON_VERSION}" install Cython pytest
}

function centos_install_ius ()
{
    rpm -q ius-release || yum -y install https://repo.ius.io/ius-release-el7.rpm
    rpm --import --verbose /etc/pki/rpm-gpg/RPM-GPG-KEY-IUS-7
}

printf "Installing Python %s\n" "${PYTHON_VERSION}"
yum makecache fast

case "${PYTHON_VERSION}" in
    3.6)
        centos_install_ius
        yum -y install python"${PYTHON_VERSION//.}"u{,-devel,-pip}
        ;;
    3.7|3.8|3.9)
        install_from_source ;;
    *)
        echo "Python version not supported!"
        exit 1
        ;;
esac

"pip${PYTHON_VERSION}" install Cython nose pytest
