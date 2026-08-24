# Security Notes

DadLAN controls or observes remote computers through Action1, so credentials and action boundaries matter.

## Credentials

- Never commit Client Secrets, bearer tokens, `.clixml` credentials, or exported credential files.
- DadLAN v0.3.0 does not persist the Client Secret.
- The Client ID may be supplied through `ACTION1_CLIENT_ID`, but the secret is prompted interactively.
- Local machine metadata can contain endpoint IDs and hostnames, so it is stored outside the repository and ignored by Git.

## API credential permissions

Use least privilege. For v0.3.0 which supports remote diagnostics, give the credential only the permissions necessary to view endpoints and run scripts (`Use Scripts` permission in Action1) for the intended endpoints.

## Protected controller

Laptop #01 is auto-marked as `Controller` and `protected=true`. Fleet actions actively exclude the Controller (Laptop #01) at the logic level, regardless of the `protected` flag in metadata. Protected endpoints are also strictly blocked.

## Remote execution safeguards

Remote actions are strictly bounded:

1. Only predefined harmless diagnostics (like System Snapshot) are allowed.
2. Actions can only target one worker at a time.
3. Controllers and non-workers are explicitly blocked.
4. The Action1 payload uses explicit `run_script` templates, preventing arbitrary PowerShell injection.
5. All executions require an explicit confirmation prompt.

Do not add an unrestricted fleet-wide arbitrary-script button.
