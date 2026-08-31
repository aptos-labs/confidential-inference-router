# confidential-inference-router

Release/attestation repo for the Aptos GPU-less TDX router CVM fronting the confidential
inference fleet. Plan and runbooks: aptos-labs/atlas `deploy/h200-inference/`.

## Layout

- `tinfoil-config.yml` — the router CVM's measured config; clients verify it via this
  repo's release attestation. Must mirror the runtime subtree of
  `rust/crates/cvmctl/vmconfig/vm-router-prod.yml` in aptos-labs/atlas.
- `config.yml` — the router's runtime model/enclave map. The router CVM fetches it at boot
  (`-i`) and on refresh (`-u`) with an integrity-pinned URL: `<raw-url>@sha256:<hex>`.
- `.github/workflows/` — tag-driven release: `tinfoil-release.yml` creates the tag and
  dispatches `tinfoil-release-publish.yml`, which runs `tinfoilsh/measure-image-action`
  to measure `tinfoil-config.yml`, attest it (Sigstore keyless), and publish the release.
  Pattern copied from `aptos-labs/confidential-glm-5-3-prod`.
- `pin.sh` — prints the measured `-i`/`-u` argv lines (URL + sha256) for a given tag.

## Cutting a release

1. Edit `config.yml` (add/remove models, change enclaves) and/or `tinfoil-config.yml`.
2. Merge to main, then run the `Tinfoil Release` workflow with the new version.
3. If `config.yml` changed: run `pin.sh <tag>` and update the `-i`/`-u` argv in
   `tinfoil-config.yml` here AND in `vm-router-prod.yml` in atlas, then cut a follow-up
   release — the argv change changes the router measurement, and clients pick it up via
   latest-release trust on this repo pin.

Self-reference note: tag vN+1's `tinfoil-config.yml` references `config.yml` from tag vN,
because the config hash only exists once vN is published.

## Trust chain

Clients pin this repo (`-r aptos-labs/confidential-inference-router`) and verify the
latest release's Sigstore attestation. The router CVM's measurement covers
`tinfoil-config.yml` (including the measured argv with the pinned config URL+hash); the
router then verifies each backend enclave against its model repo pin from `config.yml`.
This repo must stay public: the router fetches model measurements through
`github-proxy.tinfoil.sh`.
