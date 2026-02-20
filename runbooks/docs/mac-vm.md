# mac-vm Runbook (Tailscale)

Purpose: secure remote access to Mac VM/host for autonomous operations.

## Owner

> **Setup Required**: Configure your account email in this runbook.

- Account: `{{OWNER_EMAIL}}`
- Device class: MacBook M2 control plane

## Preconditions

- Tailscale installed on both controller and target.
- Both devices authenticated to same tailnet.
- SSH enabled on target (`System Settings -> Sharing -> Remote Login`).

## Setup

1. Install Tailscale:

```bash
brew install tailscale
```

2. Start and login:

```bash
sudo tailscaled
sudo tailscale up
```

3. Verify status:

```bash
tailscale status
tailscale ip -4
```

4. Confirm target reachability:

```bash
ping <tailscale-ip>
ssh <user>@<tailscale-ip>
```

## Operational Commands

```bash
# list tailnet devices
tailscale status

# open SSH session
ssh <user>@<tailscale-ip>

# copy artifact
scp ./artifact <user>@<tailscale-ip>:/tmp/
```

## Security Rules

- Use SSH keys, not passwords.
- Disable broad ACLs; least privilege only.
- Rotate keys on device changes.
- Do not store secrets in this runbook.

## Troubleshooting

- `tailscale: command not found`: install with `brew install tailscale`.
- Device missing in `tailscale status`: re-auth with `tailscale up`.
- SSH fails: verify Remote Login and firewall rules on target.
