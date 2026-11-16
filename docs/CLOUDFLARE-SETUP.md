# Cloudflare: a deploy token for GitHub (Chris, 16 Nov)

These steps let the next session deploy the Tennis Vision cloud service (the Worker, its D1 database and its R2 storage; TV-PH-4) from GitHub. Nothing is deployed until then. They use your existing Cloudflare account and touch none of your other sites.

## 1. Find your account ID

1. Sign in at dash.cloudflare.com.
2. Open **Workers & Pages** in the left menu.
3. On the right, under **Account details**, copy the **Account ID** (32 letters and digits). It is not secret, but it goes into GitHub with the token.

## 2. Make a token that can only deploy Workers, D1 and R2

1. At the top right, open your profile icon > **My Profile** > **API Tokens** > **Create Token**.
2. Next to **Create Custom Token**, press **Get started**.
3. **Token name:** `tennis-vision-deploy`.
4. **Permissions:** add these three rows, each with the first box set to **Account**:
   - **Workers Scripts**: **Edit**;
   - **D1**: **Edit**;
   - **Workers R2 Storage**: **Edit**.
5. **Account Resources:** **Include**, your account (pick it by name). Not "All accounts".
6. **Zone Resources:** leave empty. The service runs on its own `workers.dev` address, so the token gets no access to your sites' DNS or settings.
7. **Client IP Address Filtering:** leave empty (GitHub's machines change address).
8. **TTL:** set an end date one year from today. You can roll the token later.
9. **Continue to summary**: check that it lists only the three permissions on your one account. Then **Create Token**.
10. **Copy the token now.** Cloudflare shows it only once. Don't paste it anywhere except step 3.

## 3. Add both to GitHub as secrets

1. On github.com, open **Wotworth/Tennis** > **Settings** > **Secrets and variables** > **Actions**.
2. **New repository secret**: name `CLOUDFLARE_API_TOKEN`, value the token from step 2. **Add secret**.
3. **New repository secret**: name `CLOUDFLARE_ACCOUNT_ID`, value the account ID from step 1. **Add secret**.

GitHub keeps them encrypted. Workflows can use them, but nobody can read them back, me included. The repository being public doesn't expose them.

## What happens next session

- I add a deploy workflow to `.github/workflows/`. If GitHub refuses my push of a workflow file, I'll give you the file and the steps to add it in GitHub's web editor (CLAUDE.md).
- The workflow creates the D1 database and the R2 bucket, applies the database migrations, and deploys the Worker with the secrets above.
- The Worker's own read and write tokens (TV-API-03) are made at deploy time and stored as Worker secrets. The PC's upload token then goes into `secrets.local.json` on the PC (step 17 of DAY-ONE.md shows where that file is).
- **Cost:** the free Workers plan is enough to deploy and test. The spec plans on Workers Paid ($5 a month) once real sessions arrive (D1 size and CPU limits); that is your decision, when it's needed.
