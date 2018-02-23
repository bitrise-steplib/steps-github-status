require 'net/http'
require 'net/https'
require 'json/ext'

# Config
class Config
  def initialize
    @api_base_url = ENV['api_base_url']
    @repository_url = ENV['repository_url']
    @commit_hash = ENV['commit_hash']
    @ci_build_url = ENV['build_url']
    @authorization_token = ENV['auth_token']
    @build_is_green = ENV['STEPLIB_BUILD_STATUS'] == '0'
    @specific_status = ENV['set_specific_status']
  end

  def print
    secure_token = ''
    secure_token = '***' unless @authorization_token.to_s.eql? ''

    puts 'Config:'
    puts "  api_base_url: #{@api_base_url}"
    puts "  repository_url: #{@repository_url}"
    puts "  commit_hash: #{@commit_hash}"
    puts "  ci_build_url: #{@ci_build_url}"
    puts "  authorization_token: #{secure_token}"
    puts "  build_is_green: #{@build_is_green}"
    puts "  specific_status: #{@specific_status}"
    puts
  end

  def validate
    raise 'No repository repository_url specified' if @repository_url.to_s.empty?
    raise 'No commit hash specified' if @commit_hash.to_s.empty?
    raise 'No build url specified' if @ci_build_url.to_s.empty?
    raise 'No authorization_token specified' if @authorization_token.to_s.empty?
  end

  attr_reader :api_base_url
  attr_reader :repository_url
  attr_reader :commit_hash
  attr_reader :ci_build_url
  attr_reader :authorization_token
  attr_reader :build_is_green
  attr_reader :specific_status
end

# Step
class GithubStatusHelper
  def parse(repository_url)
    user = ''
    repo = ''

    regexp = %r{([A-Za-z0-9]+@|http(|s)\:\/\/)([A-Za-z0-9.-]+)(:|\/)(?<user>[^.]+)\/(?<repo>[^.]+)(\.git)?}
    match = repository_url.match(regexp)
    if match
      captures = match.captures
      if captures.length == 2
        user = captures[0]
        repo = captures[1]
      end
    end

    raise "#{repository_url} is not a GitHub repository" unless user.length && repo.length

    return [user, repo]
  end

  def perform(user, repo, api_base_url, commit_hash, authorization_token, build_is_green, ci_build_url, specific_status)
    uri = URI.parse("#{api_base_url}/repos/#{user}/#{repo}/statuses/#{commit_hash}")

    puts "  uri: #{uri}"
    puts

    http = Net::HTTP.new(uri.host, uri.port)

    http.use_ssl = true
    http.ssl_version = :SSLv2
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER

    req = Net::HTTP::Post.new(uri.path)
    req['Authorization'] = "token #{authorization_token}"

    status = specific_status

    if status.empty?
      status = (build_is_green ? 'success' : 'failure')
    end

    req.body = {
      state: status,
      target_url: ci_build_url,
      description: (build_is_green ? 'The build succeeded' : 'The build failed. Check the logs on Bitrise'),
      context: 'continuous-integration/bitrise'
    }.to_json

    return http.request(req)
  end
end
