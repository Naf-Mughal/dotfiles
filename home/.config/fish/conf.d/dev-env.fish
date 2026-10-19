# Dev toolchain environment. One specialised manager per language:
#   node: fnm   rust: rustup (pacman)   python: uv   go: built-in toolchains   java: SDKMAN   bun: ~/.bun
#   everything else / monorepos: mise (activated in config.fish)
set -gx ANDROID_HOME $HOME/Android/Sdk
set -gx ANDROID_SDK_ROOT $ANDROID_HOME
set -gx ANDROID_AVD_HOME $HOME/.android/avd
set -gx SDKMAN_DIR $HOME/.sdkman
set -gx NDK_HOME $ANDROID_HOME/ndk/28.2.13676358   # Tauri Android / Gradle NDK
set -gx JAVA_HOME $SDKMAN_DIR/candidates/java/current
set -gx GOTOOLCHAIN auto
set -gx RUSTC_WRAPPER sccache
set -gx SCCACHE_IDLE_TIMEOUT 120   # sccache server exits after 2 idle minutes (default 10)
set -gx BUN_INSTALL $HOME/.bun

fish_add_path -g $BUN_INSTALL/bin $HOME/.cargo/bin $HOME/go/bin $JAVA_HOME/bin \
    $ANDROID_HOME/cmdline-tools/latest/bin $ANDROID_HOME/platform-tools $ANDROID_HOME/emulator

# SDKMAN is a bash tool: run `sdk ...` through bash. `sdk default` changes the symlink
# $JAVA_HOME points at, so new shells pick it up.
function sdk --description 'SDKMAN (runs in bash)'
    bash -c 'source "$SDKMAN_DIR/bin/sdkman-init.sh" && sdk "$@"' sdk $argv
end

# node: fnm (switches on cd from .node-version / .nvmrc / package.json engines)
if command -q fnm
    fnm env --use-on-cd --shell fish | source
end
