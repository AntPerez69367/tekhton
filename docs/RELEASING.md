# Releasing Tekhton

This document covers the release process for Tekhton maintainers.

## Prerequisites (one-time setup)

### 1. Create the Homebrew tap repository

Create `geoffgodwin/homebrew-tekhton` on GitHub with:

- `Formula/tekhton.rb` - initial formula (see template below)
- `README.md` - brief description with install command

### 2. Initial formula template

Create `Formula/tekhton.rb` in the tap repo:

```ruby
class Tekhton < Formula
  desc "Multi-agent development pipeline built on Claude CLI"
  homepage "https://github.com/geoffgodwin/tekhton"
  url "https://github.com/geoffgodwin/tekhton/archive/refs/tags/vX.Y.Z.tar.gz"
  sha256 "PLACEHOLDER"
  license "MIT"

  depends_on "bash"
  depends_on "jq"
  depends_on "python@3.12"

  def install
    libexec.install Dir["*"]
    bin.install_symlink libexec/"tekhton.sh" => "tekhton"
  end

  test do
    assert_match "Tekhton", shell_output("#{bin}/tekhton --version")
  end
end
```

Compute the initial sha256:

```bash
curl -sL https://github.com/geoffgodwin/tekhton/archive/refs/tags/vX.Y.Z.tar.gz | shasum -a 256
```

### 3. Configure the `HOMEBREW_TAP_PAT` secret

In the main Tekhton repo (not the tap), add a repository secret:

- Name: `HOMEBREW_TAP_PAT`
- Value: A fine-grained Personal Access Token with `contents: write`
  permission on `geoffgodwin/homebrew-tekhton` only

Fine-grained tokens are strongly preferred over classic tokens for
minimal privilege scope.

## Two-step release flow

`VERSION` is the single source of truth for release versioning.

### Step 1: Prepare release (before merge)

Run:

```bash
tools/release.sh prepare
```

What this does:

- Reads `VERSION` and enforces it as the release tag source (`vX.Y.Z`)
- Syncs the README hero version line from `VERSION`
- Verifies whether `tools/release_notes/vX.Y.Z.md` exists
- Prints a merge checklist and blocks until release notes exist

If notes are missing, create:

- `tools/release_notes/vX.Y.Z.md`

Then commit prepare output changes (for example, README version sync and release notes) and merge.

### Step 2: Post-merge release publish

After merge to `main`, run:

```bash
tools/release.sh post-merge
```

What this does:

- Re-reads `VERSION` and derives tag `vX.Y.Z`
- Validates tag uniqueness (local and remote)
- Creates and pushes annotated tag
- Creates GitHub Release using `tools/release_notes/vX.Y.Z.md` when `gh` is available

## Legacy one-shot mode

The old form still works for compatibility:

```bash
tools/release.sh vX.Y.Z
```

It is equivalent to:

```bash
tools/release.sh post-merge vX.Y.Z
```

## Self-hosting docs drift guard

For Tekhton dogfooding runs, make sure docs stage is enabled in `.claude/pipeline.conf`:

```bash
DOCS_AGENT_ENABLED=true
```

Without that, docs maintenance is skipped during normal milestone/task runs.

## Troubleshooting

### `brew install` fails after a successful release

GitHub occasionally regenerates release tarballs (for example, after tag
re-signing), which changes the sha256 and breaks the formula. The
smoke-test job in `brew-bump.yml` catches this at tag-push time, but
if the tarball is regenerated later:

1. Download the current tarball and compute its sha256:

```bash
curl -sL https://github.com/geoffgodwin/tekhton/archive/refs/tags/vX.Y.Z.tar.gz | shasum -a 256
```

2. Update `Formula/tekhton.rb` in the tap repo with the new hash
3. Commit and push to `geoffgodwin/homebrew-tekhton`

### Rolling back a bad formula

Revert the last commit in the tap repo:

```bash
cd homebrew-tekhton
git revert HEAD
git push
```

### `HOMEBREW_TAP_PAT` expired or revoked

The brew-bump workflow will fail silently on the "Clone tap repo" step.
Regenerate the token and update the repository secret.
