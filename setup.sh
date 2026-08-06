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
XCODE_VERSION=26.5

# The default iPhone simulator version to set up
IPHONE_VERSION=16

# The default iOS versions to install via xcodes runtimes
XCODE_IOS_VERSION=26.5
IOS_VERSION=26.5

# Define Android SDK version
ANDROID_API_LEVEL=36
ANDROID_BUILD_TOOLS_VERSION="36.0.0"

# The default Android device to create for emulator
ANDROID_DEVICE_NAME="pixel_10"
# We prefix with "--" because the React Native CLI chooses the first AVD in the
# list.
ANDROID_AVD_NAME="--${ANDROID_DEVICE_NAME}_api_${ANDROID_API_LEVEL}"

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

# npm login auth type: "legacy" (prompts for username/password/token, works with
# any registry) or "web" (browser-based SSO, supported by npmjs.com and some
# private registries with SSO configured)
NPM_AUTH_TYPE=legacy

# There are reported issues when using $TMPDIR after macOS upgrades and using
# the following configuration variable seems to be more safe.
TMPDIR=$(getconf DARWIN_USER_TEMP_DIR)

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

# Conflicting formulae that should be unlinked before installing proto
node_conflicts=("node" "node@16" "node@18" "node@20" "node@22" "node@24")
python_conflicts=("python" "python@3.8" "python@3.9" "python@3.10" "python@3.11" "python@3.12" "python@3.13" "python@3.14")
ruby_conflicts=("ruby" "ruby@3.0" "ruby@3.1" "ruby@3.2" "ruby@3.3" "ruby@3.4")
go_conflicts=("go")
rust_conflicts=("rust")

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

brew bundle install --no-upgrade --file="${brewfile_path}"

# Clean up temp Brewfile if we downloaded it
if [ "${brewfile_path}" != "${local_brewfile}" ]; then
  rm -f "${brewfile_path}"
fi
echo "✅ Homebrew dependencies installation completed"
echo ""

echo "🔓 Checking for conflicting packages that need to be unlinked..."

# Unlink conflicting Node packages
for package in "${node_conflicts[@]}"; do
  if brew list --formula "$package" >/dev/null 2>&1; then
    echo "🔗 Unlinking conflicting package: $package"
    brew unlink "$package" 2>/dev/null || true
  fi
done

# Unlink conflicting Python packages
for package in "${python_conflicts[@]}"; do
  if brew list --formula "$package" >/dev/null 2>&1; then
    echo "🔗 Unlinking conflicting package: $package"
    brew unlink "$package" 2>/dev/null || true
  fi
done

# Unlink conflicting Ruby packages
for package in "${ruby_conflicts[@]}"; do
  if brew list --formula "$package" >/dev/null 2>&1; then
    echo "🔗 Unlinking conflicting package: $package"
    brew unlink "$package" 2>/dev/null || true
  fi
done

# Unlink conflicting Go packages
for package in "${go_conflicts[@]}"; do
  if brew list --formula "$package" >/dev/null 2>&1; then
    echo "🔗 Unlinking conflicting package: $package"
    brew unlink "$package" 2>/dev/null || true
  fi
done

# Unlink conflicting Rust packages
for package in "${rust_conflicts[@]}"; do
  if brew list --formula "$package" >/dev/null 2>&1; then
    echo "🔗 Unlinking conflicting package: $package"
    brew unlink "$package" 2>/dev/null || true
  fi
done

echo "✅ Conflicting packages check completed"
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
echo "✅ Xcode ${XCODE_VERSION} is now selected"

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
proto pin node "${NODE_VERSION}" --global
echo "✅ Node.js ${NODE_VERSION} is now active"
echo ""

echo "💎 Setting up Ruby ${RUBY_VERSION}..."
proto install ruby "${RUBY_VERSION}"
proto pin ruby "${RUBY_VERSION}" --global
echo "✅ Ruby ${RUBY_VERSION} is now active"

if ! gem list -i bundler >/dev/null 2>&1; then
  echo "📦 Installing bundler gem..."
  gem install bundler
  echo "✅ bundler installation completed"
else
  echo "✅ bundler is already installed"
fi
echo ""

echo "🐍 Setting up Python ${PYTHON_VERSION}..."
proto install python "${PYTHON_VERSION}"
proto pin python "${PYTHON_VERSION}" --global
echo "✅ Python ${PYTHON_VERSION} is now active"
echo ""

echo "🐹 Setting up Go ${GO_VERSION}..."
proto install go "${GO_VERSION}"
proto pin go "${GO_VERSION}" --global
echo "✅ Go ${GO_VERSION} is now active"
echo ""

echo "🦀 Setting up Rust ${RUST_VERSION}..."
proto install rust "${RUST_VERSION}"
proto pin rust "${RUST_VERSION}" --global
echo "✅ Rust ${RUST_VERSION} is now active"
echo ""

echo "☕️ Setting up Java ${JAVA_VERSION}..."
proto install java "${JAVA_VERSION}"
proto pin java "${JAVA_VERSION}" --global
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

echo "📱 Setting up iOS ${XCODE_IOS_VERSION} simulator runtime (required for Xcode ${XCODE_VERSION})..."
xcode_ios_name="iOS ${XCODE_IOS_VERSION}"
if [ "$(xcodes runtimes | grep "${xcode_ios_name} (Installed)" | wc -l)" -eq 0 ]; then
  echo "📥 Installing iOS ${XCODE_IOS_VERSION} runtime... (this may take a while)"
  echo ""
  xcodes runtimes install "${xcode_ios_name}"
  echo "✅ iOS ${XCODE_IOS_VERSION} runtime installation completed"
else
  echo "✅ iOS ${XCODE_IOS_VERSION} runtime is already installed"
fi
echo ""

echo "📱 Setting up iOS ${IOS_VERSION} simulator runtime..."
ios_name="iOS ${IOS_VERSION}"
if [ "$(xcodes runtimes | grep "${ios_name} (Installed)" | wc -l)" -eq 0 ]; then
  echo "📥 Installing iOS ${IOS_VERSION} runtime... (this may take a while)"
  echo ""
  xcodes runtimes install "${ios_name}"
  echo "✅ iOS ${IOS_VERSION} runtime installation completed"
else
  echo "✅ iOS ${IOS_VERSION} runtime is already installed"
fi
echo ""

echo "📱 Setting up iPhone ${IPHONE_VERSION} simulator device..."
simulator_iphone_name="iPhone ${IPHONE_VERSION}"
simulator_name="${simulator_iphone_name} - ${ios_name}"
if [ "$(xcrun simctl list devices | grep "${simulator_name}" | wc -l)" -eq 0 ]; then
  echo "📱 Creating simulator: ${simulator_name}"
  xcrun simctl create "${simulator_name}" "${simulator_iphone_name}" "iOS ${IOS_VERSION}"
  echo "✅ iPhone ${IPHONE_VERSION} simulator creation completed"
else
  echo "✅ iPhone ${IPHONE_VERSION} simulator already exists"
fi
echo ""

################################################################################
# Android SDK Setup
################################################################################

echo "🤖 Setting up Android SDK..."
export ANDROID_HOME="${HOME}/Library/Android/sdk"
export ANDROID_SDK_ROOT="${ANDROID_HOME}"

# Check if Android SDK command-line tools are available (specifically the 'latest' layout
# that sdkmanager expects — Android Studio may install a versioned dir instead)
if [ ! -f "${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager" ]; then
  echo "📥 Android SDK command-line tools not found. Setting up..."

  # Create Android SDK directory structure
  mkdir -p "${ANDROID_HOME}/cmdline-tools"

  echo "📦 Downloading Android SDK command-line tools..."
  cmdline_tools_url="https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip"
  temp_zip=$(mktemp "${TMPDIR:-/tmp}/cmdline-tools.XXXXXX.zip")

  curl -L -o "${temp_zip}" "${cmdline_tools_url}"

  echo "📦 Extracting command-line tools..."
  unzip -q "${temp_zip}" -d "${ANDROID_HOME}/cmdline-tools"
  mv "${ANDROID_HOME}/cmdline-tools/cmdline-tools" "${ANDROID_HOME}/cmdline-tools/latest"
  rm -f "${temp_zip}"

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

need_full_auth=false

# Check if already authenticated
if npm whoami --registry="${NPM_REGISTRY}" >/dev/null 2>&1; then
  echo "✅ npm registry authentication already active"

  NODE_AUTH_TOKEN=$(get_node_auth_token)

  if [ -n "${NODE_AUTH_TOKEN}" ]; then
    echo "✅ Authentication token found in .npmrc"
    export NODE_AUTH_TOKEN
    export YARN_NPM_AUTH_IDENT="${NODE_AUTH_TOKEN}"
    export npm_config__auth="${NODE_AUTH_TOKEN}"
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

  export NODE_AUTH_TOKEN="$(get_node_auth_token)"
  export YARN_NPM_AUTH_IDENT="${NODE_AUTH_TOKEN}"
  export npm_config__auth="${NODE_AUTH_TOKEN}"
  echo "✅ Authentication tokens configured"
fi

echo ""

################################################################################
# Shell Configuration Generation
################################################################################

echo "📋 Generating shell configuration and copying to clipboard..."
shell_config=$(cat << EOF
# *******************************************************************************
# Development Environment Configuration
# *******************************************************************************
# Copy and paste this entire block into your ~/.(bash|zsh)rc file.
# If you need to update it later, simply replace the entire block with a new one.
# *******************************************************************************

# Initialize (home)brew
if [ -z \${HOMEBREW_PREFIX+x} ]; then
  export HOMEBREW_PREFIX=\$([[ -d "/opt/homebrew" ]] && echo "/opt/homebrew" || echo "/usr/local")
  eval "\$(\${HOMEBREW_PREFIX}/bin/brew shellenv)"
fi

#
# Set Development Tooling Environment Variables
#

# proto — language runtime manager (node, ruby, python, go, rust, java, etc.)
export PROTO_HOME="\${HOME}/.proto"
export PATH="\${PROTO_HOME}/shims:\${PROTO_HOME}/bin:\${PATH}"

export NODE_OPTIONS="\${NODE_OPTIONS} --max_old_space_size=4096"

# npm auth token (populated by npm login, read from ~/.npmrc)
export NODE_AUTH_TOKEN="\$(cat \${HOME}/.npmrc 2>/dev/null | grep -o '_authToken=.*' -m 1 | sed 's/_authToken=//g')"
export YARN_NPM_AUTH_IDENT="\${NODE_AUTH_TOKEN}"
export npm_config__auth="\${NODE_AUTH_TOKEN}"

# Android paths
export ANDROID_HOME="\${ANDROID_HOME:-"\${HOME}/Library/Android/sdk"}"
export ANDROID_SDK_ROOT="\${ANDROID_HOME}"
export PATH="\${ANDROID_HOME}/platform-tools/:\${PATH}"
export PATH="\${ANDROID_HOME}/cmdline-tools/latest/bin/:\${PATH}"
export PATH="\${ANDROID_HOME}/emulator:\${PATH}"

# Gradle
export GRADLE_USER_HOME="\${GRADLE_USER_HOME:-"\${HOME}/.gradle"}"

# Set the default iOS simulator name
export IOS_SIMULATOR_NAME="${simulator_name}"

# Set the default Android emulator name
export ANDROID_AVD_NAME="${ANDROID_AVD_NAME}"

# *******************************************************************************
# END OF Development Environment Configuration
# *******************************************************************************
# Remember: To update this configuration in the future, simply replace this
# entire block (from the top comment to this bottom comment) with the new one.
# *******************************************************************************
EOF
)
echo ""

echo "$shell_config"
echo "$shell_config" | pbcopy
echo "✅ Configuration copied to clipboard!"

# Detect user's shell and open the appropriate RC file in VS Code
shell_rc="${HOME}/.$(basename "$SHELL")rc"

# Open the RC file in VS Code
if command -v code >/dev/null 2>&1; then
  echo "📂 Ready to open $shell_rc in VS Code"
  echo ""
  read -p "Press Enter to open the file in VS Code to paste the configuration..."
  code "$shell_rc"
  echo "✅ Opened $shell_rc in VS Code"
else
  echo "📝 Please paste the configuration into your $shell_rc file"
fi

echo ""
read -p "Press Enter after you've pasted the configuration into your $shell_rc file..."
echo "✅ Configuration setup completed"
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
echo "    🤖 Android Studio: $(/Applications/Android\ Studio.app/Contents/MacOS/studio --version 2>/dev/null | head -n 1 | sed 's/.*| //' || echo 'not available')"
echo ""

echo "📂 Dotfiles:"
echo "    If chezmoi is not initialized yet, run:"
echo "      chezmoi init git@github.com:jgornick/dotfiles.git"
echo "      chezmoi diff    # review before applying"
echo "      chezmoi apply"
echo ""

echo "🎉 Setup completed successfully for user: $USERNAME"