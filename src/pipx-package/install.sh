#!/usr/bin/env bash

PACKAGE=${PACKAGE}
PACKAGE_VERSION=${VERSION}
INJECTIONS=${INJECTIONS}
FORCEINSTALL=${FORCEINSTALL}
INCLUDEDEPS=${INCLUDEDEPS}
INCLUDEAPPS=${INCLUDEAPPS}

#  PEP 668  compatibility 
export PIP_BREAK_SYSTEM_PACKAGES=1

if [ "$(id -u)" -ne 0 ]; then
    echo -e "❌ Script must be run as root"
    exit 1
fi

# Bring in ID, ID_LIKE, VERSION_ID, VERSION_CODENAME
. /etc/os-release
# Get an adjusted ID independent of distro variants
if [ "${ID}" = "debian" ] || [ "${ID_LIKE}" = "debian" ]; then
    ADJUSTED_ID="debian"
elif [[ "${ID}" = "rhel" || "${ID}" = "fedora" || "${ID}" = "mariner" || "${ID_LIKE}" = *"rhel"* || "${ID_LIKE}" = *"fedora"* || "${ID_LIKE}" = *"mariner"* ]]; then
    ADJUSTED_ID="rhel"
    VERSION_CODENAME="${ID}{$VERSION_ID}"
elif [ "${ID}" = "alpine" ]; then
    ADJUSTED_ID="alpine"
else
    echo "❌ Linux distro ${ID} not supported"
    exit 1
fi

check_pipx() {
    if ! type pipx >/dev/null 2>&1; then
        echo "❌ Pipx not installed"
        exit 1
    fi

    if getent group pipx >/dev/null 2>&1; then
        echo "Creating system group 'pipx'"
        groupadd -r pipx
    fi
    usermod -a -G pipx "${_REMOTE_USER}"

    PIPX_HOME=${PIPX_HOME:-"/usr/local/py-utils"}
    PIPX_BIN_DIR="${PIPX_BIN_DIR:-"${PIPX_HOME}/bin"}"
    if [[ "${PATH}" != *"${PIPX_BIN_DIR}"* ]]; then
        PATH="${PIPX_BIN_DIR}:${PATH}"
    fi

    mkdir -p "${PIPX_HOME}"
    mkdir -p "${PIPX_BIN_DIR}"
    chown -R "${_REMOTE_USER}:pipx" "${PIPX_HOME}"
    chmod g+rw "${PIPX_HOME}"
    find "${PIPX_HOME}" -type d -print0 | xargs -0 -n 1 chmod g+s

    for pipx_var in "export PIPX_HOME=\"${PIPX_HOME}\"" "export PIPX_BIN_DIR=\"${PIPX_BIN_DIR}\"" "if [[ \"\${PATH}\" != *\"\${PIPX_BIN_DIR}\"* ]]; then export PATH=\"\${PATH}:\${PIPX_BIN_DIR}\"; fi"
    do
        if [ "${ADJUSTED_ID}" == "alpine" ] && ! grep -qxF "${pipx_var}" /etc/profile; then
            echo -e "${pipx_var}" >> /etc/profile
        fi
        for bashrc in "/etc/bashrc" "/etc/bash.bashrc"
        do
            if [ -f "${bashrc}" ] && ! grep -qxF "${pipx_var}" "${bashrc}"; then
                echo -e "${pipx_var}" >> "${bashrc}"
                # Exit if a file was found to avoid double setting variables
                break
            fi
        done
        if [ -f "/etc/zsh/zshrc" ] && ! grep -qxF "${pipx_var}" /etc/zsh/zshrc; then
            echo -e "${pipx_var}" >> /etc/zsh/zshrc
        fi
    done
}

pipx_install() {
    if [ "${FORCEINSTALL}" == "true" ] || ! pipx list --short | grep -q "$PACKAGE" ; then
        if [ "$PACKAGE_VERSION" == "latest" ]; then
            _package="$PACKAGE"
        else
            _package="$PACKAGE==$PACKAGE_VERSION"
        fi

        args=()
        if [ "${INCLUDEDEPS}" == "true" ]; then
            args+=("--include-deps")
        fi
        args+=("--force" "${_package}")
        if pipx install --pip-args '--no-cache-dir --force-reinstall' "${args[@]}"; then
            echo "✅ Successfully installed pipx package ${_package}"
        else
            echo "❌ Failed to install pipx package ${_package}."
            exit 2
        fi
    else
        echo "✅ $PACKAGE already installed"
    fi
}

pipx_inject() {
    IFS=", " read -r -a _injections <<< "${INJECTIONS}"
    for injection in "${_injections[@]}"
    do
        args=()
        if [ "${INCLUDEAPPS}" == "true" ]; then
            args+=("--include-apps")
        fi
        args+=("--force" "${PACKAGE}" "${injection}")
        if pipx inject --pip-args '--no-cache-dir --force-reinstall' "${args[@]}"; then
            echo "✅ Successfully injected ${injection} in to pipx package ${PACKAGE}"
        else
            echo "❌ Failed to inject ${injection} in to pipx package ${PACKAGE}."
            exit 2
        fi
    done
}

check_pipx

pipx_install
pipx_inject