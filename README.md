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

## Qwen/MiniMax models

`qwen3-omni` and `minimax-h3-fl2va` map to the shared `host0.inference.aptoslabs.com`
Model CVM and its `confidential-qwen-minimax-prod` release repository. The client-facing
router uses `router.inference.aptoslabs.com`; never send host0's SNI to this router. The
measured shim includes authenticated multipart `/v1/videos/sync` passthrough. Cosmos3-Super
remains in the earlier `confidential-qwen-cosmos-prod` releases and is not routed here.

## GLM-5.3 model

`glm-5.3` maps to the `host1.inference.aptoslabs.com` Model CVM and its
`confidential-glm-5-3-prod` release repository. Since v0.0.11 it sets `cache_salt: true`.
Since v0.0.12 the router authenticates to host1 with a scoped backend credential
(`backend_auth_env: GLM_BACKEND_API_KEY`) and keeps the customer identity for usage
attribution. `/metrics` requires a bearer key.

## Attestation collateral

Since v0.0.13 the measured shim fetches attestation collateral from
`https://atc.inference.aptoslabs.com` (the `atc` field in `tinfoil-config.yml`). That
service is `rust/crates/inference-atc` in aptos-labs/atlas. For a nonce-bound attestation
request it supplies the Intel PCS collateral and the Sigstore code-provenance and
hardware-measurement bundles. It verifies nothing itself: clients verify every signature.
If the shim cannot obtain collateral, nonce-bound attestation requests fail with 503.
v0.0.13 changes only this field. The image and model map are the same as in v0.0.12.

## Router image

The patched image (`sha256:3d2cec57acf290981a27a7d966d8483dc0ad0afddba69d34cb0b76c2994b4faf`)
is published through GHCR from source commit `7fb4911fc71b86f84ff4272088f46e500fda6799`.
The package is anonymously pullable (verified 2026-11-06). Do not embed registry credentials
in the CVM or use the staging router's secrets.

## License and source

The router container runs Aptos Labs' modified version of
[tinfoilsh/confidential-model-router](https://github.com/tinfoilsh/confidential-model-router),
licensed under the GNU Affero General Public License v3. The Corresponding Source of the
image pinned in `tinfoil-config.yml` is source commit
[`7fb4911fc71b86f84ff4272088f46e500fda6799`](https://github.com/aptos-labs/confidential-model-router/tree/7fb4911fc71b86f84ff4272088f46e500fda6799)
in [aptos-labs/confidential-model-router](https://github.com/aptos-labs/confidential-model-router).
Router images built from that repository after 2026-10-05 also return the source URL of
the running build in the `X-Source-Code` response header and at `GET /source`.

When you pin a new router image, update the source commit in this section in the same change.

## Trust chain

Clients pin this repo (`-r aptos-labs/confidential-inference-router`) and verify the
latest release's Sigstore attestation. The router CVM's measurement covers
`tinfoil-config.yml` (including the measured argv with the pinned config URL+hash); the
router then verifies each backend enclave against its model repo pin from `config.yml`.
This repo must stay public: the router fetches model measurements through
`github-proxy.tinfoil.sh`.
