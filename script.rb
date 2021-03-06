require 'rubygems'
require 'bundler/setup'

require 'httparty'
require 'oauth2' # to use for client auth flow
require 'tty-prompt' # to make script ask users for info
require 'dotenv'
require 'json'
require 'pry-byebug'
require 'logger'

# ? NOTES:
#? Setup clients project(s) w/ webhook triggers 
#TODO  Make a webhook post to clients company webhooks tool for company level resources
#?

Dotenv.load # LOAD ID AND SECRET FROM .env file ( youll need to create this if cloned repo )

prompt = TTY::Prompt.new
#Ask Script user for customer info 
@customer_info = prompt.collect do
    key(:company_id).ask('What is the Procore Company Id? ')
    key(:client_id).ask('What is Client ID? ')
    key(:client_secret).ask('What is Client Secret? ')
end

@login_url = 'https://login.procore.com/'
@base_url = 'https://api.procore.com' # todo ask user for us02 api 

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

begin

  # get access token
  client =  OAuth2::Client.new(
    @customer_info[:client_id],
    @customer_info[:client_secret],
    site: @login_url
  )
  @customer_info[:token] = client.client_credentials.get_token({'grant_type': 'client_credentials'}).token
  puts 'Succesfully Set client credential token'

  # get the company's projects
  def list_projects(company_id: )
    url = "#{@base_url}/vapid/projects?company_id=#{company_id}"
    HTTParty.get(url, headers: procore_headers(token: @customer_info[:token], company_id: @customer_info[:company_id] )).parsed_response
  end
  
  # filter out projects
  puts 'Fetching projects'
  projects = list_projects(company_id: @customer_info[:company_id]).map{|project| project['id']}

  # todo  Add logic to filter for specific projects customer only wants integrations for.

  # define webhook url n # todo ask for this URL from tty-prompt & add URL validation!
  @webhook = prompt.ask('What is the URL for the webhook Procore should POST to? ')

  # create Hook 
  def create_project_hook(project_id: )
    url = "#{@base_url}/vapid/webhooks/hooks?project_id=#{project_id}"
    body = {
      'project_id': project_id,
      'hook': {
        'api_version': 'v2',
        'namespace': 'slack-integration', #! namespace must be lowercase no special chars
        'destination_url': @webhook
      }
    }

    res = HTTParty.post(
      url,
      headers: procore_headers(token: @customer_info[:token], company_id: @customer_info[:company_id]),
      body: body.to_json)
    if res.code == 201
      res
    else
      raise StandardError.new({message: 'Error Creating Hook', data: res})
    end
  end
  
  projects_and_hooks = []
  puts "Adding Webhooks to Projects"
  projects.map do |id|
    res = create_project_hook(project_id: id)
    projects_and_hooks << { project_id: id, hook_id: res["id"] }
  end

  # template trigger event array
  def create_trigger(hook_id:, project_id:, trigger_body:)
    url = "#{@base_url}/vapid/webhooks/hooks/#{hook_id}/triggers?project_id=#{project_id}"
    res = HTTParty.post(url, body: trigger_body.to_json, headers: procore_headers(token: @customer_info[:token], company_id: @customer_info[:company_id]) ) # returns HTTParty object {code, response}
    if res.code == 201
      res
    else
      raise StandardError.new({message: 'Error Creating Hook', data: res})
    end    
  end

  # 10 current triggers
  trigger_template = [
    {
    "api_version": "v2",
      "trigger": {
        "resource_name": "Projects",
        "event_type": "create"
      }
    },
    {
    "api_version": "v2",
      "trigger": {
        "resource_name": "Projects",
        "event_type": "update"
      }
    },
    {
    "api_version": "v2",
      "trigger": {
        "resource_name": "Projects Users",
        "event_type": "create"
      }
    },
    {
    "api_version": "v2",
      "trigger": {
        "resource_name": "Projects Users",
        "event_type": "update"
      }
    },
    {
    "api_version": "v2",
      "trigger": {
        "resource_name": "Work Order Contracts",
        "event_type": "update"
      }
    },
    {
    "api_version": "v2",
      "trigger": {
        "resource_name": "RFIs",
        "event_type": "create"
      }
    },
    {
    "api_version": "v2",
      "trigger": {
        "resource_name": "RFIs",
        "event_type": "update"
      }
    },
    {
    "api_version": "v2",
      "trigger": {
        "resource_name": "RFI Replies",
        "event_type": "create"
      }
    },
    {
    "api_version": "v2",
      "trigger": {
        "resource_name": "Submittals",
        "event_type": "create"
      }
    },
    {
    "api_version": "v2",
      "trigger": {
        "resource_name": "Submittals",
        "event_type": "update"
      }
    }
  ]
# iterate template of triggers, post w/ webhook id
puts "Adding Triggers to projects"
log = []
projects_and_hooks.map do |project|
  trigger_template.map do |trigger|
    res = create_trigger(
      hook_id: project[:hook_id],
      project_id: project[:project_id],
      trigger_body: trigger
      )
      log << res
  end
end

File.open("company_id_#{@customer_info[:company_id]}_#{Time.now.to_i}.json", 'w') do |file|
  file.write(JSON.pretty_generate(log))
end
puts 'log file wrote.'

rescue => e
  binding.pry
end