# Dotfiles dev tasks. Run `just` for the list.
# (Ignored by stow — see install/03-dotfiles/05-stow.sh — so it stays
# repo-local and is never symlinked into $HOME.)

# Show available recipes
default:
    @just --list

# Run the full hermetic test suite
test:
    ./test/run.sh

# Run only tests whose name matches the given filters, e.g. `just test-one stow`
test-one *filters:
    ./test/run.sh {{filters}}

# Excluded codes are structural false positives: SC1090/SC1091 (dynamic or
# relative `source` paths shellcheck can't resolve), SC2088 (deliberate
# literal ~ in user-facing message strings).
# Shellcheck every shell script in the repo
lint:
    @shellcheck -x --severity=warning -e SC1090,SC1091,SC2088 \
        bootstrap.sh install-nvim.sh \
        install/lib/*.sh install/*/*.sh \
        test/run.sh test/lib/*.sh test/verify-*.sh
