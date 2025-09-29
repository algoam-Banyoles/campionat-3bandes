# GitHub Actions Setup Guide

## Required Secrets Configuration

To resolve the GitHub Actions warnings about "Context access might be invalid", you need to configure the following secrets in your GitHub repository:

### Step 1: Navigate to Repository Settings
1. Go to your GitHub repository: `https://github.com/algoam-Banyoles/campionat-3bandes`
2. Click on **Settings** tab
3. In the left sidebar, click **Secrets and variables** > **Actions**

### Step 2: Add Required Secrets
Click **New repository secret** and add the following:

#### For Production Deployment (`supabase-deploy-prod.yml`)
- **Name**: `SUPABASE_ACCESS_TOKEN`
  - **Value**: Your Supabase access token (get from Supabase Dashboard > Settings > API)
  
- **Name**: `SUPABASE_PROJECT_REF_PROD`
  - **Value**: Your production Supabase project reference ID (e.g., `abcdefghijklmnop`)

#### For Staging/PR Validation (`supabase-validate-pr.yml`)
- **Name**: `SUPABASE_PROJECT_REF_STAGING`
  - **Value**: Your staging Supabase project reference ID (e.g., `zyxwvutsrqponmlk`)

### Step 3: Verify Configuration
Once the secrets are added:
1. The GitHub Actions warnings will disappear
2. The workflows will run successfully when triggered
3. You can test by creating a pull request that modifies `supabase/migrations/**`

## Where to Find Your Values

### Supabase Access Token
1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Click on your profile (top right)
3. Go to **Access Tokens**
4. Create a new token or copy an existing one

### Project Reference IDs
1. Go to your Supabase project dashboard
2. Go to **Settings** > **General**
3. Find the **Reference ID** in the project details

## Security Notes
- Never commit these values to your code
- These secrets are only accessible to GitHub Actions workflows
- Rotate tokens periodically for security
- Use separate projects for staging and production

## Testing the Setup
After configuring the secrets, you can test the workflows by:
1. Creating a new migration file in `supabase/migrations/`
2. Pushing to a branch and creating a PR (triggers staging deployment)
3. Merging to `main` branch (triggers production deployment)