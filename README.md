# Perlmutter NeMo-Skills Claude Code Skills

A collection of [Claude Code](https://claude.ai/code) agent skills for running [NeMo-Skills](https://github.com/NVIDIA/NeMo-Skills) jobs on NERSC Perlmutter against an external OpenAI-compatible API endpoint.

Each skill handles the full lifecycle automatically: sshproxy MFA certificate, remote preflight checks, optional container image build, job submission, polling, and result retrieval.

## Skills

| Skill | NeMo-Skills command | Purpose |
|---|---|---|
| [`perlmutter-nemo-generate`](./perlmutter-nemo-generate/) | `ns generate` | LLM inference over `input.jsonl` with a `prompt.yaml` |
| [`perlmutter-nemo-eval`](./perlmutter-nemo-eval/) | `ns eval` / `ns robust_eval` | Benchmark evaluation; produces `metrics.json` |

## Prerequisites

The local machine running Claude Code needs:

| Tool | Purpose |
|---|---|
| `python3` | Creates the managed virtualenv |
| `ssh` / `scp` | Connects to Perlmutter |
| `sshproxy` | Acquires NERSC MFA certificate |

A NERSC account with access to `pscratch` and permission to run `podman-hpc` on Perlmutter is also required.

## Install

**1. Clone this repo**

```bash
git clone https://github.com/FLlorente/perlmutter-ns-skill.git ~/perlmutter-ns-skills
```

**2. Symlink each skill into Claude Code's skills directory**

Claude Code auto-loads skills placed under `~/.claude/skills/`. Symlink the subdirectory for each skill you want:

```bash
# Both skills (recommended)
ln -s ~/perlmutter-ns-skills/perlmutter-nemo-generate \
      ~/.claude/skills/perlmutter-nemo-generate

ln -s ~/perlmutter-ns-skills/perlmutter-nemo-eval \
      ~/.claude/skills/perlmutter-nemo-eval
```

You only need to clone once. Each skill is an independent subdirectory; install as many as you need.

**3. Initialise the NeMo-Skills submodule**

The Perlmutter-enabled NeMo-Skills fork is included as a git submodule. From the repo root:

```bash
cd ~/perlmutter-ns-skills
git submodule update --init
```

This checks out the fork into `Skills/`. Set `NEMO_SKILLS_REPO_DIR` to that absolute path in your env file.

> **Note:** The upstream fork may be a private repository. If `git submodule update --init`
> fails with a 404 or authentication error, request access from the repository owner before
> retrying.

**4. Create your env file**

Each skill has its own `env_vars.example`. Copy it to a private file **outside version control** and fill in your credentials:

```bash
# For generate:
cp ~/perlmutter-ns-skills/perlmutter-nemo-generate/env_vars.example \
   ~/my_generate_env_vars

# For eval:
cp ~/perlmutter-ns-skills/perlmutter-nemo-eval/env_vars.example \
   ~/my_eval_env_vars
```

Both skills share the same core variables (endpoint, SSH key, NERSC account, scratch paths, image tag). The eval skill adds `BENCHMARK`, `JOB_TYPE`, and a few optional tuning vars.

## Invoking a skill

Open a Claude Code session and paste the relevant starter prompt, substituting the bracketed values. See each skill's README for the full prompt template:

- [perlmutter-nemo-generate/README.md](./perlmutter-nemo-generate/README.md#invoking-the-skill)
- [perlmutter-nemo-eval/README.md](./perlmutter-nemo-eval/README.md#invoking-the-skill)

## Container image

On first run each skill checks whether `PERLMUTTER_IMAGE_NAME` exists in your Perlmutter account. If missing, it builds and migrates a minimal image using `perlmutter-nemo-generate/templates/Containerfile.minimal.tmpl`. This takes a few minutes but only happens once; subsequent runs reuse the cached image. Both skills use the same image.

## Local virtualenv

On first run the skill creates an isolated virtualenv under `~/.cache/perlmutter-nemo-generate/` (keyed by `NEMO_SKILLS_REPO_DIR`) and installs the NeMo-Skills fork editable. This is reused across both skills and across runs as long as `pyproject.toml` and requirements files are unchanged.

## Keeping skills up to date

```bash
cd ~/perlmutter-ns-skills
git pull
git submodule update
```

The symlinks in `~/.claude/skills/` always point to the live working copy, so there is nothing else to update.
