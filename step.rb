require_relative './github_status_helper'

begin
  config = Config.new
  config.print
  config.validate

  helper = GithubStatusHelper.new
  user, repo = helper.parse(config.repository_url)
  response = helper.perform(
    user,
    repo,
    config.api_base_url,
    config.commit_hash,
    config.authorization_token,
    config.build_is_green,
    config.ci_build_url,
    config.specific_status
  )

  unless response.code.eql?('201')
    puts "Response status code: #{response.code}"
    puts "Response message: #{response.message}"
    puts "Response body: #{response.body}"
    puts 'Failed to update commit status'
    exit 1
  end

  puts "Updated status for commit #{config.commit_hash}"
  exit 0
rescue => ex
  puts ex.inspect.to_s
  puts '--- Stack trace: ---'
  puts ex.backtrace.to_s
  exit 1
end
