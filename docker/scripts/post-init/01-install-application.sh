info "**update magento credentials"
cd /bitnami/magento
mkdir -p /bitnami/magento/var/composer_home/
cat <<END > /bitnami/magento/var/composer_home/auth.json
{
    "http-basic": {
        "repo.magento.com": {
            "username": "$MAGENTO_MARKETPLACE_PUBLIC_KEY",
            "password": "$MAGENTO_MARKETPLACE_PRIVATE_KEY"
        }
    }
}
END

chown -R daemon:daemon /bitnami/magento/var/composer_home/

info "**Enabling Maintenance Mode**"
bin/magento maintenance:enable

info "**Installing Sample Application"


php bin/magento config:set dev/js/minify_files 1  && \
php bin/magento config:set dev/css/minify_files 1 && \
php bin/magento config:set dev/js/enable_js_bundling 1 &&
php bin/magento config:set dev/css/merge_css_files 1 &&
php bin/magento config:set dev/static/sign 1 &&
php bin/magento config:set dev/js/minify_files 1 && \
php -d memory_limit=-1 bin/magento sampledata:deploy && \
php bin/magento setup:upgrade && \
php bin/magento setup:di:compile && \
php -d memory_limit=-1  bin/magento setup:static-content:deploy -f --area=frontend en_US && \
php bin/magento cache:flush

info "**disabling maintenance mode**"
bin/magento maintenance:disable

