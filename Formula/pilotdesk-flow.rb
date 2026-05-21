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
  url      "https://storage.googleapis.com/pilotdesk-flow-releases-swivel-labs/v0.8.0/pilotdesk-flow-v0.8.0.tar.gz"
  sha256   "e8ee3bbd693842073ce87684f599e7037b2faac680db89540a40e3c9fa0152e7"
  version  "0.8.0"
  license  "MIT"

  depends_on "caddy"

  def install
    bin.install     "bin/flow"
    libexec.install "lib", "share", "skills"

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
  end
end
