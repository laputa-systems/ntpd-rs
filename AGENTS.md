# ntpd-rs (laputa-systems fork)

This is a fork of [pendulum-project/ntpd-rs](https://github.com/pendulum-project/ntpd-rs),
an NTP/NTS implementation in Rust. The fork adds an opt-in Graviola TLS provider
and publishes its own GitHub prereleases. Upstream comparison: identical NTP/NTS
protocol behavior, configuration fields, and clock discipline; the differences
below are additive.

## Graviola TLS provider

- Opt-in `graviola` Cargo feature in `ntpd` and `ntp-proto`. It selects the
  `rustls-graviola` 0.4.x `CryptoProvider` explicitly in `ntp-proto/src/tls_utils.rs`
  for NTS-KE clients and servers and passes the same provider to the platform
  verifier. No process-global provider installation is used for Graviola.
- `graviola` is mutually exclusive with the `aws-lc` and `openssl` TLS provider
  features at compile time; building with no TLS provider also fails clearly.
  `ntpd`'s `aws-lc` feature enables `ntp-proto/aws-lc` explicitly.
- The production profile without C-backed cryptography is
  `--no-default-features --features graviola,rustcrypto`. It keeps normal
  hostname lookup and direct NTS connections but omits SRV lookup (`srv`
  stays behind the compatibility builds with Hickory DNSSEC validation).
- Resolved: `rustls-graviola 0.4.0`, `graviola 0.4.1`, `getrandom 0.3.4`.
  License policy is unchanged (`deny.toml` allow list covers the Apache-2.0
  alternative of the new crates).

## Build and verify

- MSRV is Rust 1.95 (`cargo +1.95.0 check --locked -p ntpd --target x86_64-unknown-linux-musl --no-default-features --features graviola,rustcrypto`).
- The dependency closure assertion used in CI (`.github/workflows/checks.yaml`,
  Graviola matrix entry) fails if the active `ntpd` musl graph contains
  `aws-lc-rs`, `aws-lc-sys`, `ring`, `openssl`, or `openssl-sys`. Run it locally with
  `cargo tree --locked --prefix none -p ntpd --target x86_64-unknown-linux-musl --no-default-features --features graviola,rustcrypto --edges normal,build`.
- Graviola needs x86_64 `aes, ssse3, avx, avx2, adx, bmi2, pclmulqdq` or
  AArch64 `aes, sha2, pmull, neon`. Emulated x86_64 CPUs without AVX2 cannot
  execute it (the crate aborts at startup); use native AArch64 Linux runners
  for Linux runtime proof.
- The alpha daemon requires `CAP_SYS_TIME` even to start (unconditional
  `adjtimex` write at startup), has no `minimum-agreeing-sources` field yet,
  and its observer spawn is commented out, so `ntp-ctl status` has no socket
  to connect to. `ntp-ctl validate` works on configs. NTS sources validate
  end-to-end (local Chrony 4.5 interop proven); the NTP `[[server]]` block
  takes no `listen` address yet.

## Our GitHub prereleases

- Manual dispatch only: `gh workflow run prerelease.yml --ref main`.
  The workflow refuses non-default-branch dispatches, builds the portable
  triple set (`aarch64-apple-darwin`, both musl targets), runs the Graviola
  test suites, verifies statically linked binaries, and publishes
  per-platform zips plus a verified `SHA256SUMS` under a `release-<sha>` tag
  created through the GitHub API (`--verify-tag`, `--prerelease`).
- Linux builds run in the pinned Alpine builder image (`Dockerfile` at the
  repo root: pinned Alpine base, verified rustup installer, musl-linked LLVM,
  both musl targets, rust-src, musl-cargo wrapper, CRT stubs, `libutil.a`,
  musl-native `gcc`). The workflow uses plain `cargo` with the image C
  compiler as linker; `musl-cargo` stays in the image for repomod conformance.
  This repo's own `[target.'cfg(all())']` rustflags shadow `RUSTFLAGS`-style
  injection, so the workflow does not rely on it.
- This repository is registered in the repomod catalog as
  `laputa-systems/ntpd-rs = ["tool", "rust", "fork"]` and satisfies its
  `binary-release-tags`, `binary-release-standard`, `binary-release-static`,
  and `rust-musl-image` rules.

## Docs

- `docs/guide/installation.md` covers the Alpine/OpenRC install for the
  Graviola profile (build command, MSRV, musl and CPU requirements, CA
  certificates, NTS config, OpenRC service, BusyBox `ntpd` removal).
- `docs/guide/nts.md` covers NTS usage and server setup.
