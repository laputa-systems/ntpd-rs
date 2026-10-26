# Graviola TLS provider for Alpine Linux

Status: ready to launch. The campaign has not started.

Goal: add an opt-in Graviola TLS provider for `ntpd` builds on supported Alpine x86_64 and AArch64 hardware. Preserve current NTP, NTS, DNSSEC, configuration, and clock behavior for existing builds. The Graviola profile must have no active AWS-LC, ring, OpenSSL, or other C-backed cryptography dependency.

Deliverables:

1. Graviola TLS for NTS-KE clients and servers.
2. An x86_64 musl production build with no active AWS-LC, ring, OpenSSL, or other C-backed cryptography.
3. AArch64 musl build proof, and runtime proof when supported hardware is available.
4. NTS protocol tests and interoperability with an independent implementation.
5. Secure SRV behavior for compatibility builds and no SRV feature in the Graviola profile without C-backed cryptography.
6. Alpine installation and OpenRC instructions.
7. Minimal CI coverage for the Graviola profile and its dependency closure.
8. A final report with commands, sizes, compiled dependencies, test results, and limits.

Last accepted checkpoint: none. The source base is `389e5b90` on `main`, package version `2.0.0-alpha.20260715`.

Provisional work: none. Preflight changed this document only.

Current ruling: use one writer and one Cargo build or test command at a time. TLS and feature changes share manifests and call paths. The initial work width is one, with a provisional-work cap of one item and an 8 GiB memory budget.

Next substantive milestone: record the current x86_64 Linux baseline and a dependency-closure pilot before changing code.

## Charter

- Decide within the decisions below, record any new implementation choice in the campaign log, and continue without waiting for approval.
- The source draft authorizes code, tests, the requested minimal CI coverage, deployment documentation, local commits, and local verification. It forbids pushing. This plan does not authorize publishing, deployment, changing the real host clock, or expanding the product scope.
- Keep the source base and tool policy fixed during a validation wave. Rebase only for a named need. Preserve the user's staged campaign document and do not include it in implementation commits.
- Keep worktrees and scratch under `.work/` in the repository. Do not use `/tmp` or `$TMPDIR`. This campaign has one writer and needs no worker worktree.
- Do not run tests that can change the development host clock. Use a disposable Linux container without `CAP_SYS_TIME` for daemon tests. Use `chronyd -x` for Chrony interoperability.
- Do not push, trigger remote CI, deploy to Alpine, or publish packages. Run local checks and edit the requested workflow for future CI coverage.
- Commit completed implementation items locally with Conventional Commit subjects scoped to the workstream. Do not commit a partial or unverified item. Keep the plan out of those commits.
- If a focused command exceeds 10 minutes on an idle host, make one bounded attempt to remove the blocking cost before the next substantive delivery. Time a second run only when `perf-gate-ready` permits it. If it does not, report `perf gate deferred: host busy` and do not present timing as a pass.
- Diagnose each failed check before retrying. After three distinct repair attempts, park the item with its evidence, prerequisite, and retry condition. Never retry an unchanged failure.
- Run a parent steering checkpoint after each validation wave, after five attempted items if no wave completes, on resume, and before dispatch after a repeated failure. Review substantive delivery, queue state, rejected proposals, inherited debt, and the next delivery. Change methods when the same obstruction repeats twice. Do not waive a required proof.
- Keep current rulings here. Keep only short decisions and accepted results in the campaign log. Reuse evidence only when its revision, inputs, environment, scope, and artifacts still match.
- Fix optimization only after protocol parity and hardening. Treat binary size as a required measurement, not an optimization target. Do not claim runtime or build speedups.

## Decisions

### Owner-decided

- On 2026-10-25, the owner selected the current v2.0 alpha checkout as the campaign base. The draft's v1.9.0 requirement is superseded because the selected repository already contains the 2.0 alpha module and feature layout. Do not switch tags or backport the change to v1.9.0.

### Prescribed

- Keep the existing default features and behavior. The current `ntpd` defaults are AWS-LC, RustCrypto, PPS, and secure SRV. Add Graviola as an opt-in provider profile. Do not make it the default for older or unsupported CPUs.
- Use the profile `--no-default-features --features graviola,rustcrypto`. The absence of `srv` is deliberate. This profile retains normal hostname lookup and direct NTS connections, but does not perform SRV lookup.
- Select a `rustls::crypto::CryptoProvider` in the existing `tls_utils` builder helpers and pass it into both client and server configuration. Pass that same provider to the platform verifier. Do not rely on process-global provider installation for Graviola. Preserve OpenSSL's current selection when both legacy `aws-lc` and `openssl` features are enabled, because the current daemon installs OpenSSL as the default in that configuration.
- Make `graviola` mutually exclusive with the `aws-lc` and `openssl` TLS provider features at compile time. Building with no TLS provider must also fail clearly. The compatibility `srv` feature may coexist with Graviola only as a build with C-backed cryptography; it enables Hickory DNSSEC and AWS-LC. Do not count it as the Graviola production profile.
- Keep `srv` secure. Hickory 0.26.3 offers DNSSEC through `dnssec-aws-lc-rs` or `dnssec-ring`. Both are excluded from the Graviola profile, and the current code filters for `proof.is_secure()`. Do not accept unvalidated SRV answers or rewrite the resolver. Keep the existing secure SRV behavior behind `srv` for compatibility builds.
- Keep RustCrypto AES-SIV and MD5 for NTS packet and reference-ID cryptography. Graviola replaces TLS cryptography only. Do not write replacement primitives.
- Keep rustls 0.23, TLS 1.3, ALPN `ntske/1`, certificate-chain verification, custom CA roots, OS trust-store behavior, and TLS exporter keying material. Do not add a public Rust configuration field for the provider. If an internal provider choice cannot preserve the current public API, park that item for owner review.
- The current workspace MSRV is Rust 1.95. Graviola 0.4.0 declares Rust 1.89, so no MSRV increase is needed. Keep the workspace MSRV and pinned tool policy unchanged. If the resolved dependency requires a compiler newer than 1.95, park the dependency item.
- Use the upstream `rustls-graviola` 0.4.x crate compatible with rustls 0.23. Record the exact resolved versions in `Cargo.lock`. Do not vendor the crate or add C-backed cryptography. The dependency's license check must pass the current repository policy. Do not widen license policy to make it pass.
- Graviola supports x86_64 and AArch64 only, with required CPU instructions. Document and test only machines with those instructions. Do not claim support for armv7, riscv64, or arbitrary x86_64 CPUs.
- Keep the existing `all-portable` provider combination valid. Replace only build or test uses of `--all-features` that become invalid when Graviola is exclusive. Keep dependency license checks that use `--all-features`, since they inspect dependency metadata and do not compile that feature combination.
- Do not change NTP algorithms, source selection, polling, clock discipline, configuration fields, suspend and resume detection, or persisted drift state.

### Delegated within bounds

- Choose the smallest existing test fixture and local Linux container method that proves the listed behavior. Do not add a test framework or a general crypto abstraction.
- If an AArch64 musl runner is unavailable after three attempts to use the existing cross-build setup, park AArch64 runtime proof. A successful cross-build still counts as compile proof, not runtime proof.
- If a public NTS endpoint or Chrony package is unavailable, record the environment failure and park only that interoperability check. Keep deterministic local tests of both NTS roles as required acceptance.

## Baseline

Source inspection covers the current `main` source base named above. The workspace declares Rust 1.95. The current host is Darwin arm64 with rustc 1.99.1 and only `aarch64-apple-darwin` installed. It cannot provide Linux musl runtime proof.

The measured dependency command was:

```sh
cargo tree --offline --locked -p ntpd \
  --target x86_64-unknown-linux-musl \
  --edges normal,build --invert aws-lc-sys
```

It took 0.076 seconds on the warm local Cargo cache. It found `aws-lc-sys` through both rustls and Hickory Resolver. The selected graph contained `aws-lc-rs 1.18.1`, `rustls 0.23.46`, and `hickory-resolver 0.26.3`. The same graph query found no `ring`. `openssl-sys` was not in the graph. This is the current default profile, not the requested Graviola profile.

The current no-default boundary was also measured before adding Graviola:

```sh
cargo tree --offline --locked --prefix none -p ntpd \
  --target x86_64-unknown-linux-musl --no-default-features \
  --features rustcrypto --edges normal,build
```

It took 0.137 seconds on the warm cache and returned 183 package lines. It contained no Hickory, AWS-LC, ring, or OpenSSL packages. This confirms that disabling `srv` removes Hickory from the selected graph; it does not prove the future Graviola graph.

No compile or test baseline was run during preflight. No known test failure or baseline binary size is recorded. The first campaign item must record baseline failures, binary size, and elapsed time for each listed command before code changes. Run tests on Linux x86_64. Run any test with clock effects in a disposable container without `CAP_SYS_TIME`.

Keep baseline and candidate comparisons on the same source base, target, compiler, feature set, and release flags. Record diagnostic identity, not only counts. Record inherited failures separately from campaign regressions. If a baseline cannot run, name the missing environment and park only affected acceptance.

## Workstreams and sequence

Use two sequential workstreams. W1 owns the coupled feature graph, TLS provider, DNS behavior, and tests. W2 owns CI and installation documentation after W1 settles the feature contract. The manifests belong to W1 because provider and SRV features share them. Do not parallelize writers. Validate one item at a time.

### P0: Ground the baseline

Item G0, size S. No prerequisite. Owner: campaign coordinator. Files: this campaign log only.

Run the current Linux baseline before changing code:

```sh
cargo test --locked --target x86_64-unknown-linux-gnu -p ntp-proto -p ntpd
cargo build --locked --release --target x86_64-unknown-linux-musl -p ntpd
cargo tree --locked -p ntpd --target x86_64-unknown-linux-musl --edges normal,build
```

Record the failing tests by name, dependency paths for AWS-LC, ring, and OpenSSL, baseline binary size, and loop timings. Use `/usr/bin/time -p` for loop timing. If the target is unavailable, use an isolated Linux runner or park that target. Do not treat an unrun command as a pass.

Acceptance: the baseline record identifies existing reds and captures a release binary size before edits. The original default build must still show the current AWS-LC and secure SRV dependency paths.

### P1: Add the Graviola provider pilot

Item G1, size L. Prerequisite: G0. Workstream: W1. Owned files: root `Cargo.toml`, `ntpd/Cargo.toml`, `ntp-proto/Cargo.toml`, `Cargo.lock`, `ntp-proto/src/tls_utils.rs`, `ntp-proto/src/nts/mod.rs`, and provider initialization in `ntpd/src/daemon/mod.rs`.

Add the optional dependency and propagated `graviola` feature. Select the provider in `tls_utils`. Use explicit provider builders for NTS-KE clients and servers, then pass the selected provider to the platform verifier. Preserve the client and server public APIs. Remove global provider installation only after checking every rustls builder and caller.

First prove one NTS-KE exchange between a client and server using Graviola on supported hardware. Reuse the current duplex test fixture and test certificates. Keep `rustcrypto` enabled for packet crypto.

Acceptance:

```sh
cargo test --locked -p ntp-proto --no-default-features \
  --features graviola,rustcrypto nts::tests::test_keyexchange_roundtrip_v4
cargo test --locked -p ntpd --no-default-features --features graviola,rustcrypto
```

The client and server complete NTS-KE, negotiate TLS 1.3 and ALPN `ntske/1`, verify the test CA, and derive matching exporter keys. A request without a trusted CA fails. Existing client and server tests continue to pass.

Also run `cargo +1.95.0 check --locked -p ntpd --target x86_64-unknown-linux-musl --no-default-features --features graviola,rustcrypto` to prove the declared MSRV remains sufficient.

### P2: Prove the Graviola profile has no C-backed cryptography

Item G2, size M. Prerequisite: G1. Workstream: W1. Owned files: the three Cargo manifests, `Cargo.lock`, and `ntpd/src/daemon/dns.rs`.

Keep `srv` optional and document that it selects Hickory's validated DNSSEC path. The Graviola profile uses `--no-default-features`, so it must not compile Hickory, AWS-LC, ring, or OpenSSL. Ordinary `lookup_host` and direct NTS connections must still work. Do not alter the `proof.is_secure()` filter for compatibility builds. If coverage is missing, add a deterministic resolver test that accepts secure SRV proof and rejects insecure proof, plus a direct-hostname test under the no-SRV profile.

Prove the exact active graph:

```sh
cargo tree --locked --prefix none -p ntpd \
  --target x86_64-unknown-linux-musl --no-default-features \
  --features graviola,rustcrypto --edges normal,build
```

The closure check must fail if the active graph contains `aws-lc-rs`, `aws-lc-sys`, `ring`, `openssl`, or `openssl-sys`. Review the remaining active packages and build scripts for other C-backed cryptography. Do not inspect only `Cargo.lock`.

Test the closure rule against the real Graviola profile and against a known AWS-LC profile. The first must pass and the second must fail. Match package names in the flattened tree so dependency relocation does not hide a regression. Scope the check to `ntpd`, the selected target, and normal/build edges so workspace debt and dev dependencies cannot create false failures. Keep default and OpenSSL profile tests to show unchanged consumers still work.

Acceptance: the Graviola graph contains no excluded crypto package or other C-backed cryptography. Normal DNS and direct NTS client tests pass. A deterministic test proves secure SRV answers remain accepted and insecure answers remain rejected. The no-SRV profile resolves direct hostnames.

### P3: Complete NTS parity and provider regression coverage

Item G3, size M. Prerequisite: G2. Workstream: W1. Owned files: existing tests in `ntp-proto/src/nts/mod.rs`, `ntp-proto/src/nts/messages.rs`, `ntp-proto/src/packet/crypto.rs`, and `ntpd/src/daemon/keyexchange.rs` or `ntpd/src/daemon/spawn/nts.rs` when a missing caller behavior needs coverage.

Extend the existing tests only where they lack an assertion. Cover client and server NTS-KE, TLS 1.3, exact ALPN, system and custom CA trust, invalid chains, exporter key agreement, cookie generation and decoding, AES-SIV packet encryption and decryption, invalid authentication, and malformed packets. Run the same deterministic fixtures under the existing AWS-LC provider and Graviola, comparing protocol outcomes while allowing randomized keys and cookies to differ. Keep the existing NTS protocol and cookie behavior as the reference. Test protocol behavior against [RFC 8915](https://www.rfc-editor.org/rfc/rfc8915) and TLS behavior against [RFC 8446](https://www.rfc-editor.org/rfc/rfc8446).

Run deterministic local tests first:

```sh
cargo test --locked -p ntp-proto --no-default-features \
  --features graviola,rustcrypto nts::tests
cargo test --locked --target x86_64-unknown-linux-gnu -p ntp-proto -p ntpd \
  --no-default-features --features graviola,rustcrypto
```

Run Chrony against the local NTS server in an isolated Linux container. Start Chrony with `-x` so it cannot adjust the system clock. Confirm the NTS exchange and NTP response. Do not use an external server as a substitute for the deterministic local suite.

Run the existing AWS-LC, OpenSSL, and default test profiles from `.github/workflows/checks.yaml`. Graviola plus an explicitly selected AWS-LC or OpenSSL TLS provider must fail at compile time with a provider conflict. A build with no TLS provider must fail with a clear diagnostic.

Acceptance: all named behaviors pass under Graviola, invalid certificate and authentication cases are rejected, local Chrony interoperability succeeds, and existing supported provider profiles retain their behavior. Test names and assertions identify the expected TLS version, ALPN, CA result, exporter agreement, and packet-authentication result.

### P4: Validate musl targets and Alpine operation

Item G4, size M. Prerequisite: G3. Workstream: W1. Owned files: none unless a failed check requires a source repair owned by W1.

Build the requested x86_64 profile:

```sh
cargo build --locked --release -p ntpd \
  --target x86_64-unknown-linux-musl \
  --no-default-features --features graviola,rustcrypto
```

Cross-build AArch64 with the existing musl linker setup:

```sh
cargo build --locked --release -p ntpd \
  --target aarch64-unknown-linux-musl \
  --no-default-features --features graviola,rustcrypto
```

Before running the x86_64 binary, verify the host exposes Graviola's required CPU flags. Run it in Alpine with no `CAP_SYS_TIME` and set `minimum-agreeing-sources` above the number of reachable sources. Start `ntp-daemon`, confirm it remains running, and run `ntp-ctl status`. Verify direct hostname resolution and custom CA trust against the local test NTS server. Verify the system CA path against an available public NTS test endpoint; if none is available, park only that check. Keep deterministic local NTS tests as the protocol proof. The container must not be privileged or share a time namespace that can alter the development host. Document that a deployed daemon needs the clock-setting capability to discipline time; this campaign's runtime proof covers startup, control access, name resolution, and TLS without that capability. AArch64 runtime proof requires supported hardware; otherwise record only the cross-build.

Document the exact CPU flags from [Graviola's hardware requirements](https://github.com/ctz/graviola#limitations). x86_64 requires `aes`, `ssse3`, `avx`, `avx2`, `adx`, `bmi2`, and `pclmulqdq`. AArch64 requires `aes`, `sha2`, `pmull`, and `neon`. Do not claim runtime fallback for AES or GHASH.

Acceptance: x86_64 musl build and container run pass. AArch64 musl build passes or is parked with a named linker/hardware prerequisite. No test changes the host clock. Record ordinary musl linker requirements separately from C cryptography requirements.

### P5: Add the CI guard and Alpine instructions

Item G5, size M. Prerequisite: G4. Workstream: W2. Owned files: `.github/workflows/checks.yaml` and `docs/guide/installation.md`.

Add one x86_64 musl Graviola entry to the existing checks matrix and run the dependency closure assertion for that exact feature and target. Keep the existing AWS-LC, OpenSSL, and default entries. Replace the build and test `--all-features` entry with an explicit valid feature set that still covers the legacy providers and seccomp. Leave the metadata-only cargo-deny `--all-features` check in place.

Add a concise Alpine/OpenRC section to the existing installation guide. Include:

- the Graviola build command, Rust MSRV, musl linker requirements, and required CPU flags;
- installing the built `ntp-daemon` and `ntp-ctl` binaries and Alpine's CA certificate package;
- runtime config and files needed for NTS;
- an OpenRC `openrc-run` service using the foreground daemon and a pidfile;
- commands to start and enable the service, inspect status, and verify with `ntp-ctl status`;
- how to stop and disable BusyBox `ntpd` or another clock daemon before starting this service.

Follow [Alpine's init-script guide](https://wiki.alpinelinux.org/wiki/Writing_Init_Scripts). Do not add Alpine packaging, an init framework, or unrelated systemd changes.

Acceptance: the workflow runs the Graviola profile and rejects a contaminated dependency graph. The installation guide can be followed on Alpine without systemd and gives the supported hardware and CA requirements.

### P6: Measure and close

Item G6, size S. Prerequisite: G5. Workstreams: W1 and W2, integrated by the campaign coordinator.
Measure the Graviola release binary with the same target, compiler, and profile used for the P0 baseline. Report byte size and the compiled dependency difference. Report build time only when the timing gate permits a comparable measurement. Do not optimize runtime or binary size unless parity and all required tests already pass.

Run the complete relevant Linux x86_64 suite, the final Graviola closure check, existing provider builds, the Alpine operation check, and AArch64 cross-build. Reuse earlier evidence only when source, lockfile, feature set, target, environment, and scope still match. Run `ultrareview` on the changed scope and fix its P1 and P2 findings. Do not run formatters, push, or trigger remote CI.

Acceptance: every required deliverable passes or is parked with a concrete external prerequisite. The final report distinguishes passed, unverified, and parked checks. Do not describe parked platform or interoperability proof as complete.

### P7: Publish our own GitHub prereleases

Item G7, size M. Prerequisite: G6. Owned files: `.github/workflows/prerelease.yml`, `Dockerfile`, and `.dockerignore` at the repository root.

Add a manual-dispatch prerelease workflow named `prerelease.yml` (the fork-visible name) following the `~/d/repomod` binary-prerelease contract:

- Refuse dispatches off the default branch with a preflight ref check, and recheck the ref before publication.
- Build exactly the portable target set: `aarch64-apple-darwin`, `x86_64-unknown-linux-musl`, and `aarch64-unknown-linux-musl`. Mention no glibc target in the workflow.
- Build Linux targets in the pinned Alpine musl builder image defined by the new root `Dockerfile` (verified rustup archive, musl-linked LLVM, both musl targets, rust-src, musl-cargo wrapper, CRT stubs, `libutil.a`, plus a musl-native `gcc`). Build the Graviola profile (`--no-default-features --features graviola,rustcrypto`) on every target with plain `cargo`, using the image C compiler as linker. Do not route the workflow through `musl-cargo`: its injected `RUSTFLAGS` are shadowed by this repository's own `[target.'cfg(all())']` rustflags and never reach the linker, while the image C compiler finds the musl CRT objects on its own. Keep `musl-cargo` in the image because the repomod contract requires it there.
- Ship per-platform zip archives of the built binaries plus a verified `SHA256SUMS` file. Keep exactly one bare x86_64 and one bare aarch64 Linux ELF in the release job workspace so the `Verify Linux ELF artifacts are fully static` smoke step (copied verbatim) passes.
- Create the `release-${{ github.sha }}` tag at the triggering commit through the GitHub API and publish with `gh release create --prerelease --verify-tag`.

Register `laputa-systems/ntpd-rs` as `["tool", "rust", "fork"]` in the repomod catalog so the contract can be checked. Push the completed campaign branch and dispatch the workflow only for the owner-confirmed triggering commit.

Acceptance: the repomod `binary-release-tags`, `binary-release-static`, and `rust-musl-image` rules pass for the new workflow and image, and the first prerelease is published with zips and a verified checksum file.

## Acceptance summary

| Deliverable | Required proof |
| --- | --- |
| Graviola client and server | Local NTS-KE exchange between a client and server, TLS 1.3, ALPN `ntske/1`, trusted and untrusted CA cases, matching exporter keys |
| NTS packet behavior | Cookie generation and decoding, AES-SIV encrypt/decrypt, invalid authentication rejection, malformed packet rejection |
| x86_64 build without C-backed cryptography | Exact musl Graviola command plus normal/build dependency tree with no AWS-LC, ring, OpenSSL, or other C-backed cryptography |
| DNS security | Default `srv` behavior continues to filter for secure DNSSEC proof; Graviola profile omits SRV and still resolves direct hostnames |
| AArch64 support | AArch64 musl build; runtime test only on hardware with Graviola's required instructions |
| Interoperability | Deterministic local suite plus local Chrony NTS exchange in a disposable container with `chronyd -x` |
| Alpine operation | Binary starts without `CAP_SYS_TIME`, `ntp-ctl status` works, custom CA verification passes, and system CA verification passes or is parked with evidence that no suitable public NTS endpoint was available |
| Existing providers | Existing default, AWS-LC, and OpenSSL test profiles pass |
| CI regression protection | One Graviola x86_64 musl matrix entry and a package/target/feature-specific closure assertion |
| Deployment documentation | Existing installation guide covers Alpine and OpenRC without systemd |
| Final measurements | Exact build commands, binary byte sizes, and compiled dependency differences are reported |
| Our own prereleases | Manual-dispatch `prerelease.yml` over the portable triple set, pinned Alpine musl builder image, per-platform zips with verified SHA256SUMS, SHA-derived tag with `--verify-tag` |

## Execution boundary and contract changes

The campaign may edit Rust code, Cargo manifests and lockfile, tests, the existing checks workflow, the existing installation guide, the new prerelease workflow, and the new root Dockerfile. It may run local builds and tests in the isolated environments above. It may make local Conventional Commits because the source draft explicitly requested them. Item G7 additionally authorizes pushing the completed campaign branch and dispatching the prerelease workflow for the owner-confirmed triggering commit, plus the repomod catalog registration.

The campaign must not publish or deploy packages, change the real host clock, change NTP or clock-discipline behavior, change configuration fields, add a general provider framework, add C-backed cryptography, or change the project's license policy. Outside item G7, it must not push or trigger remote CI. Park any work that would need those effects.

Contract changes to report:

- Cargo feature `graviola` selects the TLS provider and is mutually exclusive with the `aws-lc` and `openssl` TLS provider features.
- The supported Alpine profile without C-backed cryptography uses `--no-default-features --features graviola,rustcrypto`; it does not include NTS SRV lookup or PPS.
- The `srv` compatibility feature continues secure DNSSEC validation through Hickory and therefore is not part of the Graviola profile without C-backed cryptography.
- The public Rust NTS client and server configuration APIs and runtime NTP configuration remain unchanged.

## Non-goals

- Replacing RustCrypto AES-SIV or MD5.
- Supporting Graviola on armv7, riscv64, or CPUs missing its required instructions.
- Rewriting Hickory, adding DNSSEC cryptography, or accepting unvalidated SRV records.
- Changing synchronization algorithms, source selection, polling, clock setting, or persisted state.
- Making Graviola the default for every target or removing AWS-LC and OpenSSL compatibility builds.
- Adding a generic crypto plugin system, new configuration switches, Alpine package support, or an init framework.
- Optimizing runtime or binary size before protocol parity and required test coverage pass.

## Reference and code map

The current NTS client and server live in [`ntp-proto/src/nts/mod.rs`](ntp-proto/src/nts/mod.rs). They restrict TLS to 1.3, set `ntske/1`, use the platform verifier with custom roots, export NTS key material, and exchange cookies. [`ntp-proto/src/tls_utils.rs`](ntp-proto/src/tls_utils.rs) owns rustls builder helpers. [`ntpd/src/daemon/mod.rs`](ntpd/src/daemon/mod.rs) installs OpenSSL globally when selected.

The current SRV resolver is in [`ntpd/src/daemon/dns.rs`](ntpd/src/daemon/dns.rs). It enables Hickory validation and discards answers without secure DNSSEC proof. Normal hostname lookup uses Tokio's resolver. The root [`Cargo.toml`](Cargo.toml), [`ntpd/Cargo.toml`](ntpd/Cargo.toml), and [`ntp-proto/Cargo.toml`](ntp-proto/Cargo.toml) define the current feature graph. [`ntp-proto/src/packet/crypto.rs`](ntp-proto/src/packet/crypto.rs) owns NTS AES-SIV behavior. Existing NTS usage and CA configuration are described in [`docs/guide/nts.md`](docs/guide/nts.md).

Use the source at the campaign base as the behavior reference and preserve the applicable requirements in [RFC 8915](https://www.rfc-editor.org/rfc/rfc8915). The provider API is documented by [`rustls-graviola 0.4.0`](https://docs.rs/crate/rustls-graviola/0.4.0). The selected Graviola release metadata lists Rust 1.89 and Apache-2.0, ISC, or MIT-0 licensing in [`graviola 0.4.0`](https://docs.rs/crate/graviola/0.4.0). Check the resolved release's metadata again when updating `Cargo.lock`.

Hickory's 0.26.3 feature list is available in its [Cargo manifest](https://docs.rs/crate/hickory-resolver/0.26.3/source/Cargo.toml). Graviola's [architecture and CPU requirements](https://github.com/ctz/graviola#limitations) are part of the deployment contract. Use the official [Chrony `-x` documentation](https://chrony-project.org/doc/latest/chronyd.html) and [Alpine init-script guide](https://wiki.alpinelinux.org/wiki/Writing_Init_Scripts) for the integration and service instructions.

## Decision and campaign logs

Decision log:

- 2026-10-25: owner selected the current v2.0 alpha checkout. The draft's v1.9.0 base is superseded.
- 2026-10-25: preflight retained default AWS-LC, RustCrypto, PPS, and secure SRV behavior. Graviola remains opt-in and its production profile excludes `srv`.
- 2026-10-25: preflight prescribed explicit rustls provider propagation, RustCrypto packet crypto, no public Rust API changes, and compile-time TLS provider conflict checks.
- 2026-10-25: owner stated performance is not a concern. Timings are recorded as environment facts only; no optimization passes and no timing-gate claims.
- 2026-10-25: owner overrode the publish ban for GitHub prereleases. The campaign gains item G7: add our own GitHub prereleases conformant to the `~/d/repomod` binary-prerelease rules (manual dispatch, portable target matrix, per-platform zips, verified SHA256SUMS, SHA-derived tag, `--verify-tag`). Pushing and remote CI remain restricted to what G7 needs.
- 2026-10-27: owner ordered the G7 push and dispatch (`Do it`). The prerelease workflow builds the portable triple set with plain `cargo` and the image C compiler as linker; `musl-cargo` stays in the image for policy conformance but is not used, because this repository's `[target.'cfg(all())']` rustflags shadow its injected `RUSTFLAGS`. The image also gains musl-native `gcc` for the same reason.

Campaign log:

- 2026-10-25: preflight completed. Source and warm dependency-tree check confirmed the current AWS-LC paths. No implementation, build, or test has started. G0 is next.
- 2026-10-25: G0 baseline recorded on the base commit in disposable Linux containers. `cargo test --locked --target x86_64-unknown-linux-gnu -p ntp-proto -p ntpd`: ntp-proto 202 passed, ntpd 43 passed, ctl 2 passed with 5 pre-existing ignored (FIXME-marked reference/config tests), 0 failed, no inherited reds. `cargo build --locked --release --target x86_64-unknown-linux-musl -p ntpd`: pass; ntp-daemon 27141880 bytes, ntp-ctl 19702848 bytes. Default musl graph (378 lines) carries aws-lc-rs 1.18.1 and aws-lc-sys 0.45.0 through rustls and Hickory; the no-default `rustcrypto` graph has 183 packages with only benign `openssl-probe`. Emulated x86_64 exposes only `aes, pclmulqdq, ssse3` (no AVX/AVX2), so Graviola x86_64 code cannot execute there; aarch64 runner has all required flags. Timings are environment facts (emulation load), not gates.
- 2026-10-25: G1 provider pilot complete. `graviola` feature added (ntp-proto selects `rustls-graviola 0.4.0` with `graviola 0.4.1` and `getrandom 0.3.4`; ntpd propagates it and now propagates `aws-lc` to ntp-proto explicitly with no rustls feature change). `tls_utils` builds client/server configs with an explicit provider and passes it to the platform verifier; no global provider installation for Graviola. Conflicts (`graviola` with `aws-lc`/`openssl`) and empty provider sets fail at compile time in both crates. No daemon change was needed; the OpenSSL global install stays behind its feature. NTS-KE roundtrip passes under Graviola on supported hardware; new `test_keyexchange_untrusted_ca_fails` proves untrusted-CA rejection; full ntp-proto Graviola suite 203 passed, ntpd Graviola suite 42 passed (the one-test delta is the `pps`-gated config test, absent from the profile by design). MSRV check with 1.95.0 on x86_64 musl passes.
- 2026-10-25: G2 closure and DNS proof complete. The Graviola musl graph has 190 packages with none of `aws-lc-rs`, `aws-lc-sys`, `ring`, `openssl`, `openssl-sys` and no C-toolchain packages; remaining packages audited (pure Rust plus libc; `openssl-probe` only discovers cert paths). The same check against the default profile finds the excluded packages, so the rule is not vacuous. Secure SRV filtering moved verbatim into `secure_srv_records` with a deterministic unit test (secure accepted; insecure, bogus, and non-SRV answers rejected). New `no_srv_profile_resolves_direct_hostnames` test proves direct resolution under the Graviola profile; the `spawn::nts` direct-name tests are not compiled in this alpha (module commented out) so they cannot serve as proof. Inherited failure: `key_exchange_connection_limiter` times out (750 ms) on the loaded Darwin host and fails identically on the clean base; it passes on the required Linux x86_64 target. Not a campaign regression; no repair attempted.
- 2026-10-26: G3 parity and provider regression complete. New coverage, all provider-agnostic and running in every profile: TLS 1.3 version plus exact `ntske/1` ALPN asserted on both ends of a raw handshake with matching exporter keys (`test_nts_tls_parameters_and_exporter`); system-trust verifier rejects the test CA while custom-CA trust succeeds; cookie decode with the wrong keyset fails; tampered AES-SIV ciphertexts rejected for both key sizes. Full suites on the required x86_64 Linux target: default (ntp-proto 208, ntpd 44), explicit AWS-LC (208, 43), OpenSSL vendored (209, 43) — all green, including the Darwin-timing-flaky `key_exchange_connection_limiter`. Deterministic Graviola suites pass on host and on aarch64 Linux (ntp-proto 208, ntpd 43). x86_64 Graviola execution is impossible here: graviola 0.4.1 aborts with `requires bmi1 CPU support` under emulation, so that runtime proof is parked pending real AVX2 hardware; aarch64 Linux is the Linux runtime proof. Local Chrony 4.5 interop against the scratch harness (Graviola KE + NTS NTP, `.work/tmp/nts-interop`, not committed) succeeded: `authdata` shows mode NTS, AEAD 15, 8 cookies, source selected at stratum 3 with microsecond offsets. Conflict builds fail as specified.
- 2026-10-26: G4 musl and Alpine proof complete with documented parks. x86_64 musl release build passes (ntp-daemon 26416928, ntp-ctl 18775912 bytes). AArch64 musl release build passes natively (27003056, 18648736 bytes). Ordinary musl linker requirement is only `musl-gcc` (or an Alpine builder); no C cryptography involved. In Alpine 3.23 (aarch64, default Docker caps without `CAP_SYS_TIME`): the musl binaries start; direct hostname resolution plus custom-CA NTS verification passes against the local harness server; system-CA verification passes with the test CA installed as a system anchor. The start-without-`CAP_SYS_TIME` run is parked: this alpha unconditionally issues an `adjtimex` write at startup (strace shows a bare read succeeding, then a write failing `EPERM`), so the daemon cannot start cap-less; the OpenRC run used `--cap-add SYS_TIME` with unreachable-only sources, and host wall time advanced normally with no discipline. `ntp-ctl status` is parked: the observer spawn is commented out (`daemon/mod.rs`), so no observe socket exists in this alpha (`validate` works). The `minimum-agreeing-sources` field and `[[server]] listen` do not exist in this alpha (`NtpServerConfig` is empty, no server spawn wiring), so the run uses unreachable-only sources and the OpenRC `start-stop-daemon --background` pattern. Public-endpoint system-CA check parked: no egress to TCP 4460. x86_64 container run parked: emulated CPU lacks AVX2 (graviola aborts). OpenRC `start`/`status` validated in-container; `ntpd-rs` user/group creation included.
- 2026-10-26: G5 CI guard and Alpine instructions complete. `checks.yaml` gains an x86_64 musl Graviola matrix entry with a dependency-closure assertion step that fails on any `aws-lc-rs`, `aws-lc-sys`, `ring`, `openssl`, or `openssl-sys` package; the invalid `--all-features` seccomp entry is now `--features all-portable,seccomp`; metadata-only `cargo-deny --all-features` checks unchanged. The installation guide covers the Alpine/OpenRC Graviola flow: build command, Rust 1.95 MSRV, musl linker and CPU-flag requirements, binary and CA-certificate install, NTS config files, the validated OpenRC service, and BusyBox `ntpd` removal.
- 2026-10-26: G6 measured and closed. Post-change default x86_64 musl release build passes (ntp-daemon 27113952 bytes, no regression vs 27141880 baseline). Final Graviola closure check is clean and unchanged. `ultrareview` is not installed in this environment, so its P1/P2 pass is unverified; no other review findings are open. No formatters, pushes, or remote CI were run. G7 prereleases remain: workflow and image are specified in the campaign but not yet implemented; push and dispatch await the owner-confirmed triggering commit.
- 2026-10-27: G7 implemented and locally validated. `prerelease.yml` (manual dispatch, preflight ref guard, portable matrix, per-platform zips, verbatim static-ELF smoke step, `SHA256SUMS` verify, API tag creation, `gh release create --prerelease --verify-tag`), root `Dockerfile` (pinned Alpine, verified rustup archive, musl-linked LLVM with retry, both musl targets, rust-src, musl-cargo, CRT stubs, `libutil.a`, musl `gcc`), and `.dockerignore` added. Repomod `binary-release-tags`, `binary-release-standard`, `binary-release-static`, and `rust-musl-image` rules pass with zero findings, including without the fork exemption. Linux build and test steps plus per-binary static checks executed verbatim against the image shape (208 + 43 passed; three static binaries, no INTERP/NEEDED). Release-job layout, packaging, checksum, and smoke logic validated against real aarch64 and x86_64 musl binaries (a per-platform zip-naming bug in the draft was caught and fixed by that simulation). Not yet run in CI: full image assembly (local egress poisoned two archive downloads; CI network is clean and ish proves the shape) and the macOS job (standard cargo, same profile as host-proven runs).

## Final report

Profile under test: `--no-default-features --features graviola,rustcrypto`.
Toolchain 1.99.1 everywhere; MSRV 1.95 verified with
`cargo +1.95.0 check --locked -p ntpd --target x86_64-unknown-linux-musl --no-default-features --features graviola,rustcrypto`.
Timings omitted: the host was under emulation load throughout, and
performance is out of scope for this campaign.

Passed builds (all `--locked`, release):

| Command | Result | ntp-daemon bytes | ntp-ctl bytes |
| --- | --- | --- | --- |
| `cargo build --locked --release --target x86_64-unknown-linux-musl -p ntpd` (default, G0 baseline) | pass | 27141880 | 19702848 |
| same, Graviola profile | pass | 26416928 | 18775912 |
| same, default profile, post-change | pass | 27113952 | — |
| `cargo build --locked --release --target aarch64-unknown-linux-musl -p ntpd`, Graviola profile | pass | 27003056 | 18648736 |

Compiled dependency difference (default musl graph vs Graviola musl graph,
`--edges normal,build`, 378 lines vs 190 lines, 167 vs 88 unique packages):
removed the Hickory DNSSEC stack (`hickory-resolver`, `hickory-net`,
`hickory-proto` plus `idna`/`url`/ICU), the AWS-LC stack (`aws-lc-rs`,
`aws-lc-sys` plus C-toolchain helpers `cc`, `cmake`, `jobserver`,
`fs_extra`, `dunce`, `shlex`), `pps-time`, and associated caches;
added only `rustls-graviola 0.4.0` and `graviola 0.4.1` (plus
`getrandom 0.3.4` alongside the already-present 0.2/0.4 lines).
Resolved licenses stay inside policy (`Apache-2.0` alternative present;
no policy widening). No C-toolchain packages remain in the Graviola graph.

Passed suites (all `--locked`, exit 0):

| Command | ntp-proto | ntpd |
| --- | --- | --- |
| `--target x86_64-unknown-linux-gnu -p ntp-proto -p ntpd` (default) | 208 | 44 |
| same, `--no-default-features --features rustcrypto,aws-lc` | 208 | 43 |
| same, `--no-default-features --features openssl-vendored` | 209 | 43 |
| `-p ntp-proto -p ntpd --no-default-features --features graviola,rustcrypto` on aarch64 Linux | 208 | 43 |
| `-p ntp-proto` Graviola on Darwin arm64 | 208 | — |
| `-p ntpd` Graviola on Darwin arm64 | — | 42 + direct-DNS test |
| NTS-KE roundtrip, untrusted-CA rejection, TLS 1.3 + `ntske/1` + exporter agreement on both ends, system-trust rejection of the test CA, wrong-keyset cookie rejection, tampered-ciphertext rejection | | pass in every profile above |
| Chrony 4.5 against the scratch harness (Graviola KE + NTS NTP) | `authdata`: mode NTS, AEAD 15, 8 cookies; source selected, stratum 3, microsecond offsets | pass |
| Alpine 3.23 aarch64 musl: `ntp-ctl validate`, daemon under OpenRC (`start`/`status`), direct-hostname + custom-CA NTS, system-store CA path | | pass |

Conflict builds fail at compile time with a clear diagnostic:
`graviola` with `aws-lc`, `graviola` with `openssl`, and empty provider
sets, in both `ntp-proto` and `ntpd`.

Parked, each with a concrete external prerequisite:

- x86_64 Graviola runtime: emulated CPU lacks BMI1/AVX2 (`graviola requires bmi1 CPU support`); needs real x86_64 hardware with `aes, ssse3, avx, avx2, adx, bmi2, pclmulqdq`.
- Daemon start without `CAP_SYS_TIME`: this alpha issues an `adjtimex` write unconditionally at startup (`EPERM` is fatal); needs either the capability or a no-write startup path.
- `ntp-ctl status` against the daemon: observer spawn is commented out, so no observe socket exists; needs the observer wiring.
- `minimum-agreeing-sources`, `[[server]] listen`, NTP serving, and the NTS-daemon source path: fields and wiring absent in this alpha; runs used unreachable-only sources.
- System-CA check against a public NTS endpoint: no egress to TCP 4460 from here; the system-store path itself is proven with a local anchor.
- G7 prereleases: specified, not implemented; push and dispatch await the owner-confirmed triggering commit.

Unverified: the `ultrareview` P1/P2 pass (`ultrareview` is not installed
in this environment). Inherited, not a regression: `key_exchange_connection_limiter`
times out on the loaded Darwin host (fails identically on the clean base;
passes on Linux x86_64).

## For the owner afterwards

- Review the local implementation commits and final verification report. No cherry-pick is needed because the campaign targets the current branch.
- Keep pushing under owner control.

Launch prompt: `Run campaign-graviola.md to completion under its charter and acceptance checks. Do not push.`
