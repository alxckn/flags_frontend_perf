#!/usr/bin/env ruby

require 'json'

def get_random_percentage
  [10, 25, 50, 75, 90].sample
end

def get_random_context
  contexts = {
    'tld' => ['fr', 'de', 'it'],
    'accountType' => ['pro', 'patient'],
    'platform' => ['mobile', 'desktop', 'web']
  }
  
  # Pick 1-3 random context types
  num_contexts = rand(1..3)
  selected_keys = contexts.keys.sample(num_contexts)
  
  result = {}
  selected_keys.each do |key|
    result[key] = contexts[key].sample
  end
  
  result
end

def generate_flags
  flags = {}
  
  puts "Generating flagd configuration with 1000 test flags..."
  
  (1..1000).each do |i|
    puts "Progress: #{i}/1000 flags generated..." if i % 100 == 0
    
    flag_name = "test-flag-#{i.to_s.rjust(4, '0')}"
    
    if i <= 300
      # 30% fully enabled (1-300)
      flags[flag_name] = {
        'state' => 'ENABLED',
        'variants' => {
          'on' => { 'value' => true },
          'off' => { 'value' => false }
        },
        'defaultVariant' => 'on'
      }
    elsif i <= 700
      # 40% with segmentation and rollout (301-700)
      percentage = get_random_percentage
      context = get_random_context
      
      # Build targeting rule with context matching and fractional distribution
      if context.empty?
        # Simple fractional distribution without context
        targeting_rule = {
          'fractional' => [
            { 'var' => 'sessionId' },
            ['on', percentage],
            ['off', 100 - percentage]
          ]
        }
      else
        # Context matching with nested fractional distribution
        targeting_rule = {
          'if' => [
            { 'and' => context.map { |key, value| { '===' => [{ 'var' => key }, value] } } },
            {
              'fractional' => [
                { 'var' => 'sessionId' },
                ['on', percentage],
                ['off', 100 - percentage]
              ]
            },
            'off'
          ]
        }
      end
      
      flags[flag_name] = {
        'state' => 'ENABLED',
        'variants' => {
          'on' => { 'value' => true },
          'off' => { 'value' => false }
        },
        'defaultVariant' => 'off',
        'targeting' => targeting_rule
      }
    else
      # 30% disabled (701-1000)
      flags[flag_name] = {
        'state' => 'DISABLED',
        'variants' => {
          'on' => { 'value' => true },
          'off' => { 'value' => false }
        },
        'defaultVariant' => 'off'
      }
    end
  end
  
  flags
end

def main
  flags = generate_flags
  
  config = {
    '$schema' => 'https://flagd.dev/schema/v0/flags.json',
    'flags' => flags
  }
  
  # Write to JSON file
  File.write('flags.json', JSON.pretty_generate(config))
  
  puts ""
  puts "Flagd configuration generated: flags.json"
  puts ""
  puts "Configuration summary:"
  puts "- Flags 0001-0300 (300 flags): Fully enabled"
  puts "- Flags 0301-0700 (400 flags): Segmented with random rollout percentages"
  puts "- Flags 0701-1000 (300 flags): Disabled"
  puts ""
  puts "Supported contexts (segments):"
  puts "- tld: fr, de, it (European users)"
  puts "- accountType: pro, patient"
  puts "- platform: mobile, desktop, web"
end

main if __FILE__ == $0