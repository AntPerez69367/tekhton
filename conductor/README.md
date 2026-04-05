# Tekhton Conductor

Autonomous milestone progression daemon for Tekhton. Runs as a Docker container on Valette, driving Tekhton milestone completion overnight while you sleep.

## What It Does

- Reads the milestone manifest and walks the DAG in dependency order
- For each milestone: creates a branch, runs `--milestone <id>`, runs `--fix-nonblockers` and `--fix-driftlog`, commits, creates a PR, and enables auto-merge
- Tracks API token usage to avoid hitting the 5-hour rolling window ceiling
- On failure, calls the Anthropic API (`claude-opus-4-6`) to analyze the error and decide: retry, fix, diagnose, or stop
- Stops after 3 consecutive failures of the same milestone
- Exposes an HTTP control plane (FastAPI on port 7411) for monitoring and commands

## Deploying on Valette

### 1. Add env vars to `.env`

Add these to your existing `~/Valette-Server/docker/.env`:

```bash
# Tekhton Conductor
TEKHTON_HOME="/path/to/tekhton"
TEKHTON_PROJECT_REPO="/path/to/target-project"
CONDUCTOR_PORT=7411
CONDUCTOR_API_TOKEN=some-random-secret-here
ANTHROPIC_API_KEY=sk-ant-api03-...
```

### 2. Create appdata directory and config

```bash
mkdir -p ~/Valette-Server/docker/appdata/tekhton-conductor/data/{state,logs}

# Copy and edit the config (paths inside are container-internal, not host paths)
cp /path/to/tekhton/conductor/conductor.cfg.example \
   ~/Valette-Server/docker/appdata/tekhton-conductor/conductor.cfg

vi ~/Valette-Server/docker/appdata/tekhton-conductor/conductor.cfg
```

The config uses container-internal paths. The defaults in the example match the compose volume mounts:
- `/tekhton` = Tekhton source (read-only)
- `/repo` = target project (read-write)
- `/data` = persistent state and logs
- `/config` = config file

Set `api_token` to match `CONDUCTOR_API_TOKEN` from `.env`, and `anthropic_api_key` to match `ANTHROPIC_API_KEY`.

### 3. Add to Valette's compose includes

Copy the compose file into your stack directory:

```bash
cp /path/to/tekhton/conductor/tekhton-conductor.yml \
   ~/Valette-Server/docker/compose/valette/tekhton-conductor.yml
```

Add to `docker-compose-valette.yml`:

```yaml
include:
  # ... existing includes ...
  # DEV AUTOMATION
  - "compose/${STACK}/tekhton-conductor.yml"
```

### 4. Build and start

```bash
cd ~/Valette-Server/docker
docker compose -f docker-compose-valette.yml build tekhton-conductor
docker compose -f docker-compose-valette.yml up -d tekhton-conductor
```

### 5. Verify

```bash
curl -H "Authorization: Bearer $CONDUCTOR_API_TOKEN" http://localhost:7411/status
```

## Prerequisites on the Host

The container mounts these from the host (read-only):

- **`~/.ssh/`** -- SSH keys for `git push` to GitHub
- **`~/.config/gh/`** -- GitHub CLI auth (`gh auth login` must have been run)
- **`~/.claude/`** -- Claude Code CLI auth (must have been authenticated)

Ensure the host user (UID matching `PUID`) has all three configured before starting.

## Arming a Night Run

```bash
# Start from next incomplete milestone
curl -X POST http://valette:7411/start-night-run \
  -H "Authorization: Bearer $CONDUCTOR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}'

# Start from a specific milestone
curl -X POST http://valette:7411/start-night-run \
  -H "Authorization: Bearer $CONDUCTOR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"starting_milestone": "m57"}'
```

## Monitoring

```bash
# Full state
curl -s -H "Authorization: Bearer $CONDUCTOR_API_TOKEN" http://valette:7411/status | python3 -m json.tool

# Last 100 log lines
curl -s -H "Authorization: Bearer $CONDUCTOR_API_TOKEN" "http://valette:7411/log?lines=100"

# Docker logs
docker logs tekhton-conductor --tail 50
```

## Reading the Morning Report

Key fields in `/status`:
- `state`: `STOPPED_SUCCESS` = all milestones done. `STOPPED_ERROR` = needs attention.
- `completed_milestones`: list of IDs finished during the night
- `error_history`: timestamped failures
- `accumulated_tokens`: total tokens consumed
- `last_error_output`: stderr/stdout from the last failure

## Stopping

```bash
curl -X POST http://valette:7411/stop -H "Authorization: Bearer $CONDUCTOR_API_TOKEN"
```

## State Machine

```
IDLE -> ARMED -> RUNNING_MILESTONE -> RUNNING_FIXES -> COMMITTING -> IDLE (loop)
                       |                                               ^
                ANALYZING_ERROR --> RETRY / FIX / DIAGNOSE ------------+
                       |
                STOPPED_ERROR
                                          WAITING_FOR_USAGE (retry every 10min)
                                          STOPPED_SUCCESS (all done)
```

## Config Reference

| Key | Description | Default |
|-----|-------------|---------|
| `tekhton_path` | Tekhton repo (container path) | `/tekhton` |
| `manifest_path` | MANIFEST.cfg (container path) | `/repo/.claude/milestones/MANIFEST.cfg` |
| `repo_path` | Target project (container path) | `/repo` |
| `integration_branch` | PR base branch | `feature/Version3` |
| `api_port` | HTTP API port | `7411` |
| `api_token` | Bearer token for auth | -- |
| `anthropic_api_key` | Key for error analysis | -- |
| `usage_window_hours` | Rolling usage window | `5` |
| `usage_safety_threshold` | Wait threshold (fraction) | `0.25` |
| `max_milestone_retries` | Max consecutive failures | `3` |
| `log_path` | Log file (container path) | `/data/logs/conductor.log` |
| `state_path` | State file (container path) | `/data/state/conductor.state.json` |

## Files

| File | Purpose |
|------|---------|
| `conductor.py` | Main daemon: state machine, subprocess execution, error analysis |
| `api.py` | FastAPI control plane (4 endpoints + bearer auth) |
| `Dockerfile` | Container image: Python 3.12 + bash + git + gh + Claude CLI |
| `tekhton-conductor.yml` | Docker Compose service definition for Valette |
| `conductor.cfg.example` | Config template with container-internal paths |
| `requirements.txt` | Python dependencies |
| `tekhton-conductor.service` | systemd unit (alternative to Docker) |
