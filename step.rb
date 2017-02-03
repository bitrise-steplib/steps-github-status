require 'net/http'
require 'net/https'
require 'json/ext'

# Inputs
api_base_url = ENV['api_base_url']
repository_url = ENV['repository_url']
commit_hash = ENV['commit_hash']
ci_build_url = ENV['build_url']
authorization_token = ENV['auth_token']
build_is_green = ENV['STEPLIB_BUILD_STATUS'] == '0'
specific_status = ENV['set_specific_status']

secure_token = ''
secure_token = '***' unless authorization_token.to_s.eql? ''

puts 'Config:'
puts "  api_base_url: #{api_base_url}"
puts "  repository_url: #{repository_url}"
puts "  commit_hash: #{commit_hash}"
puts "  ci_build_url: #{ci_build_url}"
puts "  authorization_token: #{secure_token}"
puts "  build_is_green: #{build_is_green}"
puts

if repository_url.to_s.eql? ''
  puts 'No repository repository_url specified'
  exit 1
end

user = ''
repo = ''
regexp = %r{([A-Za-z0-9]+@|http(|s)\:\/\/)([A-Za-z0-9.-]+)(:|\/)(?<user>[A-Za-z0-9]+)\/(?<repo>[^.]+)(\.git)?}
match = repository_url.match(regexp)
if match
  captures = match.captures
  if captures.length == 2
    user = captures[0]
    repo = captures[1]
  end
end

unless user.length && repo.length
  puts "#{repository_url} is not a GitHub repository"
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

# Main
puts "Update status of #{repo}, owner: #{user}"

uri = URI.parse("#{api_base_url}/repos/#{user}/#{repo}/statuses/#{commit_hash}")

puts "  uri: #{uri}"
puts

http = Net::HTTP.new(uri.host, uri.port)

http.use_ssl = true
http.ssl_version = :TLSv1
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

response = http.request(req)

unless response.code.eql?('201')
  puts "Response status code: #{response.code}"
  puts "Response message: #{response.message}"
  puts "Response body: #{response.body}"
  puts 'Failed to update commit status'
  exit 1
end

puts "Updated status for commit #{commit_hash}"
exit 0
