FROM quay.io/keycloak/keycloak:25.0.6

# Stay as keycloak user (no additional packages needed)
USER keycloak

# Copy template, scripts, and themes
COPY --chown=keycloak:keycloak realm-export.json.template /opt/keycloak/data/import/
COPY --chown=keycloak:keycloak scripts/start-with-template.sh /opt/keycloak/bin/
COPY --chown=keycloak:keycloak themes/ /opt/keycloak/themes/

# Make script executable
RUN chmod +x /opt/keycloak/bin/start-with-template.sh

# Build optimized Keycloak
RUN /opt/keycloak/bin/kc.sh build \
    --db=postgres \
    --features=token-exchange,admin-fine-grained-authz \
    --health-enabled=true

# Set default configuration
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true
ENV KC_HTTP_ENABLED=true
ENV KC_HOSTNAME_STRICT=false
ENV KC_HOSTNAME_STRICT_HTTPS=false
ENV KC_PROXY=edge

# refer: https://scim-for-keycloak.de/
# COPY --chown=keycloak:keycloak providers/ /opt/keycloak/providers/
# ENV KC_SPI_THEME_WELCOME_THEME=scim
# ENV KC_SPI_REALM_RESTAPI_EXTENSION_SCIM_LICENSE_KEY=xxx

EXPOSE 3000
EXPOSE 8443
EXPOSE 9000

ENTRYPOINT ["/opt/keycloak/bin/start-with-template.sh"]
