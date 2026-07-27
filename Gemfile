# Root tooling Gemfile: installs Rails (app generators) and RuboCop into the
# shared local bundle path (.cache/bundle). App-specific gems live in fred/ and
# george/ Gemfiles and resolve into the same BUNDLE_PATH.

source "https://rubygems.org"

# Source of truth for Ruby (mise reads this via idiomatic version files).
ruby "4.0.6"

gem "rails", "~> 8.1"
gem "rubocop", "~> 1.88"
gem "rubocop-rails", require: false
gem "rubocop-performance", require: false
