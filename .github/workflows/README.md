# GitHub Actions Workflows

This repository uses GitHub Actions for automated testing and publishing to Hex.pm with reusable composite actions and the cucumber/action-publish-hex action.

## Workflows

### 1. Test Workflow (`test.yml`)

**Triggers:**
- Push to `develop` branch
- Pull requests targeting `develop` branch

**Actions:**
- Uses reusable `setup-elixir` action
- Uses reusable `test-elixir` action with formatting checks and test execution

### 2. Release Workflow (`release.yml`)

**Triggers:**
- Push of tags matching the pattern `x.x.x` (e.g., `1.0.0`, `2.1.3`)

**Actions:**
- **Test Job**: Uses reusable actions for setup and testing
- **Publish Job**: Runs only after tests pass
  - Uses `erlef/setup-beam` action for Elixir setup
  - Uses `cucumber/action-publish-hex@v1.0.0` for publishing to Hex.pm
  - Runs in a `Release` environment for additional security

### 3. Validate Release Workflow (`validate-release.yml`)

**Triggers:**
- Manual workflow dispatch with version input

**Actions:**
- Validates version consistency between `mix.exs` and input
- Runs full test suite
- Performs dry-run publication to validate package
- Checks changelog for version entry

## Reusable Actions

### Setup Elixir (`setup-elixir`)

**Location:** `.github/actions/setup-elixir/action.yml`

**Inputs:**
- `elixir-version` (default: '1.18.1')
- `otp-version` (default: '27.2')
- `cache-key-suffix` (optional): Additional cache key suffix

**Features:**
- Sets up Elixir and OTP versions
- Caches dependencies and build artifacts
- Installs dependencies with `mix deps.get`

### Test Elixir (`test-elixir`)

**Location:** `.github/actions/test-elixir/action.yml`

**Inputs:**
- `check-format` (default: 'true'): Whether to check code formatting
- `run-tests` (default: 'true'): Whether to run the test suite
- `test-args` (optional): Additional arguments for `mix test`

**Features:**
- Compiles with warnings as errors
- Checks code formatting with `mix format --check-formatted`
- Runs test suite with optional custom arguments

### Cucumber Publish Hex Action

**External Action:** `cucumber/action-publish-hex@v1.0.0`

**Inputs:**
- `hex-api-key` (required): Hex API key for authentication

**Features:**
- Handles all aspects of Hex.pm publishing
- Automatically installs dependencies
- Compiles for production
- Publishes package to Hex.pm
- Documentation is automatically generated and published
- Well-maintained third-party action

## Setup Requirements

### 1. GitHub Environment Setup

The release workflow uses a `Release` environment for additional security. You need to:

1. Create a `Release` environment in your GitHub repository:
   - Go to your repository on GitHub
   - Navigate to Settings → Environments
   - Click "New environment"
   - Name it "Release"
   - Optionally add protection rules (e.g., required reviewers)

### 2. Hex API Key

To enable automatic publishing to Hex.pm, you need to set up a `HEX_API_KEY` secret:

1. Generate a Hex API key:
   ```bash
   mix hex.user key generate
   ```

2. Add the key to your GitHub environment secrets:
   - Go to your repository on GitHub
   - Navigate to Settings → Environments → Release
   - Click "Add secret"
   - Name: `HEX_API_KEY`
   - Value: Your generated Hex API key

   Alternatively, you can add it as a repository secret:
   - Navigate to Settings → Secrets and variables → Actions
   - Click "New repository secret"
   - Name: `HEX_API_KEY`
   - Value: Your generated Hex API key

### 3. Version Management

Before creating a release tag, make sure to:

1. Update the version in `mix.exs`:
   ```elixir
   def project do
     [
       version: "1.0.0",  # Update this
       # ... other config
     ]
   end
   ```

2. Update the `CHANGELOG.md` file with release notes

3. Commit your changes:
   ```bash
   git add mix.exs CHANGELOG.md
   git commit -m "Bump version to 1.0.0"
   ```

4. Create and push the tag:
   ```bash
   git tag 1.0.0
   git push origin 1.0.0
   ```

## Release Process

### Standard Release

1. **Development**: Work on features and push to `develop` branch
   - Tests run automatically on every push

2. **Release Preparation**: 
   - Update version in `mix.exs`
   - Update `CHANGELOG.md`
   - Commit changes to `main` branch

3. **Validation** (Optional):
   - Go to Actions → "Validate Release"
   - Click "Run workflow"
   - Enter the version number
   - Choose dry-run option (performs `mix hex.publish --dry-run`)
   - Review validation results

4. **Release**: Create and push a version tag
   - Tests run automatically
   - If tests pass, the Release environment is activated
   - Package is automatically published to Hex.pm using cucumber/action-publish-hex

### Manual Validation

You can validate a release before tagging using the validation workflow:

1. Navigate to the Actions tab in your GitHub repository
2. Select "Validate Release" workflow
3. Click "Run workflow"
4. Enter the version you want to validate (e.g., "1.0.0")
5. Choose whether to perform a dry-run (recommended)
6. Click "Run workflow"

This will:
- Run all tests
- Validate version consistency
- Perform a dry-run publish to check package validity
- Check if the version exists in CHANGELOG.md

## Customization

### Using Different Elixir Versions

Update the matrix in your workflows:

```yaml
strategy:
  matrix:
    elixir: ['1.17.0', '1.18.1']
    otp: ['26.0', '27.2']
```

### Custom Test Arguments

Use the `test-args` input in the test action:

```yaml
- name: Test Elixir
  uses: ./.github/actions/test-elixir
  with:
    test-args: "--cover --warnings-as-errors"
```

### Skip Formatting Checks

Disable formatting checks if needed:

```yaml
- name: Test Elixir
  uses: ./.github/actions/test-elixir
  with:
    check-format: "false"
```

## Monitoring

You can monitor the status of workflows in the "Actions" tab of your GitHub repository. Failed workflows will send notifications based on your GitHub notification settings.

## Troubleshooting

### Common Issues

1. **Hex publish fails**: 
   - Check that your `HEX_API_KEY` secret is correctly set in the Release environment
   - Ensure the Release environment is properly configured
   - Verify you have push access to the Hex package
2. **Tests fail**: Ensure all tests pass locally before tagging a release
3. **Format check fails**: Run `mix format` locally and commit the changes
4. **Version mismatch**: Ensure the version in `mix.exs` matches your tag
5. **Environment access denied**: Check Release environment protection rules
6. **Cache issues**: Actions include cache keys with version suffixes to avoid conflicts

### Manual Release

If you need to publish manually:

```bash
# Ensure you're authenticated with Hex
mix hex.user auth

# Perform a dry run first
mix hex.publish --dry-run

# Publish the package
mix hex.publish

```

### Debugging Reusable Actions

To debug issues with reusable actions:

1. Check the action logs in the GitHub Actions UI
2. Verify input parameters are correctly passed
3. Test the action steps locally
4. Check for any changes in dependencies or Elixir versions

**Note:** `mix hex.publish` automatically generates and publishes documentation to HexDocs when you have `ex_doc` configured in your `mix.exs` dependencies. No separate documentation publishing step is needed.

## Benefits of This Setup

- **DRY Principle**: Avoid code duplication with reusable actions
- **Consistency**: Ensure same steps are executed identically
- **Maintainability**: Update logic in one place for custom actions
- **Security**: Release environment provides additional protection
- **Reliability**: cucumber/action-publish-hex is a well-maintained third-party action
- **Simplicity**: Less custom code to maintain for publishing
- **Testing**: Easier to test and validate individual components