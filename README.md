# homebrew-flow

Private Homebrew tap for [`pilotdesk-flow-cli`](https://github.com/Pilotdesk/pilotdesk-flow-cli).

## Install

```bash
# Both this tap and the source repo are private. Make sure your GitHub
# token has `repo` scope, then export it for Homebrew:
export HOMEBREW_GITHUB_API_TOKEN=ghp_…

brew tap pilotdesk/flow git@github.com:Pilotdesk/homebrew-flow.git
brew install pilotdesk-flow
brew services start pilotdesk-flow
echo 'source $(brew --prefix pilotdesk-flow)/share/flow-init.sh' >> ~/.zshrc
exec zsh

flow doctor
```

## Updating the formula

When `Pilotdesk/pilotdesk-flow-cli` cuts a new tag (e.g. `v0.2.0`):

```bash
TAG=v0.2.0
URL="https://github.com/Pilotdesk/pilotdesk-flow-cli/archive/refs/tags/${TAG}.tar.gz"
TOKEN=$(gh auth token)
SHA=$(curl -sL -H "Authorization: token $TOKEN" "$URL" | shasum -a 256 | awk '{print $1}')
echo "$TAG → $SHA"
```

Update `Formula/flow.rb`'s `url`, `version`, and `sha256` lines and commit.
