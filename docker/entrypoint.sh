#!/bin/bash

# shellcheck disable=SC1091

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purpose

# Load Magento environment
. /opt/bitnami/scripts/magento-env.sh

# Load libraries
. /opt/bitnami/scripts/libbitnami.sh
. /opt/bitnami/scripts/liblog.sh
. /opt/bitnami/scripts/libwebserver.sh

print_welcome_page

if [[ "$1" = "/opt/bitnami/scripts/magento/run.sh" || "$1" = "/opt/bitnami/scripts/$(web_server_type)/run.sh" || "$1" = "/opt/bitnami/scripts/nginx-php-fpm/run.sh" ]]; then
    info "** Starting Magento setup **"
    /opt/bitnami/scripts/"$(web_server_type)"/setup.sh
    /opt/bitnami/scripts/php/setup.sh
    /opt/bitnami/scripts/mysql-client/setup.sh
    /opt/bitnami/scripts/magento/setup.sh
    /post-init.sh
    info "** Magento setup finished! **"
fi

info "**update magento"

#TODO: do it only on Admin ?
cd /bitnami/magento
bin/magento config:set web/secure/base_url https://$MAGENTO_HOST/
bin/magento config:set web/unsecure/base_url http://$MAGENTO_HOST/
php bin/magento setup:upgrade && \
php bin/magento setup:static-content:deploy -f && \
php bin/magento cache:flush

echo ""
exec "$@"