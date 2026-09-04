# Codex secure Dev Container Feature

This repository packages the reusable part of the local
`codex-secure-devcontainer-poc` as a Dev Container Feature. It is intended for
trusted repositories opened from WSL2 through VS Code and Docker Desktop.

The Feature:

- installs a pinned Codex CLI through the official Node Feature;
- enables Codex's nested bubblewrap sandbox;
- adds the capabilities used by OpenAI's secure devcontainer reference;
- applies a default-deny IPv4/IPv6 egress firewall at container startup;
- bind-mounts the current WSL distribution's `~/.codex/auth.json` read/write;
- bind-mounts shared agent skills at `/etc/codex/skills` read-only; and
- installs the `openai.chatgpt` VS Code extension.

The Feature currently supports Debian and Ubuntu container images.

## Host prerequisites

Run these commands in each WSL2 distribution before opening a Dev Container:

```bash
test -f "$HOME/.codex/auth.json"
test -d "${AGENTS_SKILLS_DIR:-/mnt/d/codex/agents-skills}"
docker version
```

If the skills directory is not `/mnt/d/codex/agents-skills`, export
`AGENTS_SKILLS_DIR` before starting VS Code from that WSL distribution.

## Use from VS Code User Settings

After the package has been published to GHCR, add this to VS Code's user
`settings.json`:

```jsonc
{
  "dev.containers.defaultFeatures": {
    "ghcr.io/novanmondon/codex-devcontainer-feature/codex-secure:1": {
      "codexVersion": "0.121.0",
      "enableFirewall": true,
      "includeGitHubMetaRanges": true
    }
  }
}
```

The repository's `.devcontainer` does not need to declare the Feature.

## Local test

The test needs the same host bind-mount sources as normal use:

```bash
devcontainer features test --features codex-secure --skip-scenarios .
```

Inside a resulting container, run:

```bash
codex-secure-verify
codex login status
```

## Publish

Push the repository to `novanmondon/codex-devcontainer-feature`. The release
workflow publishes the Feature as an OCI artifact. The first GHCR package is
private by default; change the package visibility to public before adding it to
VS Code's default Features.

## Security boundaries

The bind-mounted `auth.json` contains credentials and is deliberately writable
so Codex can refresh them. Any process in the container that can read the file
can obtain those credentials. Use this Feature only with repositories you
trust.

The firewall permits DNS and therefore cannot prevent DNS exfiltration. GitHub
meta ranges also cover more addresses than a single repository. This is a
defense-in-depth development profile, not a boundary for untrusted code.

`${localEnv:...}` substitution inside Feature mount metadata works in the
current VS Code Dev Containers and Dev Container CLI stack but is not a portable
guarantee of the Feature specification. Pin and test the client versions used by
both WSL distributions.

Feature entrypoints run alongside the image's original entrypoint. The firewall
therefore becomes active during startup rather than before the first container
process. Interactive VS Code use naturally starts after initialization, and
`codex-secure-verify` waits for the readiness marker, but a project lifecycle
command that deliberately performs network access at the earliest possible
startup instant could race initialization. Eliminating that gap requires a
project-owned entrypoint or lifecycle coordination in `.devcontainer`.

## References

- [OpenAI Codex authentication](https://learn.chatgpt.com/docs/auth)
- [OpenAI Codex skills](https://learn.chatgpt.com/docs/build-skills)
- [OpenAI Codex sandboxing](https://learn.chatgpt.com/docs/sandboxing)
- [Authoring a Dev Container Feature](https://containers.dev/guide/author-a-feature)
