#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

usage() {
  cat <<'EOF'
Usage: stage_inputs.sh --manifest <absolute-path>

Create the remote run directory structure and, for robust_eval jobs, upload prompt_set_config.yaml.
EOF
}

manifest=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest) manifest="$2"; shift 2 ;;
    -h|--help)  usage; exit 0 ;;
    *)          die "Unknown argument: $1" ;;
  esac
done

[[ -n "${manifest}" ]] || die "Missing required argument: --manifest"
manifest="$(cd "$(dirname "${manifest}")" && pwd)/$(basename "${manifest}")"
require_file "${manifest}"

env_file="$(json_get "${manifest}" env_file)"
remote_run_dir="$(json_get "${manifest}" remote_run_dir)"
job_type="$(json_get "${manifest}" job_type)"
prompt_set_config_local="$(json_get "${manifest}" prompt_set_config_local_path)"

load_env_file "${env_file}"
require_env_vars NERSC_USER SSH_LOGIN_IDENTITY

ssh_cmd "mkdir -p '${remote_run_dir}/eval' '${remote_run_dir}/ns-data' '${remote_run_dir}/hf-cache'" >/dev/null

if [[ "${job_type}" == "robust_eval" && "${prompt_set_config_local}" != "null" && -n "${prompt_set_config_local}" ]]; then
  scp_to "${prompt_set_config_local}" "${remote_run_dir}/prompt_set_config.yaml"
  note "Staged prompt_set_config.yaml to ${remote_run_dir}"
fi

update_manifest "${manifest}" staged_at "\"$(now_utc)\"" status "\"staged\""
note "Staged remote directories at ${remote_run_dir}"
