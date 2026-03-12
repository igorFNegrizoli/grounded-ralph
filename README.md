# ralph-on-detention

<img width="941" height="710" alt="image" src="https://github.com/user-attachments/assets/ecf7520c-1679-4671-9dc4-9fdf1dfe4ed6" />

Runs the [Ralph autonomous coding loop](https://ghuntley.com/ralph/) inside an isolated Podman container, with optional pass-through to the host's Podman socket so the agent can manage application containers during development.

Designed for immutable OS setups (Fedora Atomic, Silverblue, etc.) where Docker is replaced by Podman and tooling lives in containers.

---

## How it works

```
Host
├── start.sh          — builds image, creates/reattaches container
│
Container (ralph-on-detention)
├── Claude Code CLI   — the agent runtime
├── /workspace/       — bind-mounted project code
├── ralph.sh          — iterative loop runner
│
Ralph loop (per iteration)
├── reads prd.json    — picks highest-priority story with passes=false
├── implements story  — writes code, runs quality checks
├── commits           — "feat: US-001 - [title]"
└── updates prd.json  — sets passes=true, appends to progress.txt
```

Each Ralph iteration spawns a fresh Claude Code instance. State persists across iterations via git history, `prd.json`, and `progress.txt`.

---

## Prerequisites

- Podman (or Docker with compatible CLI)
- `podman-compose` or `docker compose` on the host if your project uses Compose
- Git config at `~/.gitconfig`
- Claude Code credentials at `~/.claude/`

Optional (for host container management from inside Ralph):

```bash
systemctl --user enable --now podman.socket
```

---

## Usage

### Start the container

```bash
./start.sh              # with Podman socket passthrough (auto-detected)
./start.sh --isolated   # no socket — agent cannot manage host containers
```

If a container named `ralph-on-detention` already exists, the script reattaches to it. Otherwise it builds the image and creates a new one.

### Inside the container

```bash
# Create a PRD using the /prd skill (Claude Code slash command)
cd /workspace/my-project
/prd "Add dark mode to the dashboard"

# Convert markdown PRD to prd.json
/ralph path/to/prd.md

# Run the Ralph loop (default: 10 iterations, tool: amp)
/workspace/ralph.sh --tool claude        # use Claude Code
/workspace/ralph.sh --tool amp           # use Amp (default)
/workspace/ralph.sh --tool claude 20     # 20 max iterations
```

Ralph exits `0` when all stories pass. Exits `1` if max iterations are reached without full completion.

---

## prd.json format

```json
{
  "project": "my-app",
  "branchName": "ralph/dark-mode",
  "description": "Add dark mode support",
  "userStories": [
    {
      "id": "US-001",
      "title": "Toggle button in navbar",
      "description": "...",
      "acceptanceCriteria": ["...", "..."],
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
```

`branchName` doubles as the archive key — when it changes between runs, the old `prd.json` and `progress.txt` are moved to `archive/YYYY-MM-DD-<branch>/` and the log resets.

---

## Mounts

| Host path | Container path | Notes |
|-----------|---------------|-------|
| `$PROJECT_ROOT` | `/workspace/$PROJECT_NAME` | Project code, `:Z` (SELinux relabel) |
| `~/.claude/` | `/root/.claude/` | Credentials, symlinks dereferenced |
| `~/.gitconfig` | `/root/.gitconfig` | Read-only |
| `deps/ralph/ralph.sh` | `/workspace/ralph.sh` | Loop runner |
| `deps/ralph/CLAUDE.md` | `/workspace/CLAUDE.md` | Agent instructions |
| `deps/ralph/skills/` | `/workspace/skills/` | `/prd`, `/ralph` slash commands |
| Podman socket (optional) | `/run/user/1000/podman/podman.sock` | Omitted with `--isolated` |

---

## Security notes

- **Git push is disabled** inside the container via `git config`. Commits are local only; you push manually after review.
- **SSH is disabled** inside the container.
- **Socket mode**: with the Podman socket mounted, the agent can run `docker build`, `docker compose up`, etc. on the host. Use `--isolated` for untrusted projects or when you don't need this.
- The container runs with the host user's UID via `--userns=keep-id`.

---

## License

MIT
