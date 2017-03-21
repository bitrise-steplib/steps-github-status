require_relative './../github_status_helper'

describe GithubStatusHelper do
  describe 'github status helper' do
    helper = GithubStatusHelper.new

    it 'parses https repository url' do
      user, repo = helper.parse('https://github.com/bitrise-steplib/steps-github-status.git')
      expect(user).to eq('bitrise-steplib')
      expect(repo).to eq('steps-github-status')
    end

    it 'parses ssh repository url' do
      user, repo = helper.parse('git@github.com:bitrise-steplib/steps-github-status.git')
      expect(user).to eq('bitrise-steplib')
      expect(repo).to eq('steps-github-status')
    end

    it 'parses ssh repository url - even with special username' do
      user, repo = helper.parse('git@github.com:-bitrise-steplib/steps-github-status.git')
      expect(user).to eq('-bitrise-steplib')
      expect(repo).to eq('steps-github-status')
    end
  end
end
