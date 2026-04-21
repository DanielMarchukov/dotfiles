# 02-languages

Language toolchains and language-adjacent tools.

## Scope

- `01-temurin-jdk.sh` — Adoptium Temurin JDK 21 via APT.
- `02-installcert-java.sh` — optional Java keystore cert import (gates
  on `InstallCert.java` file presence at `$INSTALLCERT_SOURCE`).
- `03-go.sh` — Go + gopls.
- `04-cpp-toolchain.sh` — LLVM 19, g++-14, ninja, vcpkg, and pipx-
  installed `pre-commit` / `cmake-format` / `mdformat`.
- `05-gradle.sh` — Gradle distribution (fetched over HTTPS — cert
  import in `02-installcert-java` is load-bearing on corporate
  networks).
- `06-palantir-java-format.sh` — native binary from Maven Central; no
  JDK dependency despite the name.
- `07-rust.sh` — rustup + stable toolchain + cargo dev tools
  (`cargo-llvm-cov`, `cargo-audit`, `cargo-deny`).
- `08-node.sh` — NVM + latest LTS Node.

## Ordering

- JDK subchain MUST stay ordered: `01-temurin-jdk` →
  `02-installcert-java` → `05-gradle`.
- Everything else (`03-go`, `04-cpp`, `06-palantir`, `07-rust`,
  `08-node`) is independent and freely reorderable.

## Produces for downstream

- `cargo` on PATH + sourced env (consumed by `05-tools/03-pay-respects`,
  `05-tools/04-cli-extensions`, `05-tools/05-taskwarrior`).
- Temurin JDK at `/usr/lib/jvm/temurin-21-jdk-amd64` (consumed by
  `04-editors/03-neovim-plugins` for Mason Java tools).
- `pipx` tools on PATH.
- `vcpkg` at `$HOME/vcpkg`.
