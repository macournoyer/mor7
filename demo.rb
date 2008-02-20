%w(rubygems eventmachine thin thin_parser rack rack/lobster).each { |f| require f }

class Connection < EventMachine::Connection  
  attr_accessor :app
  
  def initialize
    @parser = Thin::HttpParser.new
    @data = ''
    @nparsed = 0
    @env = {}
  end
  
  def receive_data(data)
    @data << data
    @nparsed = @parser.execute(@env, @data, @nparsed)
    
    process if @parser.finished?
  end
  
  def process
    status, headers, body = @app.call(@env)
    
    body_output = ''
    body.each { |l| body_output << l }
    
    send_data "HTTP/1.1 #{status} OK\r\n" +
              headers.inject('') { |h, (k,v)| h += "#k: #v\r\n" } +
              "\r\n" +
              body_output
    
    close_connection_after_writing
  end
end

welcome_app = proc do |env|
  [
    200,                                  # Status
    {'Content-Type' => 'text/html'},      # Headers
    [
      '<html><body>',
      '<h1>Welcome</h1>',
      '<p>Welcome to my server!</p>',            # Body
      '<p><a href="/rails">My Rails app!</a></p>',
      '</body></html>'
    ]
  ]
end

rails_app = Rack::Adapter::Rails.new(:root => '/Users/marc/projects/refactormycode', :prefix => '/rails')

app = Rack::URLMap.new('/' => welcome_app, '/rails' => rails_app)

EventMachine.run do
  EventMachine.start_server '0.0.0.0', 3000, Connection do |con|
    con.app = app
  end
end
