# ralph-on-detention

<img width="941" height="710" alt="image" src="https://github.com/user-attachments/assets/ecf7520c-1679-4671-9dc4-9fdf1dfe4ed6" />

Runs the [Ralph autonomous coding loop](https://ghuntley.com/ralph/) inside an isolated Podman container, with optional pass-through to the host's Podman socket so the agent can manage application containers during development.

Designed for immutable OS setups (Fedora Atomic, Silverblue, etc.) where Docker is replaced by Podman and tooling lives in containers.

---

## What this project provides

- A **Containerfile** that builds a Fedora-based image with Claude Code CLI, Docker CLI, `just`, Node.js, Python, and language servers pre-installed
- A **`start.sh`** script that builds the image, creates or reattaches to a named container, and wires up all the necessary mounts
- **Optional Podman socket passthrough** so the agent inside the container can run `docker build`, `docker compose up`, etc. on the host — or `--isolated` mode to disable it
- The **Ralph loop** (`deps/ralph/`) is included as a submodule. See [`deps/ralph/`](deps/ralph/) for the loop runner, slash commands, and prd.json documentation.

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

```bash
./start.sh              # with Podman socket passthrough (auto-detected)
./start.sh --isolated   # no socket — agent cannot manage host containers
```

If a container named `ralph-on-detention` already exists, the script reattaches to it. Otherwise it builds the image and creates a new one.

Once inside the container, see [`deps/ralph/README.md`](deps/ralph/README.md) for how to create a PRD, convert it to `prd.json`, and run the Ralph loop.

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
