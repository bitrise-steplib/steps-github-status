require 'net/http'
require 'net/https'
require 'json/ext'

api_base_url = ENV['STEP_GITHUB_API_BASE_URL']
repository_url = ENV['STEP_GITHUB_STATUS_REPOSITORY_URL']
commit_hash = ENV['STEP_GITHUB_STATUS_COMMIT_HASH']
ci_build_url = ENV['STEP_GITHUB_STATUS_BUILD_URL']
authorization_token = ENV['STEP_GITHUB_STATUS_API_TOKEN'] || ENV['STEP_GITHUB_STATUS_AUTH_TOKEN']
build_is_green = ENV['STEPLIB_BUILD_STATUS'] == '0'

puts 'Config:'
puts "api_base_url: #{api_base_url}"
puts "repository_url: #{repository_url}"
puts "commit_hash: #{commit_hash}"
puts "ci_build_url: #{ci_build_url}"
puts 'authorization_token: ' + (authorization_token.to_s.eql? '') ? 'empty' : '***'
puts "build_is_green: #{build_is_green}"

if url.to_s.eql? ''
  puts 'No repository url specified'
  exit 1
end

regexp = %r{([A-Za-z0-9]+@|http(|s)\:\/\/)([A-Za-z0-9.-]+)(:|\/)(?<user>[A-Za-z0-9]+)\/(?<repo>[^.]+)(\.git)?}
unless (regexp =~ url).zero?
  puts "#{url} is not a GitHub repository"
  exit 1
end

if commit_hash.to_s.eql? ''
  puts 'No commit hash specified'
  exit 1
end

if ci_build_url.to_s.eql? ''
  puts 'No build url specified'
  exit 1
end

if authorization_token.to_s.eql? ''
  puts 'No authorization_token specified'
  exit 1
end

uri = URI.parse("#{api_base_url}/repos/#{user}/#{repo}/statuses/#{commit_hash}")
http = Net::HTTP.new(uri.host, uri.port)

http.use_ssl = true
http.ssl_version = :TLSv1
http.verify_mode = OpenSSL::SSL::VERIFY_PEER

req = Net::HTTP::Post.new(uri.path)
req['Authorization'] = "token #{authorization_token}"
req.body = {
  state: (build_is_green ? 'success' : 'failure'),
  target_url: ci_build_url,
  description: (build_is_green ? 'The build succeeded' : 'The build failed. Check the logs on Bitrise'),
  context: 'continuous-integration/bitrise'
}.to_json
response = http.request(req)

if response.code.eql?('201')
  puts "Updated status for commit #{commit_hash}"
else
  puts 'Failed to update commit status'
end
exit (response.code.eql?('201') ? 0 : 1)
