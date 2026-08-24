# Security Notes

DadLAN controls or observes remote computers through Action1, so credentials and action boundaries matter.

## Credentials

- Never commit Client Secrets, bearer tokens, `.clixml` credentials, or exported credential files.
- DadLAN v0.2.2 does not persist the Client Secret.
- The Client ID may be supplied through `ACTION1_CLIENT_ID`, but the secret is prompted interactively.
- Local machine metadata can contain endpoint IDs and hostnames, so it is stored outside the repository and ignored by Git.

## API credential permissions

Use least privilege. For the current read-only release, give the credential only the permissions necessary to view endpoints and related read-only information.

When write features are introduced, use a separate credential or role limited to the intended test endpoints rather than immediately granting enterprise-wide script/deployment permissions.

## Protected controller

Laptop #01 is auto-marked as `Controller` and `protected=true`. Future fleet actions must exclude protected endpoints by default.

## Remote execution roadmap

Remote actions should be introduced in stages:

1. predefined harmless diagnostic
2. one worker only
3. selected workers
4. write operations with explicit confirmation

Do not add an unrestricted fleet-wide arbitrary-script button before those controls are tested.
