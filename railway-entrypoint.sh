#!/usr/bin/env bash
# Railway entrypoint for Paperless-ngx.
#
# Runs as root before s6-overlay starts, so anything exported here is visible to
# every s6 service through with-contenv.
set -euo pipefail

log() { echo "[railway-entrypoint] $*"; }

# 1. Refuse to boot without an admin credential.
#
# Upstream's init-superuser is a no-op when PAPERLESS_ADMIN_USER is empty, and
# Paperless has no signup page and no reset path without SMTP. A deployment that
# boots without a seeded account is a healthy-looking instance nobody can log
# into, so fail loudly instead.
if [[ -z "${PAPERLESS_ADMIN_PASSWORD:-}" ]]; then
	log "FATAL: PAPERLESS_ADMIN_PASSWORD is empty."
	log "Set it in the Railway variables panel and redeploy; the admin account cannot be created without it."
	exit 1
fi
if [[ -z "${PAPERLESS_ADMIN_USER:-}" ]]; then
	export PAPERLESS_ADMIN_USER=admin
fi

# 2. Honour the port Railway injects.
#
# The webserver reads GRANIAN_PORT/PAPERLESS_PORT, not PORT, and Railway's HTTP
# healthcheck dials the injected port rather than the domain's target port.
export PAPERLESS_PORT="${PORT:-8000}"
log "listening on ${PAPERLESS_PORT}"

# 3. Size the OCR thread pool from the container's CPU quota.
#
# settings.py derives THREADS_PER_WORKER from multiprocessing.cpu_count(), which
# in a cgroup-limited container reports the HOST's core count (measured: 5 in a
# --cpus 2 container), so ocrmypdf oversubscribes the quota on every document.
cpu_quota() {
	local line quota period
	if [[ -r /sys/fs/cgroup/cpu.max ]]; then
		read -r line < /sys/fs/cgroup/cpu.max
		quota=${line%% *}
		period=${line##* }
		if [[ "${quota}" != "max" && "${period}" -gt 0 ]]; then
			echo $(( quota / period ))
			return
		fi
	elif [[ -r /sys/fs/cgroup/cpu/cpu.cfs_quota_us && -r /sys/fs/cgroup/cpu/cpu.cfs_period_us ]]; then
		read -r quota < /sys/fs/cgroup/cpu/cpu.cfs_quota_us
		read -r period < /sys/fs/cgroup/cpu/cpu.cfs_period_us
		if [[ "${quota}" -gt 0 && "${period}" -gt 0 ]]; then
			echo $(( quota / period ))
			return
		fi
	fi
	nproc
}
if [[ -z "${PAPERLESS_THREADS_PER_WORKER:-}" ]]; then
	cpus=$(cpu_quota)
	[[ "${cpus}" -lt 1 ]] && cpus=1
	workers="${PAPERLESS_TASK_WORKERS:-1}"
	threads=$(( cpus / workers ))
	[[ "${threads}" -lt 1 ]] && threads=1
	export PAPERLESS_THREADS_PER_WORKER="${threads}"
	log "cpu_quota=${cpus} task_workers=${workers} threads_per_worker=${threads} (visible cores: $(nproc))"
fi

exec /init "$@"
