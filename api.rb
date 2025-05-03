require 'sinatra'
require 'sinatra/cross_origin'
require 'json'
require 'truemail'

# CORS setup
configure do
  enable :cross_origin
end

before do
  response.headers['Access-Control-Allow-Origin'] = '*'
  response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
end

options '/verify' do
  response.headers['Access-Control-Allow-Methods'] = 'POST, OPTIONS'
  response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
  200
end

# Truemail setup
Truemail.configure do |config|
  config.verifier_email = 'you@yourdomain.com'  # Replace this
  config.connection_timeout = 2
  config.response_timeout = 2
  config.connection_attempts = 1
end

# Email verification endpoint
post '/verify' do
  content_type :json

  begin
    request_payload = JSON.parse(request.body.read)
  rescue JSON::ParserError
    halt 400, { error: 'Invalid JSON' }.to_json
  end

  target_email = request_payload['email']
  halt 400, { error: 'Email is required' }.to_json unless target_email

  domain = target_email.split('@').last
  fake_email = "fake_#{rand(100000..999999)}@#{domain}"

  real_result = Truemail.validate(target_email)
  fake_result = Truemail.validate(fake_email)

  output = {
    email: target_email,
    valid: real_result.result == true,
    catch_all: false,
    reason: nil
  }

  if real_result.result == true && fake_result.result == true
    output[:catch_all] = true
    output[:reason] = "catch_all_detected"
  elsif real_result.result == true
    output[:catch_all] = false
    output[:reason] = "smtp_verified"
  else
    output[:catch_all] = fake_result.result == true
    output[:reason] = "invalid_or_rejected"
  end

  output.to_json
end
