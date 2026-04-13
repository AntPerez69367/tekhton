# Releasing Tekhton

This document covers the release process for Tekhton maintainers.

## Prerequisites (one-time setup)

### 1. Create the Homebrew tap repository

Create `geoffgodwin/homebrew-tekhton` on GitHub with:

- `Formula/tekhton.rb` — initial formula (see template below)
- `README.md` — brief description with install command

### 2. Initial formula template

Create `Formula/tekhton.rb` in the tap repo:

```ruby
class Tekhton < Formula
  desc "Multi-agent development pipeline built on Claude CLI"
  homepage "https://github.com/geoffgodwin/tekhton"
  url "https://github.com/geoffgodwin/tekhton/archive/refs/tags/v3.78.0.tar.gz"
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
curl -sL https://github.com/geoffgodwin/tekhton/archive/refs/tags/v3.78.0.tar.gz | shasum -a 256
```

### 3. Configure the `HOMEBREW_TAP_PAT` secret

In the **main tekhton repo** (not the tap), add a repository secret:

- **Name:** `HOMEBREW_TAP_PAT`
- **Value:** A fine-grained Personal Access Token with `contents: write`
  permission on `geoffgodwin/homebrew-tekhton` only

Fine-grained tokens are strongly preferred over classic tokens for
minimal privilege scope.

## Cutting a release

1. Bump `TEKHTON_VERSION` in `tekhton.sh`:

   ```bash
   # Example: completing milestone 78
   sed -i 's/TEKHTON_VERSION=".*"/TEKHTON_VERSION="3.78.0"/' tekhton.sh
   ```

2. Commit and tag:

   ```bash
   git add tekhton.sh
   git commit -m "chore: bump version to 3.78.0"
   git tag v3.78.0
   git push origin main --tags
   ```

3. **What happens automatically:**
   - The **release workflow** (`.github/workflows/release.yml`) creates a
     GitHub Release with a tarball and SHA256SUMS
   - The **brew-bump workflow** (`.github/workflows/brew-bump.yml`)
     computes the tarball sha256, updates `Formula/tekhton.rb` in the
     tap repo, and pushes the change
   - A **smoke-test job** runs `brew install tekhton` (short form, after
     `brew tap geoffgodwin/tekhton`) on a macOS runner and verifies
     `tekhton --version` matches the tag

## Troubleshooting

### `brew install` fails after a successful release

GitHub occasionally regenerates release tarballs (e.g., after tag
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
