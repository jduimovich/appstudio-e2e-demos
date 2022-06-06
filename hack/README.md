# trigger-git-webhook

Use this to trigger a local event listener trigger to build a pipeline (on CRC for example).

`build-all.sh` will trigger all routes starting with EL and a minimal fake github payload.
`trigger-webhook.sh url <optional-tag>` will trigger the URL and optionally a specific tag
