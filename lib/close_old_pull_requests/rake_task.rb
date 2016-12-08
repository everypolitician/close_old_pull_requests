require 'rake'
require 'rake/tasklib'

module CloseOldPullRequests
  class RakeTask < ::Rake::TaskLib
    attr_reader :name

    def initialize(name = :close_old_pull_requests)
      @name = name
    end

    def install_tasks
      desc 'Go through the list of open pull requests and close any outdated ones'
      task(name) do
        require 'close_old_pull_requests'
        CloseOldPullRequests.clean.each do |pull_request|
          puts "Pull request #{pull_request.number} is outdated. (Newest pull request is #{pull_request.superseded_by.number})"
        end
      end
    end
  end
end
