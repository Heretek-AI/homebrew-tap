class GdevelopUnlocked < Formula
  desc "Unlocked desktop IDE for GDevelop 5 with BYOK local AI studio"
  homepage "https://github.com/Heretek-AI/GDevelop-Unlocked"
  version "5.6.283"
  license "MIT"

  on_linux do
    on_intel do
      url "https://github.com/Heretek-AI/GDevelop-Unlocked/releases/download/unlocked-8301cdcaa48b496f48a28a6e3a56fa833eaeddff/gdevelop-5.6.283.zip"
      sha256 "7a961d66b5256d00b41a7aad61165d7433003de27b39f10593a76fbe6927991e"
    end

    on_arm do
      url "https://github.com/Heretek-AI/GDevelop-Unlocked/releases/download/unlocked-8301cdcaa48b496f48a28a6e3a56fa833eaeddff/gdevelop-unlocked-linux-arm64-8301cdcaa48b496f48a28a6e3a56fa833eaeddff.zip"
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    end
  end

  depends_on "alsa-lib"
  depends_on "gtk+3"
  depends_on "libxscrnsaver"
  depends_on "nss"
  depends_on "bubblewrap" => :recommended

  def install
    # Install unpacked payload into libexec
    libexec.install Dir["*"]

    # Wrapper script handling Linux desktop environment (Wayland/X11) and sandboxing
    (bin/"gdevelop-unlocked").write <<~EOS
      #!/usr/bin/env bash
      set -eo pipefail

      APP_DIR="#{libexec}"
      BIN_NAME="$(find "${APP_DIR}" -maxdepth 2 -type f -name 'gdevelop*' | head -n 1)"
      if [[ -z "${BIN_NAME}" || ! -x "${BIN_NAME}" ]]; then
        echo "Error: GDevelop binary not found in #{libexec}" >&2
        exit 1
      fi

      # Runtime flags for desktop rendering and Wayland/X11 auto-detection
      EXTRA_FLAGS=()
      if [[ -n "${WAYLAND_DISPLAY}" ]]; then
        EXTRA_FLAGS+=("--ozone-platform-hint=auto" "--enable-features=WaylandWindowDecorations")
      fi

      # Sandboxing detection: check unprivileged user namespaces
      CLONE_NEWUSER="/proc/sys/kernel/unprivileged_userns_clone"
      if [[ -f "${CLONE_NEWUSER}" && "$(cat "${CLONE_NEWUSER}" 2>/dev/null)" == "0" ]]; then
        if command -v bwrap >/dev/null 2>&1; then
          # Bubblewrap wrapper for systems without unprivileged userns
          exec bwrap --dev-bind / / --setenv GDEVELOP_SANDBOX bwrap "${BIN_NAME}" "${EXTRA_FLAGS[@]}" "$@"
        else
          echo "Warning: unprivileged user namespaces disabled and bubblewrap missing. Running with --no-sandbox." >&2
          EXTRA_FLAGS+=("--no-sandbox")
        fi
      fi

      exec "${BIN_NAME}" "${EXTRA_FLAGS[@]}" "$@"
    EOS
    chmod 0755, bin/"gdevelop-unlocked"

    # Install desktop entry and icons if present
    desktop_file = libexec/"gdevelop.desktop"
    if File.exist?(desktop_file)
      (share/"applications").install desktop_file => "gdevelop-unlocked.desktop"
    else
      (share/"applications"/"gdevelop-unlocked.desktop").write <<~EOS
        [Desktop Entry]
        Name=GDevelop Unlocked
        Comment=Unlocked 2D/3D Game Engine with BYOK Local AI Studio
        Exec=#{bin}/gdevelop-unlocked %U
        Terminal=false
        Type=Application
        Icon=gdevelop-unlocked
        Categories=Development;IDE;
        MimeType=application/x-gdevelop;
      EOS
    end

    # Install icon
    icon_file = Dir[libexec/"*icon*.png"].first
    if icon_file && File.exist?(icon_file)
      (share/"icons/hicolor/512x512/apps").install icon_file => "gdevelop-unlocked.png"
    end
  end

  def caveats
    <<~EOS
      GDevelop-Unlocked has been installed to #{bin}/gdevelop-unlocked.

      Desktop Environment Notes:
        - Wayland: Auto-detected via --ozone-platform-hint=auto.
        - Sandboxing: If your kernel restricts unprivileged user namespaces
          (e.g., Debian/Ubuntu sysctl kernel.unprivileged_userns_clone=0),
          install 'bubblewrap' for hardened execution or run with --no-sandbox.
        - Local AI: Set up local inference via Preferences -> AI Settings.
    EOS
  end

  test do
    assert_predicate bin/"gdevelop-unlocked", :exist?
    assert_predicate bin/"gdevelop-unlocked", :executable?
  end
end
