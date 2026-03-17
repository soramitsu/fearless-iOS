## Private Pods / Secrets Setup

Some modules (FearlessKeys, SSFAssetManagmentStorage) live in a private CocoaPods spec. To run full builds/tests locally:

1. Generate a GitHub PAT with `repo` read access (the builder account already has one).
2. Run the helper script (it writes a local `.env.private` file and configures Git to use the token):

   ```bash
   GH_PAT_READ=ghp_yourtoken scripts/secrets/setup-private-pods.sh
   source .env.private   # enables INCLUDE_FEARLESS_KEYS=1 for pod install/dev-setup
   ```

   If `GH_PAT_READ` is omitted you’ll be prompted interactively.

3. Install pods and bootstrap SwiftPM as usual:

   ```bash
   pod install
   scripts/dev-setup.sh
   ```

4. If you also have the Google/OKX keys, drop the `google-keys.txt` payload into `Pods/FearlessKeys/FearlessKeys/Classes/` and export the required env vars (`GOOGLE_CLIENT_ID`, `OKX_API_KEY`, etc.) before running the app.

To undo the Git override later:

```bash
git config --global --unset-all url."https://${GH_PAT_READ}@github.com/".insteadOf
```
