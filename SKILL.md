---
name: "perlmutter-nemo-generate"
description: "Use when the user wants to run API-backed NeMo-Skills generation on NERSC Perlmutter with sshproxy MFA, podman-hpc image bootstrap, remote preflight checks, job submission, polling, and result retrieval. Require an absolute env file, an absolute local input.jsonl path, an absolute local prompt.yaml path, and a supported model."
---

# Perlmutter NeMo Generate

Use this skill for one job shape only:
- `ns generate`
- `server_type=openai`
- Perlmutter `executor: slurm`
- Perlmutter `runtime: podman-hpc`
- external OpenAI-compatible endpoint

Do not use this skill for `ns eval`, sidecars, self-hosted vLLM, or multi-component jobs.

## Install

Claude Code discovers skills placed under `~/.claude/skills/`. Clone this repo directly into that directory so the skill is auto-loaded:

```bash
git clone https://github.com/FLlorente/perlmutter-ns-skill.git ~/.claude/skills/perlmutter-nemo-generate
```

Then:

1. Copy [env_vars.example](./env_vars.example) to a private absolute-path env file outside version control.
2. Fill in the env file, especially `NEMO_SKILLS_REPO_DIR`, the private-key path in `SSH_LOGIN_IDENTITY`, NERSC account values, scratch paths, and image tag.
3. Use the starter text in [user_prompt](./user_prompt) when invoking the skill.

## Local prerequisites

The local machine running Codex must already have:
- `python3`
- `ssh`
- `scp`
- `sshproxy`

On first use, the skill creates or reuses an isolated local virtualenv and installs the modified NeMo-Skills repo there so it can run the correct `ns` CLI. It does not install or upgrade packages in the user's active Python environment.
If `setuptools`, `wheel`, or repo dependencies are not already available locally, first use may require internet access to populate the managed virtualenv.

## Inputs

The user must provide:
- an absolute local env file path
- an absolute local `input.jsonl` path
- an absolute local `prompt.yaml` path
- a supported `model`

Supported models live in [config/supported_models.txt](./config/supported_models.txt).

## Env var contract

Require these variables from the env file:
- `OPENAI_BASE_URL`
- `NERSC_USER`
- `SSH_LOGIN_IDENTITY`
- `NERSC_ACCOUNT`
- `NERSC_QOS`
- `NERSC_CONSTRAINT`
- `NERSC_JOB_DIR`
- `REMOTE_WORKSPACE_ROOT`
- `PERLMUTTER_IMAGE_NAME`
- `NEMO_SKILLS_REPO_DIR`

Require at least one API key variable:
- `OPENAI_API_KEY`
- `NVIDIA_API_KEY`

Optional vars:
- `NERSC_HOST` default `perlmutter.nersc.gov`
- `SSH_IDENTITY` defaults to `<SSH_LOGIN_IDENTITY>-cert.pub`
- `NODES` default `1`
- `NTASKS_PER_NODE` default `1`
- `DEFAULT_TIMEOUT` default `00:20:00`
- `HF_HOME_IN_WORKSPACE` default `/workspace/hf-cache`
- `REMOTE_IMAGE_BUILD_DIR` default `$HOME/ns-image-build`
- `STATUS_POLL_INTERVAL` default `30`
- `PERLMUTTER_BASE_IMAGE` default `docker.io/library/python:3.11`
- `PERLMUTTER_AGENT_RUNS_DIR` to override where local run artifacts are stored
- `PERLMUTTER_AGENT_STATE_DIR` to override where the managed local virtualenv is stored

The explicit repo path in `NEMO_SKILLS_REPO_DIR` must point to the Perlmutter-enabled NeMo-Skills checkout. The scripts validate the repo shape and reject checkouts that do not contain the required Perlmutter files.

The local CLI contract is:
- the skill never trusts `ns` from `PATH`
- the skill creates or reuses a managed virtualenv under `~/.cache/perlmutter-nemo-generate` by default
- the modified repo is installed into that managed virtualenv with `pip install -e`
- the rendered submission script uses that managed `ns` binary explicitly

The image contract is simple:
- `PERLMUTTER_IMAGE_NAME` is the tag the skill will look for on Perlmutter.
- If that tag already exists, the skill reuses it.
- If that tag is missing, the skill builds the minimal podman-hpc image defined by [templates/Containerfile.minimal.tmpl](./templates/Containerfile.minimal.tmpl) and migrates it.
- The user does not need to know a separate image "type"; the skill manages one image shape for this workflow.

## Source of truth

Resolve the workflow from the repo referenced by `NEMO_SKILLS_REPO_DIR`, not from memory:
- `<repo_dir>/docs/basics/perlmutter.md`
- `<repo_dir>/ns-tests/test_api_perlmutter.sh`
- `<repo_dir>/ns-tests/cluster_configs/perlmutter.yaml`
- `<repo_dir>/nemo_skills/pipeline/utils/cluster.py`

## Initial prompt

Use this starter prompt with the user:

`Use the Perlmutter NeMo generation skill. My env vars file is <ABS_ENV_VARS>, and it already defines the endpoint, API keys, NERSC account details, SSH private-key path, NEMO_SKILLS_REPO_DIR for the Perlmutter-enabled NeMo-Skills checkout, remote workspace defaults, and the target image tag. My local input file is <ABS_INPUT_JSONL>, my local prompt file is <ABS_PROMPT_YAML>, and my model is <MODEL_NAME>. Validate the required local tools and repo path, create or reuse the managed isolated local virtualenv for the modified repo, verify sshproxy access, verify Perlmutter access, verify the podman image, and if the image is missing build, test, and migrate the minimal image in my NERSC account. Do not install into my active local environment. Then render perlmutter.yaml and run.sh, upload the input and prompt files, submit the generation job, monitor it until completion, fetch the results locally, and report the local result path and any logs. Do not print secrets.`

## Workflow

1. Validate inputs.
   - Require absolute local paths for the env file, `input.jsonl`, and `prompt.yaml`.
   - Reject unsupported models with the allowlist file.

2. Validate the explicit repo path from the env file.
   - Load `NEMO_SKILLS_REPO_DIR` from the env file.
   - Reject the run if the repo path is missing, not absolute, or does not contain the required Perlmutter-enabled files.
   - Never assume a sibling `Skills/` checkout.
   - Never clone or install the repo automatically.

3. Ensure MFA-backed SSH access is live.
   - Run [scripts/ensure_sshproxy.sh](./scripts/ensure_sshproxy.sh).
   - Treat `sshproxy` as interactive and wait for the user to complete MFA.

4. Run preflight checks before every submission.
   - Run [scripts/check_remote_access.sh](./scripts/check_remote_access.sh) without `--require-image`.
   - Then run it with `--require-image`.
   - If it exits with code `3`, the target image is missing.

5. If the image is missing, build it.
   - Run [scripts/build_remote_image.sh](./scripts/build_remote_image.sh).
   - Re-run the image preflight check after build and migration.

6. Prepare the run bundle.
   - Run [scripts/prepare_run.sh](./scripts/prepare_run.sh).
   - This renders:
     - `perlmutter.yaml`
     - `run.sh`
     - `manifest.json`

7. Stage user files.
   - Run [scripts/stage_inputs.sh](./scripts/stage_inputs.sh).
   - Always copy the user files into the remote mounted workspace first.
   - Never rely on untracked local files being packaged by NeMo-Run.

8. Submit the job.
   - Run [scripts/submit_run.sh](./scripts/submit_run.sh).

9. Poll until completion.
   - Run [scripts/check_status.sh](./scripts/check_status.sh) with `--wait`.
   - Success requires the remote `output.jsonl.done` file.

10. Fetch outputs.
   - Run [scripts/fetch_results.sh](./scripts/fetch_results.sh).

## Behavior constraints

- Never print the contents of the env file.
- Never echo secret values from API keys or SSH settings.
- Always keep `perlmutter.yaml` run-specific; do not edit shared checked-in templates in place.
- Always mount the run-specific remote directory to `/workspace`.
- Always submit from the repo pointed to by `NEMO_SKILLS_REPO_DIR` so NeMo-Run packages the correct code.
- The `run.sh` template uses `cd /tmp` before invoking `ns generate`. Do not change this to `cd "$SCRIPT_DIR"`. NeMo-Skills' `get_packager()` checks the process CWD for a git repo; if the CWD is inside any git repo (including this skill's own repo), `GitArchivePackager` fires and fails on uncommitted run artifacts. Running from `/tmp` forces the safe `PatternPackager` path.
- Preflight checks are mandatory on every run. Do not treat them as optional health checks.

## Final response

The final user-facing reply must include:
- whether the job succeeded or failed
- the local fetched `output.jsonl` path
- the local fetched log directory or submission log path
- the image tag used
- a short failure summary if any step failed
