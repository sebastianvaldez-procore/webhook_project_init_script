### Procore Webhook init script

Setup a Customer's project(s) to use webhooks

### clone repo and cd into it
> $ bundle install

### Run the script
> $ ruby script.rb

### Run the Delete script
> #First set the log file in the script where it will be parsed
> $ ruby delete.rb

# Todos:
- [ ] Ask for project list to only setup 
- [ ] Add better error handling
- [ ] Log file container client id/secret & company id (for delete script to use)
- [ ] Add a Progress bar betweens tasks
- [ ] Create Company level Hook
- [✅] Create a 'undo' script using the log file 