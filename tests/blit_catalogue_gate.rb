#!/usr/bin/env ruby
require 'json'
require 'digest'
require 'webrick'
require 'tmpdir'
require 'open3'
ROOT=File.expand_path('..',__dir__)
source=File.binread(File.join(ROOT,'bundles/control-panel/blit.hibr'))
entry=JSON.parse(File.read(File.join(ROOT,'index.json'))).fetch('entries').fetch('control-panel/blit')
abort('generated bundle checksum disagrees') unless entry['sha256']==Digest::SHA256.hexdigest(source)
older=source.sub('server" 0.1.0','server" 0.0.9')
abort('older-version fixture did not change') if older==source
phase=:older
server=WEBrick::HTTPServer.new(BindAddress:'127.0.0.1',Port:0,Logger:WEBrick::Log.new(File::NULL),AccessLog:[])
port=server.config[:Port]
server.mount_proc('/') do |req,res|
  case req.path
  when '/index.json'
    e=entry.dup
    if phase==:older
      e['version']='0.0.9';e['sha256']=Digest::SHA256.hexdigest(older)
    end
    res['Content-Type']='application/json'
    res.body=JSON.generate('entries'=>{'control-panel/blit'=>e},'apps'=>{'blit'=>e})
  when '/bundles/control-panel/blit.hibr'
    res.body=phase==:older ? older : source
  else
    res.status=404;res.body='not found'
  end
end
thread=Thread.new{server.start}
begin
  Dir.mktmpdir('blit-catalogue') do |root|
    env={'HOME'=>root,'XDG_CONFIG_HOME'=>File.join(root,'config'),'XDG_DATA_HOME'=>File.join(root,'data'),
         'XDG_CACHE_HOME'=>File.join(root,'cache'),'TMPDIR'=>root,'HIBR_HOLD'=>nil,
         'HIBR_APPS_URL'=>"http://127.0.0.1:#{port}/index.json"}
    run=->(*args) do
      out,err,st=Open3.capture3(env,'/usr/bin/catalogue',*args)
      abort("catalogue #{args.inspect} failed:#{out}\n#{err}") unless st.success?
      out
    end
    run.call('install','control-panel/blit')
    installed=File.join(root,'data/hibr/control-panel/blit.hibr')
    abort('older pane not installed in the catalogue scan root') unless File.binread(installed)==older
    phase=:current
    run.call('refresh')
    run.call('update','control-panel/blit')
    abort('catalogue update did not install canonical pane bytes') unless File.binread(installed)==source
    run.call('remove','control-panel/blit')
    abort('catalogue removal left the pane behind') if File.exist?(installed)
    puts 'BLIT_CATALOGUE_PASS install=0.0.9 update=0.1.0 canonical_sha256=verified remove=clean isolated_scope=yes'
  end
ensure
  server.shutdown;thread.join
end
