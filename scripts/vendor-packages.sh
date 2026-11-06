#!/usr/bin/env bash
#
# Used to lock-in dependencies, mainly these are major-modes for
# working with languages whose mode is not provided as part of emacs.

set -euo pipefail

VENDOR_PATH="${VENDOR_PATH:-$HOME/.emacs.d/vendor}"

# Full or short commit SHAs.
GO_REF=3a71d28ab47d
CLOJURE_REF=d864d6f26c8a
REFORMATTER_REF=2bd8818f3f21
ZIG_REF=62bfbaced022
MARKDOWN_REF=e2e2bc753b43
HCL_REF=1da895ed75d2
TERRAFORM_REF=01635df3625c
TYPESCRIPT_REF=2535780bdb31

mkdir -p "$VENDOR_PATH"
workdir="$(mktemp -d "$VENDOR_PATH/.vendor.XXXXXXXX")"
trap 'rm -rf -- "$workdir"' EXIT
mkdir "$workdir/files"

vendor() {
    local repo="$1"
    local ref="$2"
    local file="$3"
    local checkout="$workdir/repo"
    local commit

    if [[ ! "$ref" =~ ^[[:xdigit:]]{7,40}$ ]]; then
        printf 'Invalid commit SHA: %s\n' "$ref" >&2
        return 1
    fi

    git clone --quiet --no-checkout "$repo" "$checkout"

    # Fails if the short SHA is missing or ambiguous.
    commit="$(git -C "$checkout" rev-parse --verify "${ref}^{commit}")"

    printf 'Vendoring %s at %s\n' "$file" "$commit"
    git -C "$checkout" show "$commit:$file" > "$workdir/files/$file"
    test -s "$workdir/files/$file"

    rm -rf -- "$checkout"
}

echo 'Vendoring 3rd party packages...'

vendor https://github.com/dominikh/go-mode.el.git \
    "$GO_REF" go-mode.el

vendor https://github.com/clojure-emacs/clojure-mode.git \
    "$CLOJURE_REF" clojure-mode.el

vendor https://github.com/purcell/emacs-reformatter.git \
    "$REFORMATTER_REF" reformatter.el

vendor https://codeberg.org/ziglang/zig-mode.git \
    "$ZIG_REF" zig-mode.el

vendor https://github.com/jrblevin/markdown-mode.git \
    "$MARKDOWN_REF" markdown-mode.el

vendor https://github.com/hcl-emacs/hcl-mode.git \
    "$HCL_REF" hcl-mode.el

vendor https://github.com/hcl-emacs/terraform-mode.git \
    "$TERRAFORM_REF" terraform-mode.el

vendor https://github.com/emacs-typescript/typescript.el.git \
    "$TYPESCRIPT_REF" typescript-mode.el

# Install only after every extraction succeeds.
for file in "$workdir/files"/*.el; do
    mv -f -- "$file" "$VENDOR_PATH/"
done

echo 'Done.'
