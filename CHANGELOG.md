# Change log

## master (unreleased)

### New Features

* Add `CsvReport` helper for reading, writing and merging `csv` reports
* Add `TestReport` helper which writes results of the run to the `csv` report
* Add unit tests for the report helpers
* Add `dependabot` check for `GitHub Actions`
* Add `ruby-3.3` to CI
* Add `ruby-3.4` to CI
* Update default Dockerfile to `ruby-3.4`

### Changes

* Write test results to the `csv` reports instead of `palladium`
* Remove `palladium` dependency and its token check from the pre-test checks
* Remove `ruby-3.0` from CI, since it's EOLed

### Fixes

* Run `rubocop` in CI through `bundle exec`

## (2024-02-27)

### Changes

* Rewritten tests for more efficient testing of conversion api

## (2023-12-22)

### New Features

* Add `markdownlint` check in CI
* Add `yamllint` check in CI

### Changes

* Check `dependabot` at 8:00 Moscow time daily
* Drop `ruby-2.7` support, since it's EOL
