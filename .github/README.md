# GitHub Actions Setup

This directory contains the GitHub Actions workflow for automated testing and deployment.

## Workflow: Test and Deploy to Staging

The workflow in `.github/workflows/test-and-deploy.yml` performs the following:

1. **Triggers**: Runs on pushes and pull requests to the `develop` branch
2. **Testing**: Runs the full RSpec test suite with PostgreSQL
3. **Deployment**: Deploys to Dokku staging server if tests pass (only on pushes to develop)

## Required GitHub Secrets

You need to configure the following secrets in your GitHub repository:

### 1. RAILS_MASTER_KEY

- **Purpose**: Rails master key for decrypting credentials in test environment
- **How to get it**: Copy the contents of `config/master.key` from your local Rails app
- **Location**: Repository Settings → Secrets and variables → Actions → New repository secret

### 2. DOKKU_SSH_PRIVATE_KEY

- **Purpose**: SSH private key for connecting to your Dokku server
- **How to get it**:
  1. Generate a new SSH key pair: `ssh-keygen -t rsa -b 4096 -C "github-actions@yourdomain.com"`
  2. Add the public key to your Dokku server: `ssh-copy-id -i ~/.ssh/id_rsa.pub dokku@45.79.159.125`
  3. Copy the private key content: `cat ~/.ssh/id_rsa`
- **Location**: Repository Settings → Secrets and variables → Actions → New repository secret

### 3. DOKKU_SSH_KNOWN_HOSTS

- **Purpose**: SSH known hosts entry for your Dokku server
- **How to get it**:
  1. Run: `ssh-keyscan -H <ip_address>`
  2. Copy the output (should be one line starting with the IP address)
- **Location**: Repository Settings → Secrets and variables → Actions → New repository secret

## Setting up GitHub Secrets

1. Go to your GitHub repository
2. Click on "Settings" tab
3. In the left sidebar, click "Secrets and variables" → "Actions"
4. Click "New repository secret" for each secret above
5. Enter the secret name and value
6. Click "Add secret"

## Workflow Behavior

- **Pull Requests**: Only runs tests, no deployment
- **Pushes to develop**: Runs tests, and if they pass, deploys to staging
- **Other branches**: No action taken

## Troubleshooting

### Tests failing

- Check that `RAILS_MASTER_KEY` is correctly set
- Verify database configuration in test environment
- Check test logs for specific error messages

### Deployment failing

- Verify SSH keys are correctly configured
- Check that the Dokku app `<app-name>` exists on your server
- Ensure the SSH user has proper permissions on the Dokku server

### SSH Connection Issues

- Verify `DOKKU_SSH_KNOWN_HOSTS` contains the correct fingerprint
- Check that the SSH private key matches the public key on the server
- Test SSH connection manually: `ssh dokku@<ip-addr>`
