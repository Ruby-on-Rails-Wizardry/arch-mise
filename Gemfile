# frozen_string_literal: true

# Starter gems when this flavor directory is the project at /work
# (`task warm` runs `bundle install` if a Gemfile is present).
# App repos should ship their own Gemfile; this is a common Rails + lint set.

source "https://rubygems.org"

ruby "4.0.6"

gem "rails", "~> 8.1.3"

group :development do
  gem "brakeman", "~> 8.0", require: false
  gem "rubocop", "~> 1.88", require: false
end
