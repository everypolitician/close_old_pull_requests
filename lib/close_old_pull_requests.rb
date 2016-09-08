require 'close_old_pull_requests/version'
require 'octokit'

module CloseOldPullRequests
  PullRequest = Struct.new(:number, :superseded_by)

  def self.clean
    github = Octokit::Client.new
    github.access_token = ENV['GITHUB_ACCESS_TOKEN']
    Cleaner.new(github).clean_old_pull_requests
  end

  # Finds the outdated pull requests in a list of pull requests that comes
  # back from the GitHub API.
  class Finder
    attr_reader :pull_requests

    def initialize(pull_requests)
      @pull_requests = pull_requests
    end

    def outdated
      pull_requests.group_by { |pr| [pr[:title], pr[:user][:login]] }.values.map do |pulls|
        pulls = pulls.sort_by { |p| p[:created_at] }.reverse
        new_pr = PullRequest.new(pulls.first[:number])
        pulls.drop(1).map { |p| PullRequest.new(p[:number], new_pr) }
      end.compact.flatten
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

  class Cleaner
    attr_reader :github

    def initialize(github)
      @github = github
    end

    def clean_old_pull_requests
      Finder.new(pull_requests).outdated.each do |pull_request|
        other_committers = OtherCommitters.new(
          commits:       pull_request_commits(pull_request.number),
          primary_login: github.user.login
        )
        if other_committers.empty? # The only commits were by @everypoliticianbot
          message = "This Pull Request has been superseded by ##{pull_request.superseded_by.number}"
          github.add_comment(everypolitician_data_repo, pull_request.number, message)
          github.close_pull_request(everypolitician_data_repo, pull_request.number)
        else # There are human commits
          message = "This Pull Request has been superseded by ##{pull_request.superseded_by.number}" \
            " but there are non-bot commits.\n\n" \
            "#{other_committers.mentions} is this pull request still needed?"
          github.add_comment(everypolitician_data_repo, pull_request.number, message)
        end
      end
    end

    private

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
