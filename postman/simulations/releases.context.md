# GitHub release-check simulation

## Purpose

Exercise `Sources/ReleaseUpdates.swift` through real URLSession HTTP calls. The fixture models the public latest-release contract in `postman/contracts/github-releases.json`, from GitHub's official documentation. No Postman account, cloud workspace or credentials are used; an owner's published mock was not searched.

## Execution

Run `python3 Tests/ReleaseUpdates/run.py` on macOS with the Postman CLI and Apple command-line tools available. It starts the local simulation on an automatic port, compiles the client tests, checks recorded HTTP requests and stops the server. Nothing is deployed.

## Assumptions

- The endpoint is read-only and public; the mock rejects authorization and cookie headers. The local scenarios cover version comparison, missing release, malformed responses, unexpected release URLs, draft releases, rate limits, server errors and timeout. They do not reproduce GitHub's service internals or TLS. (contract and observed 2026-10-25)
- Local HTTP networking must be permitted by the test environment. Tests use fictional releases and do not access the Cursor account. (observed 2026-10-25)

## Observations

<!-- begin:observations -->
2026-10-25: the GitHub mock served the release client's real requests; no members were idle. Live GitHub is a separate explicit `--live` check.
<!-- end:observations -->

## What didn't work

- 2026-10-25: a directory mock path was rejected as `Mock 'file' must point to a file`; this CLI accepts the explicit `config.yaml` path recorded in the simulation.
- 2026-10-25: the restricted execution environment returned `listen EPERM` and denied client HTTP; the same fixture passed with local networking permitted.
