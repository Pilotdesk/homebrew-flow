# homebrew-flow

Public Homebrew tap for [`pilotdesk-flow-cli`](https://github.com/Pilotdesk/pilotdesk-flow-cli).

The flow source repo stays private; releases are published as source
tarballs to a public-read GCS bucket. The formula in this tap pins each
release's sha256, so Homebrew refuses tampered tarballs.

## Install

```bash
brew tap pilotdesk/flow
brew install pilotdesk-flow
brew services start pilotdesk-flow
echo 'source $(brew --prefix pilotdesk-flow)/share/flow-init.sh' >> ~/.zshrc
exec zsh

flow doctor
```

No GitHub token, no SSH key — `brew tap` reads this public repo, and
`brew install` downloads the tarball directly from
`storage.googleapis.com`.

## How releases land here

`Pilotdesk/pilotdesk-flow-cli`'s release workflow does the publishing:

1. Engineer bumps `VERSION` in the source repo and merges to `main`.
2. CI tags `v<version>`, builds the source tarball, uploads it to
   `gs://pilotdesk-flow-releases-swivel-labs/v<version>/`.
3. CI opens a PR against this repo bumping `Formula/pilotdesk-flow.rb`'s
   `url`, `sha256`, and `version`.
4. A human reviews the PR and merges. That review is the supply-chain
   checkpoint — never auto-merge.

## Branch protection

`main` requires PR + 1 review + signed commits. No direct pushes, even
by admins. Formula bumps are the highest-value attack vector — keep
this tight.
