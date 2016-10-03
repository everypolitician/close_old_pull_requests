require 'close_old_pull_requests/version'
require 'octokit'

Octokit.auto_paginate = true

module CloseOldPullRequests
  PullRequest = Struct.new(:number)

  def self.clean(access_token: ENV['GITHUB_ACCESS_TOKEN'])
    github = Octokit::Client.new
    github.access_token = access_token
    Cleaner.new(github).clean_old_pull_requests
  rescue Octokit::Unauthorized
    abort 'Please set GITHUB_ACCESS_TOKEN in the environment and try again'
  end

  # Finds the outdated pull requests in a list of pull requests that comes
  # back from the GitHub API.
  class Finder
    attr_reader :pull_requests

    def initialize(pull_requests)
      @pull_requests = pull_requests
    end

    # Sorts through the `pull_requests` and returns a Hash where the key is the
    # pull request that is now considered outdated and the value is the pull
    # request that supersedes it.
    #
    # @return [Hash] old to new pull request mapping
    def outdated
      pull_requests.group_by { |pr| [pr[:title], pr[:user][:login]] }.values.flat_map do |pulls|
        pulls = pulls.sort_by { |p| p[:created_at] }.reverse.map { |pr| PullRequest.new(pr[:number]) }
        new_pr = pulls.shift
        pulls.map { |pull| [pull, new_pr] }
      end.to_h
    end
  end

  # Determines if there have been any non-bot commits on a pull request.
  class OtherCommitters
    attr_reader :commits, :primary_login

    def initialize(commits:, primary_login:)
      @commits = commits
      @primary_login = primary_login
    end

    def author_logins
      commits.map { |c| c[:author][:login] }.uniq.reject { |l| l == primary_login }
    end

    def mentions
      author_logins.map { |c| "@#{c}" }.join(', ')
    end

    def empty?
      author_logins.empty?
    end
  end

  class Summary
    def initialize(new_pull_request_number:, other_committers:)
      @new_pull_request_number = new_pull_request_number
      @other_committers = other_committers
    end

    def message
      if can_be_closed?
        "This Pull Request has been superseded by ##{new_pull_request_number}"
      else # There are human commits
        "This Pull Request has been superseded by ##{new_pull_request_number}" \
          " but there are non-bot commits.\n\n" \
          "#{other_committers.mentions} is this pull request still needed?"
      end
    end

    def can_be_closed?
      other_committers.empty?
    end

    private

    attr_reader :new_pull_request_number, :other_committers
  end

  class Cleaner
    PRIMARY_LOGIN = 'everypoliticianbot'.freeze

    attr_reader :github

    def initialize(github)
      @github = github
    end

    def clean_old_pull_requests
      Finder.new(pull_requests).outdated.each do |pull_request, new_pull_request|
        other_committers = OtherCommitters.new(
          commits:       pull_request_commits(pull_request.number),
          primary_login: PRIMARY_LOGIN
        )
        summary = Summary.new(
          new_pull_request_number: new_pull_request.number,
          other_committers:        other_committers
        )
        add_comment(pull_request.number, summary.message)
        github.close_pull_request(everypolitician_data_repo, pull_request.number) if summary.can_be_closed?
      end
    end

    private

    def add_comment(number, message)
      return if github.issue_comments(everypolitician_data_repo, number).map(&:body).include?(message)
      github.add_comment(everypolitician_data_repo, number, message)
    end

    def pull_requests
      @pull_requests ||= github.pull_requests(everypolitician_data_repo)
    end

    def pull_request_commits(number)
      github.pull_request_commits(everypolitician_data_repo, number)
    end

    def everypolitician_data_repo
      ENV.fetch('EVERYPOLITICIAN_DATA_REPO', 'everypolitician/everypolitician-data')
    end
  end
end
