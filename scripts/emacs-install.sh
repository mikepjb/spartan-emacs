#!/usr/bin/env bash
#
# Build GUI Emacs from a release tag on Arch Linux or macOS.
#
# Install dependencies first:
#
# Arch:
#   sudo pacman -Syu --needed \
#     base-devel autoconf texinfo pkgconf gtk3 gnutls libgccjit \
#     sqlite libxml2 librsvg libpng libjpeg-turbo \
#     giflib libtiff libwebp
#
# macOS (Homebrew):
#   xcode-select --install
#   brew install autoconf texinfo pkgconf gnutls gmp \
#     sqlite libxml2 libgccjit
#
# tree-sitter dep removed from both, re-add if you want this in future.

set -euo pipefail

EMACS_SOURCE="https://git.savannah.gnu.org/git/emacs.git"
EMACS_VERSION="31.1"
EMACS_TAG="emacs-${EMACS_VERSION}"
BUILD_BRANCH="build/${EMACS_TAG}"
SOURCE_PATH="$HOME/src/emacs"
INSTALL_PREFIX="$HOME/.local"

# Arch: set EMACS_GUI=x11 for an X11 build.
EMACS_GUI="${EMACS_GUI:-wayland}"

die() {
    echo "Error: $*" >&2
    exit 1
}

command -v git >/dev/null 2>&1 || die "git is not installed"

case "$(uname -s)" in
    Linux|Darwin) ;;
    *) die "Only Linux and macOS are supported" ;;
esac

# Create the repository only on the first run.
if [[ ! -e "$SOURCE_PATH" ]]; then
    mkdir -p "$SOURCE_PATH"
    git -C "$SOURCE_PATH" init
fi

[[ -d "$SOURCE_PATH/.git" ]] ||
    die "$SOURCE_PATH is not a Git checkout"

cd "$SOURCE_PATH"

# Protect tracked source edits before switching versions/build branches.
[[ -z "$(git status --porcelain --untracked-files=no)" ]] ||
    die "Commit or stash tracked changes in $SOURCE_PATH first"

# No network request if we already have the requested tag.
if git show-ref --verify --quiet "refs/tags/$EMACS_TAG"; then
    echo "Using local tag $EMACS_TAG; skipping fetch"
else
    echo "Fetching $EMACS_TAG"
    git fetch --depth=1 "$EMACS_SOURCE" \
        "refs/tags/$EMACS_TAG:refs/tags/$EMACS_TAG"
fi

TAG_COMMIT="$(git rev-parse "refs/tags/${EMACS_TAG}^{commit}")"

# Keep HEAD attached to a local branch at the release commit.
if git show-ref --verify --quiet "refs/heads/$BUILD_BRANCH"; then
    BRANCH_COMMIT="$(git rev-parse "refs/heads/$BUILD_BRANCH")"

    [[ "$BRANCH_COMMIT" == "$TAG_COMMIT" ]] ||
        die "$BUILD_BRANCH has moved away from $EMACS_TAG"

    git checkout "$BUILD_BRANCH"
else
    git checkout -b "$BUILD_BRANCH" "$TAG_COMMIT"
fi

CONFIGURE_FLAGS=(
    --with-native-compilation=aot
    # --with-tree-sitter
    --with-modules
    --with-gnutls
    --with-sqlite3
    --with-xml2
)

case "$(uname -s)" in
    Linux)
        JOBS="$(nproc)"

        CONFIGURE_FLAGS+=(
            "--prefix=$INSTALL_PREFIX"
            --with-rsvg
            --with-png
            --with-jpeg
            --with-gif
            --with-tiff
            --with-webp
        )

        case "$EMACS_GUI" in
            wayland) CONFIGURE_FLAGS+=(--with-pgtk) ;;
            x11) CONFIGURE_FLAGS+=(--with-x-toolkit=gtk3) ;;
            *) die "EMACS_GUI must be wayland or x11" ;;
        esac
        ;;

    Darwin)
        command -v brew >/dev/null 2>&1 ||
            die "Homebrew is required for this macOS setup"

        JOBS="$(sysctl -n hw.ncpu)"
        BREW_PREFIX="$(brew --prefix)"
        JIT_PREFIX="$(brew --prefix libgccjit)"
        XML_PREFIX="$(brew --prefix libxml2)"
        SQLITE_PREFIX="$(brew --prefix sqlite)"

        export PATH="$(brew --prefix texinfo)/bin:$PATH"

        export PKG_CONFIG_PATH="$XML_PREFIX/lib/pkgconfig:$SQLITE_PREFIX/lib/pkgconfig:$BREW_PREFIX/lib/pkgconfig:$BREW_PREFIX/share/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

        export CPPFLAGS="-I$JIT_PREFIX/include -I$JIT_PREFIX/lib/gcc/current/include ${CPPFLAGS:-}"
        export LDFLAGS="-L$JIT_PREFIX/lib -L$JIT_PREFIX/lib/gcc/current ${LDFLAGS:-}"

        CONFIGURE_FLAGS+=(--with-ns)
        ;;
esac

# Git checkouts need generated configure/build files.
./autogen.sh

# Separate build directories for each release and GUI backend.
if [[ "$(uname -s)" == Darwin ]]; then
    BUILD_PATH="$SOURCE_PATH/build/${EMACS_TAG}-ns"
else
    BUILD_PATH="$SOURCE_PATH/build/${EMACS_TAG}-${EMACS_GUI}"
fi

mkdir -p "$BUILD_PATH"
cd "$BUILD_PATH"

"$SOURCE_PATH/configure" "${CONFIGURE_FLAGS[@]}"
make -j"$JOBS"
make install

if [[ "$(uname -s)" == Darwin ]]; then
    echo "Built app: $BUILD_PATH/nextstep/Emacs.app"
    echo "Copy it to ~/Applications or /Applications."
else
    echo "Installed: $INSTALL_PREFIX/bin/emacs"
fi
