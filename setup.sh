#!/bin/bash

# Exit on any error and handle interruption signals
set -e

# Trap function to handle script interruption
cleanup_and_exit() {
    echo ""
    echo "🛑 Setup script interrupted by user. Exiting..."
    exit 130
}

# Trap SIGINT (Ctrl+C) and SIGTERM signals
trap cleanup_and_exit SIGINT SIGTERM

################################################################################

USERNAME=$(whoami)

# The default Xcode version to install via xcodes
XCODE_VERSION=26.6

# The default iPhone simulator version to set up
IPHONE_VERSION=16

# The default iOS versions to install via xcodes runtimes
XCODE_IOS_VERSION=26.5
IOS_VERSION=26.5

# Define Android SDK version
ANDROID_API_LEVEL=36
ANDROID_BUILD_TOOLS_VERSION="36.0.0"

# The default Android device to create for emulator
ANDROID_DEVICE_NAME="pixel_9"
ANDROID_AVD_NAME="${ANDROID_DEVICE_NAME}_api_${ANDROID_API_LEVEL}"

# The Node.js version to install via proto
NODE_VERSION=24

# The Ruby version to install via proto
RUBY_VERSION=3.4.9

# The Python version to install via proto
PYTHON_VERSION=3.14.4

# The Go version to install via proto
GO_VERSION=1.26.3

# The Rust version to install via proto
RUST_VERSION=1.95.0

# The Java version to install via proto
JAVA_VERSION=25

# The default npm registry
NPM_REGISTRY=https://registry.npmjs.org/

# Whether the registry needs credentials: "auto" asks the registry and only logs
# in when it actually refuses, "true" always logs in, "false" never does. Auto is
# safe for the public registry, which serves packages without any login.
NPM_AUTH_REQUIRED=auto

# npm login auth type: "legacy" (prompts for username/password/token, works with
# any registry) or "web" (browser-based SSO, supported by npmjs.com and some
# private registries with SSO configured)
NPM_AUTH_TYPE=legacy

# There are reported issues when using $TMPDIR after macOS upgrades and using
# the following configuration variable seems to be more safe.
TMPDIR=$(getconf DARWIN_USER_TEMP_DIR)

# Homebrew keeps its trust store under $XDG_CONFIG_HOME (falling back to
# ~/.homebrew when unset). This script runs before chezmoi delivers the ~/.zshrc
# that exports XDG_CONFIG_HOME, so without pinning it here every tap trusted
# below lands in ~/.homebrew/trust.json and is invisible to later shells.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"

################################################################################
# Function definitions
################################################################################

get_node_auth_token() {
  if [ -f "${HOME}/.npmrc" ]; then
    cat "${HOME}/.npmrc" | grep -o '_authToken=.*' -m 1 | sed 's/_authToken=//g'
  else
    echo ""
  fi
}

################################################################################
# Main script execution
################################################################################

echo "🚀 Starting setup for user: $USERNAME"
echo ""

################################################################################
# Homebrew Installation
################################################################################

echo "🍺 Checking for Homebrew installation..."
if ! which brew > /dev/null; then
  echo "📦 Installing Homebrew..."
  /usr/bin/env bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo "✅ Homebrew installation completed"
else
  echo "✅ Homebrew is already installed"
fi

echo "🔍 Locating Homebrew installation..."
export HOMEBREW_PREFIX=$([[ -d "/opt/homebrew" ]] && echo "/opt/homebrew" || echo "/usr/local")
echo "📍 Homebrew prefix: $HOMEBREW_PREFIX"

echo "🔧 Initializing Homebrew environment..."
eval "$($HOMEBREW_PREFIX/bin/brew shellenv)"
echo "✅ Homebrew environment initialized"
echo ""

################################################################################
# Homebrew Dependencies Installation
################################################################################

echo "📦 Installing dependencies via Homebrew..."

# Formulae owned by proto — brew copies are uninstalled after brew bundle so
# proto's shims are the only copy on PATH
proto_owned=(
  "node" "node@16" "node@18" "node@20" "node@22" "node@24"
  "python" "python@3.8" "python@3.9" "python@3.10" "python@3.11" "python@3.12" "python@3.13" "python@3.14"
  "ruby" "ruby@3.0" "ruby@3.1" "ruby@3.2" "ruby@3.3" "ruby@3.4"
  "go" "rust"
  "pnpm" "yarn" "uv" "cocoapods" "sdkman-cli"
)

# Resolve Brewfile location: use local copy if running from a cloned repo,
# otherwise download from GitHub raw content alongside this script.
# The repo is a chezmoi source, so the Brewfile lives at private_dot_Brewfile.
DOTFILES_RAW_BASE="https://raw.githubusercontent.com/jgornick/dotfiles/master"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
local_brewfile="${script_dir}/private_dot_Brewfile"

if [ -f "${local_brewfile}" ]; then
  echo "📍 Using local Brewfile: ${local_brewfile}"
  brewfile_path="${local_brewfile}"
else
  echo "📥 Downloading Brewfile from ${DOTFILES_RAW_BASE}/private_dot_Brewfile ..."
  brewfile_path=$(mktemp "${TMPDIR:-/tmp}/Brewfile.XXXXXX")
  curl -fsSL "${DOTFILES_RAW_BASE}/private_dot_Brewfile" -o "${brewfile_path}"
  echo "📍 Using downloaded Brewfile: ${brewfile_path}"
fi

# Homebrew 6 refuses to load formulae and casks from third-party taps until they
# are trusted ($HOMEBREW_REQUIRE_TAP_TRUST defaults on), which aborts a
# non-interactive `brew bundle`. Trust every tap the Brewfile declares up front.
# The Brewfile also marks its third-party entries `trusted: true` so `brew
# bundle` works the same way when chezmoi runs it later.
if brew trust --json=v1 >/dev/null 2>&1; then
  echo "🔑 Trusting third-party taps declared in the Brewfile..."
  while IFS= read -r tap_name; do
    [ -n "${tap_name}" ] || continue
    brew trust --tap "${tap_name}"
  done < <(sed -nE 's/^[[:space:]]*tap[[:space:]]+"([^"]+)".*/\1/p' "${brewfile_path}")
  echo "✅ Tap trust configured"
else
  echo "⏭️  This Homebrew has no 'brew trust' command; nothing to trust"
fi
echo ""

brew bundle install --no-upgrade --file="${brewfile_path}"

# Clean up temp Brewfile if we downloaded it
if [ "${brewfile_path}" != "${local_brewfile}" ]; then
  rm -f "${brewfile_path}"
fi
echo "✅ Homebrew dependencies installation completed"
echo ""

echo "🔓 Removing brew copies of proto-managed packages..."

for package in "${proto_owned[@]}"; do
  if brew list --formula "$package" >/dev/null 2>&1; then
    echo "🗑️  Uninstalling proto-managed package: $package"
    # Fall back to unlink if it's required as a dependency by another formula
    if ! brew uninstall "$package" 2>/dev/null; then
      echo "🔗 $package is required by another formula; unlinking instead"
      brew unlink "$package" 2>/dev/null || true
    fi
  fi
done

echo "✅ Proto-managed package cleanup completed"
echo ""

################################################################################
# Xcode Installation
################################################################################

echo "📱 Setting up Xcode ${XCODE_VERSION}..."
if xcodes installed 2>/dev/null | grep -q "${XCODE_VERSION}"; then
  xcode_path="$(xcodes installed 2>/dev/null | grep "${XCODE_VERSION}" | head -1)"
  echo "✅ Xcode ${XCODE_VERSION} is already installed at: ${xcode_path}"
else
  echo "📥 Installing Xcode ${XCODE_VERSION}... (this may take a while)"
  xcodes install "${XCODE_VERSION}" --experimental-unxip
  echo "✅ Xcode ${XCODE_VERSION} installation completed"
fi

echo "🔧 Setting Xcode ${XCODE_VERSION} as selected version..."
xcodes select "${XCODE_VERSION}"

# `xcodes select` is a no-op if it cannot escalate, which leaves the active
# developer directory pointing at the Command Line Tools. Every xcrun-based tool
# then reports the utility it wants as missing ("unable to find utility
# ... not a developer tool or in PATH") rather than saying Xcode is not selected.
active_developer_dir="$(xcode-select -p 2>/dev/null || true)"
if [[ "${active_developer_dir}" != *".app/Contents/Developer" ]]; then
  echo "📝 Active developer directory is '${active_developer_dir:-none}', not an Xcode.app."
  echo "   Pointing it at Xcode ${XCODE_VERSION}. Please provide your sudo password..."
  sudo xcode-select -s "$(xcodes select -p)"
  active_developer_dir="$(xcode-select -p)"
fi
echo "✅ Xcode ${XCODE_VERSION} is now selected (${active_developer_dir})"

# A freshly unpacked Xcode still has to install its bundled toolchain packages.
# Until it does, the developer directory is missing build tools that xcrun
# resolves lazily, so `xcodebuild`, `simctl` and CocoaPods fail with confusing
# "not a developer tool" errors. This also accepts the license.
echo "🚀 Checking Xcode first-launch components..."
if xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
  echo "✅ Xcode first-launch components already installed"
else
  echo "📦 Installing Xcode first-launch components. Please provide your sudo password..."
  sudo xcodebuild -runFirstLaunch
  echo "✅ Xcode first-launch components installed"
fi

echo "📄 Checking Xcode license status..."
if xcodebuild -license status >/dev/null 2>&1; then
  echo "✅ Xcode license already accepted"
else
  echo "📝 Xcode license needs to be accepted. Please provide your sudo password..."
  sudo xcodebuild -license accept
  echo "✅ Xcode license agreement completed"
fi
echo ""

################################################################################
# Development Tools Installation (via proto)
################################################################################

echo "🛠️  Setting up language runtimes via proto..."

# Add proto shims to PATH so installed tools are available in this session
export PROTO_HOME="${HOME}/.proto"
export PATH="${PROTO_HOME}/shims:${PROTO_HOME}/bin:${PATH}"

echo "🟢 Setting up Node.js ${NODE_VERSION}..."
proto install node "${NODE_VERSION}"
proto pin node "${NODE_VERSION}" --to global
echo "✅ Node.js ${NODE_VERSION} is now active"
echo ""

echo "📦 Setting up npm via proto..."
# npm is its own proto tool: the node plugin ships only the `node` shim, so npm,
# npx and node-gyp stay off PATH — and every later npm call in this script fails
# — unless npm is installed and pinned in its own right.
proto install npm
proto pin npm latest --to global --resolve
echo "✅ npm is now active"
echo ""

echo "📦 Setting up pnpm and yarn via proto..."
proto install pnpm
proto pin pnpm latest --to global --resolve
proto install yarn
proto pin yarn latest --to global --resolve
echo "✅ pnpm and yarn are now active"
echo ""

echo "💎 Setting up Ruby ${RUBY_VERSION}..."
proto install ruby "${RUBY_VERSION}"
proto pin ruby "${RUBY_VERSION}" --to global
echo "✅ Ruby ${RUBY_VERSION} is now active"

# Gem executables (cocoapods' `pod`, for one) get no proto shim, so add the gem
# bin directory the way ~/.zshrc does — appended, to keep the shims winning for
# ruby/gem/bundle themselves.
for gem_bin in "${PROTO_HOME}"/tools/ruby/*/bin; do
  [ -d "${gem_bin}" ] && export PATH="${PATH}:${gem_bin}"
done
unset gem_bin

if ! gem list -i bundler >/dev/null 2>&1; then
  echo "📦 Installing bundler gem..."
  gem install bundler
  echo "✅ bundler installation completed"
else
  echo "✅ bundler is already installed"
fi

if ! gem list -i cocoapods >/dev/null 2>&1; then
  echo "📦 Installing cocoapods gem..."
  gem install cocoapods
  echo "✅ cocoapods installation completed"
else
  echo "✅ cocoapods is already installed"
fi
echo ""

echo "🐍 Setting up Python ${PYTHON_VERSION}..."
proto install python "${PYTHON_VERSION}"
proto pin python "${PYTHON_VERSION}" --to global
echo "✅ Python ${PYTHON_VERSION} is now active"
echo ""

echo "🐍 Setting up uv via proto..."
proto install uv
proto pin uv latest --to global --resolve
echo "✅ uv is now active"
echo ""

echo "🐹 Setting up Go ${GO_VERSION}..."
proto install go "${GO_VERSION}"
proto pin go "${GO_VERSION}" --to global
echo "✅ Go ${GO_VERSION} is now active"
echo ""

echo "🦀 Setting up Rust ${RUST_VERSION}..."
proto install rust "${RUST_VERSION}"
proto pin rust "${RUST_VERSION}" --to global
# proto's rust plugin delegates to rustup, which creates no proto shims and puts
# cargo/rustc in ~/.cargo/bin. rustup wires that into ~/.zshenv for interactive
# shells; this non-login bash never reads it, so source it directly.
[ -f "${HOME}/.cargo/env" ] && . "${HOME}/.cargo/env"
echo "✅ Rust ${RUST_VERSION} is now active"
echo ""

echo "☕️ Setting up Java ${JAVA_VERSION}..."
proto install java "${JAVA_VERSION}"
proto pin java "${JAVA_VERSION}" --to global
echo "✅ Java ${JAVA_VERSION} is now active"
echo ""

################################################################################
# Docker Configuration
################################################################################

echo "🐳 Setting up Docker configuration..."
docker_config_dir="${HOME}/.docker"
docker_config_file="${docker_config_dir}/config.json"
docker_plugin_path="${HOMEBREW_PREFIX}/lib/docker/cli-plugins"

# Create .docker directory if it doesn't exist
mkdir -p "${docker_config_dir}"

# Initialize config file if it doesn't exist
if [ ! -f "${docker_config_file}" ]; then
  echo "{}" > "${docker_config_file}"
fi

# Check if Homebrew plugin path is already configured
if jq -e ".cliPluginsExtraDirs[]? | select(. == \"${docker_plugin_path}\")" "${docker_config_file}" >/dev/null 2>&1; then
  echo "✅ Docker CLI plugins already configured"
else
  echo "🔧 Configuring Docker CLI plugins..."

  # Add or update cliPluginsExtraDirs with Homebrew path (edit in-place)
  jq ".cliPluginsExtraDirs = (.cliPluginsExtraDirs // []) + [\"${docker_plugin_path}\"] | .cliPluginsExtraDirs |= unique" \
    "${docker_config_file}" > "${docker_config_file}.tmp" && mv "${docker_config_file}.tmp" "${docker_config_file}"

  echo "✅ Docker CLI plugins configured"
fi
echo ""

################################################################################
# iOS Simulator Setup
################################################################################

# Ask CoreSimulator, not xcodes, whether a runtime is present: simctl availability
# is what `simctl create` actually needs, and it stays correct regardless of how
# xcodes formats its listing (it prints "iOS 26.5 [Apple Silicon] (Installed)", so
# grepping for "iOS 26.5 (Installed)" never matches and reinstalls every run).
ios_runtime_available() {
  xcrun simctl list runtimes | grep -qF "com.apple.CoreSimulator.SimRuntime.iOS-${1//./-}"
}

install_ios_runtime() {
  if ios_runtime_available "${1}"; then
    echo "✅ iOS ${1} runtime is already installed"
    return
  fi
  echo "📥 Installing iOS ${1} runtime... (this may take a while)"
  echo ""
  xcodes runtimes install "iOS ${1}"
  echo "✅ iOS ${1} runtime installation completed"
}

echo "📱 Setting up iOS ${XCODE_IOS_VERSION} simulator runtime (required for Xcode ${XCODE_VERSION})..."
install_ios_runtime "${XCODE_IOS_VERSION}"
echo ""

# Installing the same version twice registers a second, duplicate disk image that
# CoreSimulator marks unusable, which in turn breaks runtime lookup for simctl.
if [ "${IOS_VERSION}" != "${XCODE_IOS_VERSION}" ]; then
  echo "📱 Setting up iOS ${IOS_VERSION} simulator runtime..."
  install_ios_runtime "${IOS_VERSION}"
  echo ""
fi

echo "📱 Setting up iPhone ${IPHONE_VERSION} simulator device..."
simulator_iphone_name="iPhone ${IPHONE_VERSION}"
simulator_name="${simulator_iphone_name} - iOS ${IOS_VERSION}"
if xcrun simctl list devices | grep -qF "${simulator_name}"; then
  echo "✅ iPhone ${IPHONE_VERSION} simulator already exists"
elif ! ios_runtime_available "${IOS_VERSION}"; then
  echo "⚠️  Skipping simulator: iOS ${IOS_VERSION} runtime is not available to simctl."
  echo "   Check 'xcrun simctl runtime list' for unusable images, then re-run."
else
  echo "📱 Creating simulator: ${simulator_name}"
  # Pass the runtime identifier rather than the "iOS 26.5" display name, which
  # fails to resolve whenever more than one image reports that same version.
  xcrun simctl create "${simulator_name}" "${simulator_iphone_name}" \
    "com.apple.CoreSimulator.SimRuntime.iOS-${IOS_VERSION//./-}"
  echo "✅ iPhone ${IPHONE_VERSION} simulator creation completed"
fi
echo ""

################################################################################
# Android SDK Setup
################################################################################

echo "🤖 Setting up Android SDK..."
# The android-commandlinetools cask (Brewfile) provides sdkmanager/avdmanager
# and anchors the SDK under brew's share directory; all sdkmanager-installed
# components (platforms, build-tools, emulator, system images) land there too.
export ANDROID_HOME="$(brew --prefix)/share/android-commandlinetools"
export ANDROID_SDK_ROOT="${ANDROID_HOME}"

if [ ! -f "${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager" ]; then
  echo "📥 Android SDK command-line tools not found. Installing cask..."
  brew install --cask android-commandlinetools
  echo "✅ Android SDK command-line tools installed"
else
  echo "✅ Android SDK command-line tools already installed"
fi

# Set up PATH for sdkmanager
export PATH="${ANDROID_HOME}/cmdline-tools/latest/bin:${PATH}"

# Accept Android SDK licenses
echo "📄 Accepting Android SDK licenses..."
yes | sdkmanager --licenses >/dev/null 2>&1 || true
echo "✅ Android SDK licenses accepted"

# Install Android SDK Platform
echo "📱 Installing Android SDK Platform ${ANDROID_API_LEVEL}..."
if [ -d "${ANDROID_HOME}/platforms/android-${ANDROID_API_LEVEL}" ]; then
  echo "✅ Android SDK Platform ${ANDROID_API_LEVEL} already installed"
else
  sdkmanager "platforms;android-${ANDROID_API_LEVEL}"
  echo "✅ Android SDK Platform ${ANDROID_API_LEVEL} installation completed"
fi

# Install Android SDK Build-Tools
echo "🔧 Installing Android SDK Build-Tools ${ANDROID_BUILD_TOOLS_VERSION}..."
if [ -d "${ANDROID_HOME}/build-tools/${ANDROID_BUILD_TOOLS_VERSION}" ]; then
  echo "✅ Android SDK Build-Tools ${ANDROID_BUILD_TOOLS_VERSION} already installed"
else
  sdkmanager "build-tools;${ANDROID_BUILD_TOOLS_VERSION}"
  echo "✅ Android SDK Build-Tools ${ANDROID_BUILD_TOOLS_VERSION} installation completed"
fi

# Install Android SDK Platform-Tools
echo "🔧 Installing Android SDK Platform-Tools..."
if [ -d "${ANDROID_HOME}/platform-tools" ]; then
  echo "✅ Android SDK Platform-Tools already installed"
else
  sdkmanager "platform-tools"
  echo "✅ Android SDK Platform-Tools installation completed"
fi

# Install Android Emulator
echo "📲 Installing Android Emulator..."
if [ -d "${ANDROID_HOME}/emulator" ]; then
  echo "✅ Android Emulator already installed"
else
  sdkmanager "emulator"
  echo "✅ Android Emulator installation completed"
fi

# Install system image for emulator
# Detect architecture: arm64 for Apple Silicon, x86_64 for Intel Macs
if [[ $(uname -m) == "arm64" ]]; then
  arch="arm64-v8a"
  echo "💿 Installing Android system image (API ${ANDROID_API_LEVEL} ARM64)..."
else
  arch="x86_64"
  echo "💿 Installing Android system image (API ${ANDROID_API_LEVEL} x86_64)..."
fi

system_image="system-images;android-${ANDROID_API_LEVEL};google_apis;${arch}"
system_image_path="${ANDROID_HOME}/system-images/android-${ANDROID_API_LEVEL}/google_apis/${arch}"

if [ -d "${system_image_path}" ]; then
  echo "✅ Android system image already installed"
else
  sdkmanager "${system_image}"
  echo "✅ Android system image installation completed"
fi

# Create Android Virtual Device (AVD)
echo "📱 Setting up Android emulator: ${ANDROID_AVD_NAME}..."
export PATH="${ANDROID_HOME}/emulator:${PATH}"

if avdmanager list avd | grep -q "Name: ${ANDROID_AVD_NAME}"; then
  echo "✅ Android emulator '${ANDROID_AVD_NAME}' already exists"
else
  echo "📱 Creating Android Virtual Device: ${ANDROID_AVD_NAME}"
  echo "   Device: ${ANDROID_DEVICE_NAME}"
  echo "   API Level: ${ANDROID_API_LEVEL} (Android 16)"
  echo "no" | avdmanager create avd \
    --name "${ANDROID_AVD_NAME}" \
    --package "${system_image}" \
    --device "${ANDROID_DEVICE_NAME}"
  echo "✅ Android emulator creation completed"
fi
echo ""

################################################################################
# GitHub & Git Configuration
################################################################################

echo "📧 Setting up GitHub authentication and Git configuration..."

# Check if already authenticated with the user:email scope (required for gh api user/emails)
if gh auth status >/dev/null 2>&1 && gh api user/emails >/dev/null 2>&1; then
  echo "✅ GitHub CLI already authenticated with user scope"
else
  echo "🔑 Authenticating with GitHub CLI..."
  gh auth login -p ssh -h github.com --skip-ssh-key -w -s user
  echo "✅ GitHub authentication completed"
fi
echo ""

echo "📬 Retrieving GitHub email address..."
github_email=$(gh api user/emails | jq -r '.[] | select(.primary == true) | .email')
echo "📧 Found GitHub email: ${github_email}"

echo "🔧 Configuring Git with email: ${github_email}"
git config --global user.email "${github_email}"
echo "✅ Git configuration completed"
echo ""

################################################################################
# NPM Configuration
################################################################################

echo "📦 Configuring npm registry..."
npm config -L user set registry "${NPM_REGISTRY}"
echo "✅ npm registry set to: ${NPM_REGISTRY}"
echo ""

################################################################################
# Credentials & Authentication Setup
################################################################################

echo "🔐 Setting up npm authentication..."

# Export credentials only when a token actually exists: empty values make npm and
# yarn send blank credentials rather than falling back to anonymous access.
export_npm_auth() {
  NODE_AUTH_TOKEN=$(get_node_auth_token)

  if [ -z "${NODE_AUTH_TOKEN}" ]; then
    unset NODE_AUTH_TOKEN
    return 1
  fi

  export NODE_AUTH_TOKEN
  export YARN_NPM_AUTH_IDENT="${NODE_AUTH_TOKEN}"
  export npm_config__auth="${NODE_AUTH_TOKEN}"
}

# Ask the registry whether it will serve packages with the credentials we already
# have (possibly none). npm does the request rather than curl so the probe honours
# the .npmrc proxy, CA and strict-ssl settings that private registries usually sit
# behind. Exit codes: 0 = readable as-is, 1 = credentials required, 2 = unclear.
#
# Registries disagree on how they refuse: some answer 401/403, but others (GitHub
# Packages among them) answer 404 so they never reveal whether a package exists.
# A 404 is therefore indistinguishable from a genuinely absent package, so this
# can establish that auth IS needed but never that it isn't.
probe_npm_registry() {
  npm_probe_output=$(npm view npm version --registry="${NPM_REGISTRY}" 2>&1) && return 0

  case "${npm_probe_output}" in
    *"code E401"* | *"code E403"* | *ENEEDAUTH*) return 1 ;;
    *) return 2 ;;
  esac
}

npm_auth_required="${NPM_AUTH_REQUIRED}"

if [ "${npm_auth_required}" = auto ]; then
  echo "🔎 Checking whether ${NPM_REGISTRY} needs credentials..."

  probe_status=0
  probe_npm_registry || probe_status=$?

  case "${probe_status}" in
    0)
      npm_auth_required=false
      echo "✅ Registry is readable without logging in"
      ;;
    1)
      npm_auth_required=true
      echo "🔒 Registry refused the request as unauthenticated"
      ;;
    *)
      npm_auth_required=false
      echo "⚠️  Could not tell whether ${NPM_REGISTRY} needs credentials."
      echo "   Continuing without login; set NPM_AUTH_REQUIRED=true if installs fail."
      ;;
  esac
  echo ""
fi

if [ "${npm_auth_required}" != true ]; then
  echo "⏭️  Skipping npm login for ${NPM_REGISTRY}"
  # A token may still be present for private scopes; reuse it if so.
  if export_npm_auth; then
    echo "✅ Reusing existing authentication token from .npmrc"
  fi
else
  need_full_auth=false

  # Check if already authenticated
  if npm whoami --registry="${NPM_REGISTRY}" >/dev/null 2>&1; then
    echo "✅ npm registry authentication already active"

    if export_npm_auth; then
      echo "✅ Authentication token found in .npmrc"
    else
      echo "⚠️  Could not extract token from .npmrc, will re-authenticate"
      need_full_auth=true
    fi
  else
    echo "📝 npm registry authentication required"
    need_full_auth=true
  fi

  if [ "${need_full_auth}" = true ]; then
    echo "🔑 Logging into npm registry: ${NPM_REGISTRY}"
    echo "   Auth type: ${NPM_AUTH_TYPE}"
    npm login --registry="${NPM_REGISTRY}" --auth-type="${NPM_AUTH_TYPE}"
    echo "✅ npm login completed"
    echo ""

    if export_npm_auth; then
      echo "✅ Authentication tokens configured"
    else
      echo "⚠️  npm login finished but no token was written to .npmrc"
    fi
  fi
fi

echo ""

################################################################################
# Setup Summary
################################################################################

echo "📊 Setup Summary"
echo ""
echo "  Languages:"
echo "    🟢 Node.js:  $(node --version 2>/dev/null || echo 'not available')"
echo "    💎 Ruby:     $(ruby --version 2>/dev/null | awk '{print $2}' || echo 'not available')"
echo "    🐍 Python:   $(python --version 2>/dev/null | awk '{print $2}' || echo 'not available')"
echo "    🐹 Go:       $(go version 2>/dev/null | awk '{print $3}' | sed 's/go//' || echo 'not available')"
echo "    🦀 Rust:     $(rustc --version 2>/dev/null | awk '{print $2}' || echo 'not available')"
echo "    ☕️ Java:     $(java -version 2>&1 | head -n 1 | cut -d'"' -f2 || echo 'not available')"
echo ""
echo "  Package Managers:"
echo "    📦 npm:      $(npm --version 2>/dev/null || echo 'not available')"
echo "    📦 pnpm:     $(pnpm --version 2>/dev/null || echo 'not available')"
echo "    🧶 yarn:     $(yarn --version 2>/dev/null || echo 'not available')"
echo "    💎 gem:      $(gem --version 2>/dev/null || echo 'not available')"
echo "    📦 bundler:  $(bundle --version 2>/dev/null | awk '{print $3}' || echo 'not available')"
echo "    🐍 pip:      $(pip --version 2>/dev/null | awk '{print $2}' || echo 'not available')"
echo "    🦀 cargo:    $(cargo --version 2>/dev/null | awk '{print $2}' || echo 'not available')"
echo ""
echo "  Tools & SDKs:"
echo "    🛠️ proto:   $(proto --version 2>/dev/null | awk '{print $NF}' || echo 'not available')"
echo "    📱 Xcode:   $(xcodebuild -version 2>/dev/null | head -n 1 | sed 's/Xcode //' || echo 'not available')"
echo "    🤖 Android SDK: $(sdkmanager --version 2>/dev/null | head -n 1 || echo 'not available')"
echo ""

echo "📂 Dotfiles:"
echo "    Your shell configuration (~/.zshrc) is delivered by chezmoi, not by"
echo "    this script. Apply it now:"
echo ""
echo "      chezmoi init git@github.com:jgornick/dotfiles.git   # first machine only"
echo "      chezmoi diff    # review before applying — never blind-apply"
echo "      chezmoi apply"
echo ""

echo "🎉 Setup completed successfully for user: $USERNAME"