require 'test_helper'

describe CloseOldPullRequests do
  it 'has a version number' do
    refute_nil ::CloseOldPullRequests::VERSION
  end

  let(:outdated_pull_request) { { number: 42, title: 'Test', created_at: '2016-09-05T18:25:42Z', user: { login: 'everypoliticianbot' } } }
  let(:new_pull_request) { { number: 100, title: 'Test', created_at: '2016-09-07T12:00:00Z', user: { login: 'everypoliticianbot' } } }
  let(:pull_requests) { [outdated_pull_request, new_pull_request] }

  describe CloseOldPullRequests::Finder do
    it 'returns a list of outdated pull requests' do
      outdated_pr, new_pr = CloseOldPullRequests::Finder.new(pull_requests).outdated.first
      outdated_pr.number.must_equal 42
      new_pr.number.must_equal 100
    end
  end

  describe CloseOldPullRequests::OtherCommitters do
    it 'represents a single committer' do
      commits = [
        { author: { login: 'everypoliticianbot' } },
        { author: { login: 'everypoliticianbot' } },
      ]
      other_committers = CloseOldPullRequests::OtherCommitters.new(
        commits:       commits,
        primary_login: 'everypoliticianbot'
      )
      other_committers.author_logins.must_equal []
      other_committers.empty?.must_equal true
      other_committers.mentions.must_equal ''
    end

    it 'represents multiple committers' do
      commits = [
        { author: { login: 'everypoliticianbot' } },
        { author: { login: 'tmtmtmtm' } },
        { author: { login: 'chrismytton' } },
      ]
      other_committers = CloseOldPullRequests::OtherCommitters.new(
        commits:       commits,
        primary_login: 'everypoliticianbot'
      )
      other_committers.author_logins.must_equal %w(tmtmtmtm chrismytton)
      other_committers.mentions.must_equal '@tmtmtmtm, @chrismytton'
      other_committers.empty?.must_equal false
    end
  end

  describe CloseOldPullRequests::Cleaner do
    let(:everypolitician_data) { 'everypolitician/everypolitician-data' }
    let(:github) { Minitest::Mock.new }

    before do
      github.expect :pull_requests, pull_requests, [everypolitician_data]
      github.expect :issue_comments, [], [everypolitician_data, 42]
    end

    after { github.verify }

    describe 'with a single committer' do
      let(:commits) do
        [{ author: { login: 'everypoliticianbot' } }]
      end

      before do
        github.expect :pull_request_commits, commits, [everypolitician_data, 42]
        github.expect :add_comment, nil, [
          everypolitician_data,
          42,
          'This Pull Request has been superseded by #100',
        ]
        github.expect :close_pull_request, nil, [everypolitician_data, 42]
      end

      it 'cleans up old pull requests' do
        CloseOldPullRequests::Cleaner.new(github).clean_old_pull_requests
      end
    end

    describe 'with multiple comitters' do
      let(:commits) do
        [
          { author: { login: 'everypoliticianbot' } },
          { author: { login: 'chrismytton' } },
        ]
      end

      before do
        github.expect :pull_request_commits, commits, [everypolitician_data, 42]
        github.expect :add_comment, nil, [
          everypolitician_data,
          42,
          "This Pull Request has been superseded by #100 but there are non-bot commits.\n\n@chrismytton is this pull request still needed?",
        ]
      end

      it 'cleans up old pull requests' do
        CloseOldPullRequests::Cleaner.new(github).clean_old_pull_requests
      end
    end
  end
end
