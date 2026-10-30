# paperless-railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/paperless-ngx-or-just-updated-document-m?referralCode=Z1xivh&utm_medium=integration&utm_source=template&utm_campaign=generic)

**Deploy on Railway:** [Paperless-ngx template](https://railway.com/deploy/paperless-ngx-or-just-updated-document-m?referralCode=Z1xivh&utm_medium=integration&utm_source=template&utm_campaign=generic)

Wrapper image for running [Paperless-ngx](https://github.com/paperless-ngx/paperless-ngx)
3.1.1 on [Railway](https://railway.com), published as
`ghcr.io/bon5co/paperless-railway:3.1.1`.

The official image assumes a docker-compose environment. On Railway it needs four
changes, none of which can be made from the template's variables panel:

1. **It honours the injected `$PORT`.** The webserver reads `PAPERLESS_PORT` /
   `GRANIAN_PORT`, and Railway's HTTP healthcheck dials the port it injects rather
   than the domain's target port.
2. **It refuses to boot without an admin credential.** Upstream's `init-superuser`
   step logs `Not creating superuser` and continues when `PAPERLESS_ADMIN_USER` is
   empty, which leaves a healthy-looking instance with no account — and Paperless
   has no signup page and no reset path without SMTP.
3. **It applies the admin credential on every boot.** Upstream's
   `manage_superuser` returns early once the user (or any superuser) exists, so the
   password is otherwise fixed forever at whatever the first boot used. Re-applying
   it makes a redeploy a working reset.
4. **It sizes the OCR thread pool from the container's CPU quota.** Paperless
   derives `THREADS_PER_WORKER` from `multiprocessing.cpu_count()`, which reports
   the host's core count inside a cgroup-limited container (measured: 5 in a
   `--cpus 2` container), so ocrmypdf oversubscribes the plan on every document.

Everything durable lives under one volume at `/data`: the data dir, media, and the consume directory.

## Variables

| Variable | Purpose |
| --- | --- |
| `PAPERLESS_ADMIN_PASSWORD` | Required. The container exits with a readable message if it is empty. |
| `PAPERLESS_ADMIN_USER` | Defaults to `admin`. |
| `PAPERLESS_SECRET_KEY` | Django secret key. |
| `PAPERLESS_URL` | The public URL of the deployment, for CSRF/allowed hosts. |
| `PAPERLESS_DBHOST`, `PAPERLESS_DBUSER`, `PAPERLESS_DBPASS`, `PAPERLESS_DBNAME` | Postgres connection. |
| `PAPERLESS_REDIS` | Redis connection URL. |

## Licence

Paperless-ngx is GPL-3.0. This repository only adds packaging for Railway.
