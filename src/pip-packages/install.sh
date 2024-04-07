
set -e

echo "Installing pip packages: ${PACKAGES}"

python3 -m pip install ${PACKAGES}

echo 'Done!'
