# Release workflow

The user wants completed game updates published automatically when publishing is enabled. GitHub publishing is currently paused; prepare verified local builds and source commits, and wait for explicit approval to resume uploads.

After implementing and verifying an update, package the Windows build with tools/package_windows.ps1 and update README. When publishing resumes, commit/push scoped source changes and upload the verified ZIP plus checksum as GitHub Release assets. Future release ZIPs are ignored intentionally: do not force-add them to source history. Existing tracked releases remain available; do not delete them or rewrite Git history without explicit approval.

Do not include unrelated local files, diagnostic logs, credentials, or old untracked builds. Report the published download link (or local package path while publishing is paused) and any testing limitations. Do not publish unfinished or failing work merely to satisfy the release preference.
