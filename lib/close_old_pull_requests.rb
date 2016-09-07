require 'close_old_pull_requests/version'

module CloseOldPullRequests
  PullRequest = Struct.new(:number, :superseded_by)

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
end
