# Instructions

## Code style
- Don't use short variable names, e.g. prefer `device_config` over `dc`

## Tests
- Don't add comments to tests
- Don't use `instance_variable_get` or `send` in tests — add a public accessor or method to the class instead

## PRs
- Squash commits in PRs
- Don't add Claude session links to PR descriptions
