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

1. Edit `config.yml`, choose an unused release tag, and run `pin.sh <tag>` to hash the
   exact file bytes. Update the `-i`/`-u` argv and image digest in Atlas's router manifest.
2. Export that manifest with `cvmctl export-runtime` into `tinfoil-config.yml`. Review
   both files, verify anonymous image pulls, and merge to main.
3. Run the `Tinfoil Release` workflow with that same version. Verify the published
   runtime and config bytes match the prepared hashes before applying the CVM.

The config hash can be computed before publication. Both files may use the same new
release tag; no follow-up release is needed if those exact bytes are published.

## Qwen/Cosmos models

`qwen3-omni` and `cosmos3-super` (NVIDIA Cosmos3-Super video generation, which replaced
MiniMax-H3 FL2VA) map to the shared `host0.inference.aptoslabs.com` Model CVM and its
`confidential-qwen-cosmos-prod` release repository. The client-facing router uses
`router.inference.aptoslabs.com`; never send host0's SNI to this router. The measured shim
includes authenticated multipart `/v1/videos/sync` passthrough, and the map preserves the CCS
rate/overload policy. Earlier tags (v0.0.4-v0.0.6) routed `minimax-h3-fl2va` to
`confidential-qwen-minimax-prod`.

The patched image is published through GHCR from source commit
`b8c36d88e332a361f944ec46446f9a57d5d947d3`. Publication remains gated on making the
package anonymously pullable and provisioning production credentials; do not embed
registry credentials in the CVM or use the staging router's secrets.

## Trust chain

Clients pin this repo (`-r aptos-labs/confidential-inference-router`) and verify the
latest release's Sigstore attestation. The router CVM's measurement covers
`tinfoil-config.yml` (including the measured argv with the pinned config URL+hash); the
router then verifies each backend enclave against its model repo pin from `config.yml`.
This repo must stay public: the router fetches model measurements through
`github-proxy.tinfoil.sh`.
