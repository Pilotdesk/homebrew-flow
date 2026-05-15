# Homebrew formula for the pilotdesk-flow-cli.
# Source: https://github.com/Pilotdesk/pilotdesk-flow-cli
#
# Both this tap and the source repo are PRIVATE GitHub repos. Installers
# need a GitHub token with `repo` scope, exported as HOMEBREW_GITHUB_API_TOKEN:
#
#     export HOMEBREW_GITHUB_API_TOKEN=$(gh auth token)
#
# Without it, the inline GitHubPrivateRepositoryDownloadStrategy below
# raises a clear error rather than letting the unauth'd curl 404.

require "download_strategy"

class GitHubPrivateRepositoryDownloadStrategy < CurlDownloadStrategy
  def initialize(url, name, version, **meta)
    super
    parse_url_pattern
    set_github_token
  end

  def parse_url_pattern
    pattern = %r{https://github\.com/([^/]+)/([^/]+)/(\S+)}
    unless @url =~ pattern
      raise CurlDownloadStrategyError, "Invalid GitHub URL: #{@url}"
    end
    _, @owner, @repo, @filepath = *@url.match(pattern)
  end

  def set_github_token
    @github_token = ENV["HOMEBREW_GITHUB_API_TOKEN"]
    return if @github_token

    raise CurlDownloadStrategyError, <<~MSG
      HOMEBREW_GITHUB_API_TOKEN is required to install from a private repo.
      Run:
          export HOMEBREW_GITHUB_API_TOKEN=$(gh auth token)
      then retry brew install.
    MSG
  end

  # Embed the token in the URL so curl auths during the redirect chain.
  def download_url
    "https://#{@github_token}@github.com/#{@owner}/#{@repo}/#{@filepath}"
  end

  private

  def _fetch(url:, resolved_url:, timeout:)
    curl_download download_url, to: temporary_path, timeout: timeout
  end
end

class PilotdeskFlow < Formula
  desc "Pilotdesk flow CLI for isolated dev environments"
  homepage "https://github.com/Pilotdesk/pilotdesk-flow-cli"
  url      "https://github.com/Pilotdesk/pilotdesk-flow-cli/archive/refs/tags/v0.3.0.tar.gz",
           using: GitHubPrivateRepositoryDownloadStrategy
  sha256   "e68cdf1a6bd4e4a3f39d432eb73e310a8ba1e642266468a0de14ffc11c26d27c"
  version  "0.3.0"
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
      Source flow's shell init from your rc to enable `flow cd`, the
      cd-on-`flow up` wrapper, and the per-shell FD limit bump:

          source $(brew --prefix pilotdesk-flow)/share/flow-init.sh

      Then start the user-mode Caddy service:

          brew services start pilotdesk-flow

      Optional — wire the bundled /flow agent skill into Claude Code so
      it's auto-discovered:

          flow skill install

      Verify with:

          flow doctor
    EOS
  end

  test do
    assert_match "Usage: flow", shell_output("#{bin}/flow help")
  end
end
