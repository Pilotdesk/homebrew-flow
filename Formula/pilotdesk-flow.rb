# Reference copy of Formula/pilotdesk-flow.rb for the Pilotdesk/homebrew-flow
# tap. Not consumed by this repo — copy-paste into the tap when the tap
# repo flips to public and the release pipeline is live.
#
# After publication the release workflow (.github/workflows/release.yml)
# auto-PRs bumps to this file, so manual edits should only be needed for
# structural changes (install steps, service block, caveats).

class PilotdeskFlow < Formula
  desc "Pilotdesk flow CLI for isolated dev environments"
  homepage "https://github.com/Pilotdesk/pilotdesk-flow-cli"
  url      "https://storage.googleapis.com/pilotdesk-flow-releases-swivel-labs/v0.11.0/pilotdesk-flow-v0.11.0.tar.gz"
  sha256   "9352b905d7ed50a9d1e1c9b3a8562af89d3c35539d6fb4aa6fca2bad29afe3f6"
  version  "0.11.0"
  license  "MIT"

  depends_on "caddy"

  def install
    bin.install     "bin/flow"
    # VERSION must land at the install root (== PILOTDESK_FLOW_HOME below) so
    # `flow version` can read it; without it the CLI prints "flow unknown".
    libexec.install "lib", "share", "skills", "VERSION"

    # Expose flow-init.sh at the conventional <prefix>/share path so the
    # shell-rc snippet `source $(brew --prefix pilotdesk-flow)/share/flow-init.sh`
    # resolves without a `libexec/` segment.
    share.mkpath
    share.install_symlink libexec/"share/flow-init.sh" => "flow-init.sh"

    # Pin PILOTDESK_FLOW_HOME to libexec so the auto-detection in bin/flow
    # doesn't walk back to the brew Cellar prefix.
    inreplace bin/"flow" do |s|
      s.gsub! /^PILOTDESK_FLOW_HOME=.*$/, "PILOTDESK_FLOW_HOME=\"#{libexec}\""
    end

    # Pre-create a Caddyfile stub so `brew services start` succeeds
    # before the user has run their first `flow up`.
    state_dir = "#{Dir.home}/.pilotdesk-flow"
    cf        = "#{state_dir}/Caddyfile"
    system "/bin/mkdir", "-p", state_dir
    unless File.exist?(cf)
      File.write(cf, <<~EOS)
        # Auto-generated stub. Replaced on first `flow up`.

        {
            auto_https disable_redirects
            admin 127.0.0.1:2019
        }

        # Dashboard — reachable at https://flow.localtest.me:7443 even
        # before the first `flow up` regenerates this file. :7443 (not :443)
        # because macOS denies non-root binds to <1024.
        https://flow.localtest.me:7443 {
            bind 127.0.0.1
            tls internal
            reverse_proxy 127.0.0.1:7777
        }

        # no flows registered yet
      EOS
    end
  end

  service do
    # One supervised process under launchd: `flow web --with-caddy` runs the
    # dashboard HTTP server AND caddy together, with shared lifecycle. brew
    # formulas only allow one `service` block, so we wrap both children
    # behind a single PID rather than splitting into two formulas.
    run [HOMEBREW_PREFIX/"bin/flow", "web", "--with-caddy", "--port", "7777"]
    keep_alive   true
    # launchd's default PATH omits the Homebrew prefix; without this, the
    # supervisor can't find `caddy` (or `python3` from brew) and crash-loops.
    environment_variables PATH: std_service_path_env
    log_path     var/"log/flow-web.log"
    error_log_path var/"log/flow-web.err.log"
  end

  def post_install
    # `brew upgrade` stops/unloads the launchd job before installing the new
    # version, so by the time post_install runs `brew services list` shows
    # the service as `none` even when the user had it running — the previous
    # gate (`match? /started/`) silently skipped the restart and left users
    # with no dashboard until they noticed and ran `brew services start`.
    #
    # The LaunchAgent plist symlink is a reliable "user opted in" marker:
    # `brew services start` installs it, `brew services stop` removes it,
    # and brew's internal pre-upgrade stop leaves it in place. So restart
    # iff the symlink is present — fresh installs and users who have
    # explicitly stopped the service are unaffected.
    plist = "#{Dir.home}/Library/LaunchAgents/homebrew.mxcl.pilotdesk-flow.plist"
    return unless File.exist?(plist)

    ohai "Restarting pilotdesk-flow service to load the upgraded code"
    system "brew", "services", "restart", "pilotdesk-flow"
  end

  def caveats
    <<~EOS
      Source flow's shell init from your rc to enable `flow cd`, the
      cd-on-`flow up` wrapper, and the per-shell FD limit bump:

          source $(brew --prefix pilotdesk-flow)/share/flow-init.sh

      Then start the user-mode flow service (caddy reverse proxy +
      dashboard, under one PID):

          brew services start pilotdesk-flow

      Open the dashboard:

          https://flow.localtest.me:7443

      (Run `caddy trust` once if you haven't, so the cert is accepted.)

      Optional — wire the bundled /flow agent skill into Claude Code so
      it's auto-discovered:

          flow skill install

      Optional — install the SwiftBar menu-bar dropdown:

          brew install --cask swiftbar      # Homebrew formulas can't
          open -a SwiftBar                  # depend on casks, so this
          flow toolbar install              # is a separate step.

      Verify with:

          flow doctor
    EOS
  end

  test do
    assert_match "Usage: flow", shell_output("#{bin}/flow help")
    # Guards the VERSION-install step above: a missing VERSION file makes
    # `flow version` fall back to "unknown".
    assert_match version.to_s, shell_output("#{bin}/flow version")
  end
end
