# Paperless-ngx for Railway.
#
# Wraps the official image. Everything here exists because Railway's template
# system drops literal variable defaults (they would publish as blank required
# fields on the deploy form), and because the upstream image assumes a
# docker-compose environment rather than Railway's one-volume, injected-$PORT one.
FROM ghcr.io/paperless-ngx/paperless-ngx:3.1.1

# Literals baked in so the deploy form asks for nothing that the image already knows.
# All durable state lands under the single Railway volume at /data.
ENV PAPERLESS_DATA_DIR=/data/data \
    PAPERLESS_MEDIA_ROOT=/data/media \
    PAPERLESS_CONSUMPTION_DIR=/data/consume \
    PAPERLESS_ADMIN_USER=admin \
    PAPERLESS_TIME_ZONE=UTC \
    PAPERLESS_OCR_LANGUAGE=eng \
    PAPERLESS_TASK_WORKERS=1

# Create-or-rotate superuser, replacing upstream's create-once script.
COPY init-superuser-run /etc/s6-overlay/s6-rc.d/init-superuser/run
COPY rotate_superuser.py /usr/local/lib/paperless-railway/rotate_superuser.py
COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh

RUN chmod +x /etc/s6-overlay/s6-rc.d/init-superuser/run /usr/local/bin/railway-entrypoint.sh \
    # Fail the build rather than silently shipping stock behaviour if upstream
    # moves the superuser step or the webserver's port variable.
    && test -d /etc/s6-overlay/s6-rc.d/init-superuser/dependencies.d \
    && test -e /etc/s6-overlay/s6-rc.d/init-superuser/dependencies.d/init-migrations \
    && grep -q 'PAPERLESS_PORT' /etc/s6-overlay/s6-rc.d/svc-webserver/run

ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
