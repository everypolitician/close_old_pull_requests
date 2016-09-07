# Close old pull requests

This library will go through the open pull requests on [everypolitician/everypolitician-data](https://github.com/everypolitician/everypolitician-data) and close any that have been are now out of date and have been replaced by a newer pull request.

To determine if a pull request is out of date we perform the following steps:

- Group pull requests by title and author -- pull requests created by @everypoliticianbot in `everypolitician-data` have a predictable title `"#{country.name} (#{legislature.name}): refresh data"`
- Close all but the most recently created pull requests in each group.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'close_old_pull_requests', git: 'https://github.com/everypolitician/close_old_pull_requests', branch: 'master'
```

And then execute:

    $ bundle

## Usage

First require the library in your program:

```ruby
require 'close_old_pull_requests'
```

Then you can find a list of pull requests that need closing with:

```ruby
pull_requests = [
  { number: 42, title: 'Test', created_at: '2016-09-05T18:25:42Z' },
  { number: 100, title: 'Test', created_at: '2016-09-07T12:00:00Z' },
]

CloseOldPullRequests::Finder.new(pull_requests).outdated.each do |pull_request|
  puts "Pull request #{pull_request.number} is outdated. (Newest pull request is #{pull_request.superseded_by.number})"
end
```

This will output:

    Pull request 42 is outdated. (Newest pull request is 100)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/everypolitician/close_old_pull_requests.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
