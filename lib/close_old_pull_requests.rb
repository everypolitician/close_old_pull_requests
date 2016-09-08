require 'close_old_pull_requests/version'

module CloseOldPullRequests
  PullRequest = Struct.new(:number, :superseded_by)

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
end
