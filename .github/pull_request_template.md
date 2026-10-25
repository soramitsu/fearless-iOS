## Summary

Describe the change and why it is needed.

## Related Issue

Closes #<issue-number> (or) Relates to #<issue-number>

## Target Branch

- [ ] This PR targets `develop`
- [ ] This PR targets `master` and is a release or hotfix PR

## Type of Change

- [ ] feat (new feature)
- [ ] fix (bug fix)
- [ ] refactor (no functional change)
- [ ] chore/build (tooling, CI, deps)
- [ ] docs

## Screenshots / Videos

If UI changes, include before/after.

## Test Plan

Commands run locally:

```
xcodebuild -workspace fearless.xcworkspace -scheme fearless.tests test
```

Additional checks and scenarios covered:
-

## Risks & Rollout

Potential impact, migrations, or config/secrets required.

## Checklist

- [ ] Linked an issue and added a clear description
- [ ] Added/updated tests for changed code where applicable
- [ ] Updated docs when behavior or commands changed
- [ ] Ran simulator build/tests locally or verified CI
- [ ] No secrets or local environment files committed
- [ ] `./scripts/audit-public-artifacts.sh` passes when public artifacts or env defaults change
- [ ] No direct-to-`master` workflow is introduced
