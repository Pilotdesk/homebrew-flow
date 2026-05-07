# Homebrew formula for the pilotdesk-flow-cli.
# Source: https://github.com/Pilotdesk/pilotdesk-flow-cli
#
# Both this tap and the source repo are PRIVATE GitHub repos. Installers
# need a GitHub token with `repo` scope:
#
#     export HOMEBREW_GITHUB_API_TOKEN=ghp_…
#
# without it, `brew install` fails with a 404 on the tarball download.

class PilotdeskFlow < Formula
  desc "Pilotdesk flow CLI for isolated dev environments"
  homepage "https://github.com/Pilotdesk/pilotdesk-flow-cli"
  url      "https://github.com/Pilotdesk/pilotdesk-flow-cli/archive/refs/tags/v0.1.0.tar.gz",
           using: GitHubPrivateRepositoryDownloadStrategy
  sha256   "f08d995294f2cfbf01c47f5b8c8f02cbdbc65ff4a492dde47cb4c4411ba64a5c"
  version  "0.1.0"
  license  "MIT"

  depends_on "caddy"

  def install
    bin.install     "bin/flow"
    libexec.install "lib", "share", "env-templates", "skills"

    # Pin PILOTDESK_FLOW_HOME to libexec so the auto-detection in bin/flow
    # doesn't walk back to the brew Cellar prefix.
    inreplace bin/"flow" do |s|
      s.gsub! /^PILOTDESK_FLOW_HOME=.*$/, "PILOTDESK_FLOW_HOME=\"#{libexec}\""
    end

    # Pre-create a Caddyfile stub so `brew services start flow` succeeds
    # before the user has run their first `flow up`.
    state_dir = "#{Dir.home}/.pilotdesk-flow"
    cf        = "#{state_dir}/Caddyfile"
    system "/bin/mkdir", "-p", state_dir
    unless File.exist?(cf)
      File.write(cf, <<~EOS)
        # Auto-generated stub. Replaced on first `flow up`.

        {
            auto_https off
            admin 127.0.0.1:2019
        }

        # no flows registered yet
      EOS
    end
  end

  service do
    run [HOMEBREW_PREFIX/"bin/caddy", "run",
         "--config", "#{Dir.home}/.pilotdesk-flow/Caddyfile",
         "--watch", "--adapter", "caddyfile"]
    keep_alive   true
    log_path     var/"log/flow-caddy.log"
    error_log_path var/"log/flow-caddy.err.log"
  end

  def caveats
    <<~EOS
      Source flow's shell init from your rc to enable `flow cd` and bump
      the per-shell FD limit:

          source #{libexec}/share/flow-init.sh

      Then start the user-mode Caddy service:

          brew services start flow

      Verify with:

          flow doctor
    EOS
  end

  test do
    assert_match "Usage: flow", shell_output("#{bin}/flow help")
  end
end
