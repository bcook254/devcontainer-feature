
set -e

echo "Installing pip packages: ${PACKAGES}"

python -m pip install ${PACKAGES}

echo 'Done!'
