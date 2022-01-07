FROM bitnami/magento

WORKDIR /opt/bitnami/magento

USER root

RUN chown -R daemon:daemon /opt/bitnami/
RUN chown -R daemon:daemon /bitnami/magento

USER daemon

COPY scripts/post-init /docker-entrypoint-init.d/

ENTRYPOINT [ "/opt/bitnami/scripts/magento/entrypoint.sh" ]
CMD [ "/opt/bitnami/scripts/magento/run.sh" ]