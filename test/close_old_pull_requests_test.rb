require 'test_helper'

describe CloseOldPullRequests do
  it 'has a version number' do
    refute_nil ::CloseOldPullRequests::VERSION
  end

  describe CloseOldPullRequests::Finder do
    it 'returns a list of outdated pull requests' do
      pull_requests = [
        { number: 42, title: 'Test', created_at: '2016-09-05T18:25:42Z', user: { login: 'everypoliticianbot' } },
        { number: 100, title: 'Test', created_at: '2016-09-07T12:00:00Z', user: { login: 'everypoliticianbot' } },
      ]

      outdated_pr = CloseOldPullRequests::Finder.new(pull_requests).outdated.first
      outdated_pr.number.must_equal 42
      outdated_pr.superseded_by.number.must_equal 100
    end
  end
end
