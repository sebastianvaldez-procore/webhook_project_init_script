require 'rubygems'
require 'bundler/setup'

require 'httparty'
require 'oauth2' # to use for client auth flow
require 'tty-prompt' # to make script ask users for info
require 'dotenv'
require 'json'
require 'pry-byebug'
require 'logger'
require 'progress_bar'

#Ask Script user for customer info 
prompt = TTY::Prompt.new
@customer_info = prompt.collect do
  key(:company_id).ask('What is the Procore Company Id? ')
  key(:client_id).ask('What is Client ID? ')
  key(:client_secret).ask('What is Client Secret? ')
end

@login_url = 'https://login.procore.com/'
@base_url = 'https://us02.procore.com' # todo ask user for us02 api 

def procore_headers(company_id: nil, token: '')
  if company_id.nil?
    {
      "Authorization": "Bearer #{token}",
      "Content-Type": "application/json",
    }
  else
    {
      "Authorization": "Bearer #{token}",
      "Content-Type": "application/json",
      "Procore-Company-Id": "#{company_id}"
    }
  end
end

  # get access token
  client =  OAuth2::Client.new(
    @customer_info[:client_id],
    @customer_info[:client_secret],
    site: @login_url
  )
  @customer_info[:token] = client.client_credentials.get_token({'grant_type': 'client_credentials'}).token
  puts 'Succesfully Set client credential token'

begin
  def delete_procore_webhook(project_id: , webhook_hook_id:)
    url = "#{@base_url}/vapid/webhooks/hooks/#{webhook_hook_id}?project_id=#{project_id}"
    res = HTTParty.delete(url, headers: procore_headers(company_id: @customer_info[:company_id], token: @customer_info[:token]) )
    if res.code != 200
      throw StandardError.new("Failure to delete hook: #{webhook_hook_id} on project: #{project_id}")
    end
  end

  # load log file and json parse it
  file = JSON.load(File.open(' NAME OF COMPANY LOG FILE HERE '))
  file = file.map{|item| JSON.parse(item)}

  # Collect project_ids and hook ids that are disticnt into hash
  distinct_hook_ids =  file.group_by{|item| item["project_id"]}
                            .map{|hooks| { project_id: hooks[0] , webhook_hook_id: hooks[1][0]["webhook_hook_id"] } }



  # loop over file for project ids and hook ids
  bar = ProgressBar.new(distinct_hook_ids.size)
  distinct_hook_ids.map do |item|
    res = delete_procore_webhook(project_id: item[:project_id], webhook_hook_id: item[:webhook_hook_id])
    bar.increment!
  end
rescue => e
  binding.pry
end
puts "All #{distinct_hook_ids.size} Project webhooks Deleted"


