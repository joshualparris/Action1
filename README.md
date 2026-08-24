# DadLAN Action1 Command Centre

DadLAN is a small fleet dashboard for managing a lab of Action1-managed computers. The current release is deliberately **read-only**: it connects to Action1, lists endpoints, applies local roles/metadata, filters the fleet, and retrieves endpoint diagnostics without changing remote machines.

Two front ends are included:

- **Windows** — PowerShell + WinForms + the official `PSAction1` module.
- **Fedora/Linux** — Python + Tkinter + the official Action1 REST API.

## Current status

Version: **v0.2.2 — Fleet Grid & Layout Fix**

Implemented:

- Action1 authentication
- Australia region by default
- organisation selection
- endpoint inventory
- online/offline/problem summary
- DadLAN roles (`Controller`, `Worker`, `Legacy Worker`)
- protected controller metadata
- search and fleet filters
- endpoint details
- read-only diagnostics
- local activity log
- local metadata persistence
- Safe Test Mode / no remote-changing actions

Not implemented yet:

- remote PowerShell/scripts
- reboot/shutdown
- software deployment
- Action1 automations
- bulk write actions

## Security

**Do not commit Action1 credentials.** This repository intentionally does not contain a Client ID, Client Secret, bearer token, or saved credential file.

The Windows and Fedora apps prompt for credentials at runtime and do not persist the Client Secret. Local fleet metadata is also ignored by Git because it can contain endpoint IDs and hostnames.

For this read-only release, use an Action1 API credential with the minimum permissions needed to view endpoints.

## Windows

### Requirements

- Windows 10/11
- Windows PowerShell 5.1 or newer
- Action1 API credentials

### Setup

Open **PowerShell as Administrator**:

```powershell
cd windows
.\Setup-Action1Controller.ps1
```

Then launch:

```powershell
.\DadLAN-Control.ps1
```

The app uses `PSAction1`, sets the region to Australia, asks for your Client ID/Secret, and loads the fleet.

Local metadata is stored outside the repo under:

```text
%LOCALAPPDATA%\DadLAN\machines.json
```

## Fedora / Linux

The Linux edition does not depend on PowerShell or WinForms. It talks directly to the Action1 REST API using Python's standard library.

### Install on Fedora

```bash
cd fedora
./install-fedora.sh
```

Then run:

```bash
dadlan
```

or launch **DadLAN Command Centre** from the Fedora application menu.

The installer only ensures Python/Tkinter are available and creates a per-user launcher. There are no pip dependencies.

Local metadata is stored under:

```text
~/.config/dadlan/machines.json
```

### Optional Client ID environment variable

You can pre-fill the Client ID without storing the secret:

```bash
export ACTION1_CLIENT_ID='your-client-id'
dadlan
```

The Client Secret is still requested interactively and is not written to disk.

## Action1 API regions

The Fedora client supports the region hosts used by Action1:

- North America
- North America 2
- Europe
- Australia

DadLAN defaults to Australia.

## DadLAN roles

When an endpoint name contains `Laptop #01` through `Laptop #10`, DadLAN automatically assigns:

- `#01` → Controller + Protected
- `#02`–`#08` → Worker
- `#09`–`#10` → Legacy Worker

Manual metadata edits are kept locally and are not written back to Action1.

## Repository structure

```text
windows/
  DadLAN-Control.ps1
  Setup-Action1Controller.ps1
fedora/
  dadlan.py
  install-fedora.sh
config/
  DadLAN-Machines.example.json
docs/
  ROADMAP.md
  SECURITY-NOTES.md
```

## Why two implementations?

WinForms is Windows-only. Keeping the Windows dashboard on `PSAction1` preserves the working setup, while the Fedora version uses Action1's documented OAuth 2.0 REST API and gives the project a genuinely cross-platform path.

## Next milestone

v0.3 will focus on **safe remote execution**:

1. one pre-defined, read-only diagnostic action
2. one explicitly selected worker
3. result collection and history
4. protected controller exclusion
5. confirmations and dry-run behaviour

Arbitrary scripts and fleet-wide write actions should come later.
