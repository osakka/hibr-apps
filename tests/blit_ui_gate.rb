#!/usr/bin/env ruby
# Native Hibr UI libraries + the canonical catalogue pane, rendered by Blit.
# Isolated custom session uses Hibr's documented desktop library API; no core edits.
require 'json'
require 'net/http'
require 'tmpdir'
require 'timeout'
require 'fileutils'
require 'open3'
ROOT=File.expand_path('..',__dir__)
BLIT=ENV.fetch('BLIT_ROOT',File.expand_path('../../hw-manager',__dir__))
BINARY=ENV.fetch('BLIT_GATE_BINARY',File.join(BLIT,'build/blit/blit-server'))
EXPECTED_VERSION=ENV.fetch('BLIT_EXPECTED_VERSION'){File.read(File.join(BLIT,'packaging/VERSION')).strip}
PANE=ENV.fetch('BLIT_PANEL_UI_PANE','blit')
raise 'unsupported panel fixture' unless %w[blit blit_mouse].include?(PANE)
PORT=Integer(ENV.fetch('BLIT_PANEL_UI_PORT','19496'))
BASE=URI("http://127.0.0.1:#{PORT}")
def req(method,path,body=nil)
  q={'GET'=>Net::HTTP::Get,'POST'=>Net::HTTP::Post,'PUT'=>Net::HTTP::Put,'DELETE'=>Net::HTTP::Delete}.fetch(method).new(BASE+path)
  q['Content-Type']='application/json';q.body=JSON.generate(body) if body
  r=Net::HTTP.start(BASE.host,BASE.port,read_timeout:5){|h|h.request(q)}
  raise "HTTP #{r.code}:#{r.body}" unless r.code.start_with?('2')
  r.body.to_s.empty? ? nil : JSON.parse(r.body)
end
def await(message)
  Timeout.timeout(20,RuntimeError,"timeout:#{message}") do
    loop do
      begin
        v=yield;return v if v
      rescue Errno::ECONNREFUSED
      end
      sleep 0.05
    end
  end
end
Dir.mktmpdir('blit-panel-ui') do |root|
  output=ENV.fetch('BLIT_PANEL_UI_OUTPUT',root)
  FileUtils.mkdir_p(output)
  Dir.mkdir(File.join(root,'input'))
  script=File.join(root,'session.hibr')
  File.write(script,<<~HIBR)
    strict
    mod load img; mod load pty; mod load term; mod load hold
    source /usr/share/hibr/desktop/desktop.hibr
    source /usr/share/hibr/desktop/system/panel.hibr
    source '#{ROOT}/bundles/control-panel/blit.hibr'
    DT_TERMMS=0
    dt_open || exit 1
    id := dt_launch panel #{PANE}
    dt_run
    dt_close
  HIBR
  env={'SDL_VIDEODRIVER'=>'dummy','BLIT_RENDERER'=>'software','BLIT_LOGIN_AUTOSTART'=>'0','BLIT_AUTH_TOKEN'=>'',
       'BLIT_PSF_FONT'=>ENV.fetch('BLIT_GATE_FONT',File.join(BLIT,'assets/fonts/Blit-Hibr-Terminus16.psf')),
       'BLIT_SETTINGS_PATH'=>File.join(root,'settings.json'),'BLIT_INPUT_ROOT'=>File.join(root,'input'),
       'LD_LIBRARY_PATH'=>File.join(BLIT,'build/sdl3-kms')}
  log=File.join(root,'server.log')
  pid=spawn(env,BINARY,PORT.to_s,out:log,err:[:child,:out])
  session=nil
  begin
    await('server'){req('GET','/v1/version')}
    if ENV['BLIT_PANEL_UI_FONT']
      active=req('PUT','/v1/fonts',{font_id:ENV['BLIT_PANEL_UI_FONT'],size_px:16}).fetch('active')
      raise 'requested UI font was not selected' unless active['id']==ENV['BLIT_PANEL_UI_FONT']
    end
    session=req('POST','/v1/terminal-sessions',{'command'=>'/usr/bin/hibr','arguments'=>[script],
      'pane_id'=>'pane-display-1-1','environment'=>{'HOME'=>root,'XDG_CONFIG_HOME'=>File.join(root,'config'),
       'XDG_DATA_HOME'=>File.join(root,'data'),'TMPDIR'=>root,'XDG_RUNTIME_DIR'=>root,
       'BLIT_CP_URL'=>BASE.to_s,'DT_LOG'=>File.join(root,'desktop.log')}})
    surface="/v1/surfaces/#{session['surface_id']}/cells"
    text=-> do
      cells=req('GET',surface)['cells']
      cells.group_by{|c|c['y']}.sort.map{|_,row|row.sort_by{|c|c['x']}.map{|c|c['text']}.join}.join("\n")
    end
    # A font change reflows the pane: Blit resizes the grid, the desktop
    # redraws, and for a moment the cells are neither the old screen nor the
    # new one. A click aimed from such a frame lands on nothing (Gitea #362),
    # so every click waits for two reads of the cells and the grid, 150 ms
    # apart, to agree first -- and on a screen that is drawn, since two blank
    # reads agree too. What is left is Blit flipping between the live font
    # and the one its automatic save is still writing (itdlabs/blit, see
    # #362), which reflows the screen several times a second for a while.
    settle=->(why) do
      await("settled before #{why}") do
        a=[text.call,req('GET','/v1/topology')['panes'][0]['cell_grid']]
        sleep 0.15
        b=[text.call,req('GET','/v1/topology')['panes'][0]['cell_grid']]
        a==b && a[0].include?('Control Panel')
      end
    end
    snapshot=await('connected pane in actual Hibr UI'){t=text.call;t if t.include?("Connected: #{EXPECTED_VERSION}") && t.include?(PANE=='blit_mouse' ? 'Pointer Size' : 'Apply auxiliaries')}
    capture=->(name) do
      File.write(File.join(output,"#{name}.txt"),text.call)
      bmp=Net::HTTP.get(BASE+'/v1/diagnostics/screenshots/display-1')
      raise 'not a BMP' unless bmp.start_with?('BM')
      File.binwrite(File.join(output,"#{name}.bmp"),bmp)
      Open3.capture3('ffmpeg','-hide_banner','-loglevel','error','-y','-i',File.join(output,"#{name}.bmp"),File.join(output,"#{name}.png"))
    end
    capture.call('panel')
    # Real pointer press/held motion/release through Blit into the installed
    # Control Panel drag handler, not a direct call to the pane callback.
    drag=->(label,position) do
      settle.call("dragging #{label}")
      cells=req('GET',surface)['cells']
      row=cells.group_by{|c|c['y']}.find{|_,r|r.sort_by{|c|c['x']}.map{|c|c['text']}.join.include?(label)}
      raise "missing slider #{label}" unless row
      y=row[0]; track=row[1].select{|c|['●','─'].include?(c['text'])}.map{|c|c['x']}.min
      raise 'missing native slider track' unless track
      grid=req('GET','/v1/topology')['panes'][0]['cell_grid']
      move=->(column){req('POST','/v1/input/inject',{kind:'pointer_motion',x:grid['origin_x']+column*grid['cell_width']+grid['cell_width']/2,y:grid['origin_y']+y*grid['cell_height']+grid['cell_height']/2})}
      move.call(track)
      req('POST','/v1/input/inject',{kind:'pointer_button',button:0,pressed:true})
      move.call(track+position)
      req('POST','/v1/input/inject',{kind:'pointer_button',button:0,pressed:false})
    end
    input=->(bytes){req('POST',"/v1/terminal-sessions/#{session['id']}/input",{'data'=>bytes})}
    # A click on a dropdown must open the installed native menu, not step
    # to another value. Escape dismisses it without a settings mutation.
    dropdown=->(label,value,alternative,select=false) do
      settle.call("opening #{label}")
      cells=req('GET',surface)['cells']
      row=cells.group_by{|c|c['y']}.find{|_,r|r.sort_by{|c|c['x']}.map{|c|c['text']}.join.include?(label)}
      unless row
        File.write(File.join(output,'lookup.txt'),cells.group_by{|c|c['y']}.sort.map{|_,r|r.sort_by{|c|c['x']}.map{|c|c['text']}.join}.join("\n")+"\n#{cells.length} cells")
        raise "missing dropdown #{label}"
      end
      sorted=row[1].sort_by{|c|c['x']}
      offset=sorted.map{|c|c['text']}.join.index(value)
      raise "missing dropdown value #{value}" unless offset
      x=sorted[offset]['x']; grid=req('GET','/v1/topology')['panes'][0]['cell_grid']
      req('POST','/v1/input/inject',{kind:'pointer_motion',x:grid['origin_x']+x*grid['cell_width']+grid['cell_width']/2,y:grid['origin_y']+row[0]*grid['cell_height']+grid['cell_height']/2})
      req('POST','/v1/input/inject',{kind:'pointer_button',button:0,pressed:true})
      req('POST','/v1/input/inject',{kind:'pointer_button',button:0,pressed:false})
      await("native #{label} popup"){text.call.include?(alternative)}
      capture.call("dropdown-#{label.downcase.gsub(' ','-')}")
      if select
        settle.call("choosing #{alternative}")
        items=req('GET',surface)['cells'].group_by{|c|c['y']}
        item=items.find{|_,r|r.sort_by{|c|c['x']}.map{|c|c['text']}.join.include?(alternative)}
        chars=item[1].sort_by{|c|c['x']}
        column=chars[chars.map{|c|c['text']}.join.index(alternative)]['x']
        req('POST','/v1/input/inject',{kind:'pointer_motion',x:grid['origin_x']+column*grid['cell_width']+grid['cell_width']/2,y:grid['origin_y']+item[0]*grid['cell_height']+grid['cell_height']/2})
        req('POST','/v1/input/inject',{kind:'pointer_button',button:0,pressed:true})
        req('POST','/v1/input/inject',{kind:'pointer_button',button:0,pressed:false})
        await("selected #{alternative}") do
          text.call.lines.any?{|line|line.include?(label) && line.include?(alternative)}
        end
        next
      end
      input.call("\e")
      await("dismiss #{label} popup"){!text.call.include?(alternative)}
    end
    if PANE=='blit_mouse'
      before=req('GET','/v1/settings')
      dropdown.call('Shape','arrow','precision')
      raise 'opening/dismissing popup changed settings' unless req('GET','/v1/settings')==before
      dropdown.call('Shape','arrow','precision',true)
      raise 'selection saved staged settings prematurely' unless req('GET','/v1/settings')==before
      drag.call('Pointer Size',10)
      await('native pointer size drag'){text.call.include?('Pointer Size (64 px)')}
      capture.call('pointer-size-dragged')
      cells=req('GET',surface)['cells']
      row=cells.group_by{|c|c['y']}.find{|_,r|r.sort_by{|c|c['x']}.map{|c|c['text']}.join.include?('Save all staged Blit')}
      raise 'save action missing' unless row
      label=row[1].sort_by{|c|c['x']}; x=label.find{|c|c['text']=='S'}['x']
      grid=req('GET','/v1/topology')['panes'][0]['cell_grid']
      req('POST','/v1/input/inject',{kind:'pointer_motion',x:grid['origin_x']+(x+5)*grid['cell_width'],y:grid['origin_y']+row[0]*grid['cell_height']+grid['cell_height']/2})
      # Native actions select on the first click and activate on the next.
      2.times do
        req('POST','/v1/input/inject',{kind:'pointer_button',button:0,pressed:true})
        req('POST','/v1/input/inject',{kind:'pointer_button',button:0,pressed:false})
      end
      await('mouse pane actual save action'){req('GET','/v1/settings').dig('effective','pointer','size_px')==64}
      raise 'popup selected next option instead of precision' unless req('GET','/v1/settings').dig('effective','pointer','shape')=='precision'
      capture.call('mouse-saved')
      puts "BLIT_MOUSE_UI_PASS library=installed_hibr renderer=sdl_software pane=shared_bundle size=actual_pointer64 save=actual_click screenshots=#{output}"
    else
    input.call("\r")
    await('connection dialog from real keyboard input'){text.call.include?('Blit Connection')}
    capture.call('connection')
    input.call("\e")
    await('dialog close'){!text.call.include?('Blit Connection')}
    input.call("\e[B")
    input.call("\r")
    await('token dialog from real keyboard input'){text.call.include?('API Token:')}
    input.call('secret-must-be-masked')
    await('masked UI text'){text.call.include?('********************')}
    raise 'token visible in terminal cells' if text.call.include?('secret-must-be-masked')
    capture.call('token-masked')
    input.call("\e")
    await('masked dialog close'){!text.call.include?('Blit Connection')}
    drag.call('Columns',10)
    await('native columns drag'){text.call.include?('Columns (8)')}
    drag.call('Rows (',3)
    await('native rows drag'){text.call.include?('Rows (3)')}
    capture.call('grid-sliders-dragged')
    drag.call('Font size (',2)
    await('native pixel size drag and font reflow'){req('GET','/v1/fonts').dig('active','size_px')==19 && text.call.include?('Font size (19 px)')}
    capture.call('font-size-slider-dragged')
    input.call("\e[C")
    await('one pixel keyboard increase'){req('GET','/v1/fonts').dig('active','size_px')==20 && text.call.include?('Font size (20 px)')}
    input.call("\e[D")
    await('one pixel keyboard decrease'){req('GET','/v1/fonts').dig('active','size_px')==19 && text.call.include?('Font size (19 px)')}
    capture.call('font-size-keyboard-step')
    dropdown.call('Fallback','first_available','wait')
    puts "BLIT_UI_PASS library=installed_hibr renderer=sdl_software font=#{req('GET','/v1/fonts').dig('active','id')} panel=connected drag=actual_pointer_columns8_rows3_font19px keyboard=font_plus_minus_1px token=masked screenshots=#{output}"
    end
  rescue Exception
    File.write(File.join(output,'failure.txt'),text.call) rescue nil
    warn File.read(log) if File.exist?(log)
    warn File.read(File.join(root,'desktop.log')) if File.exist?(File.join(root,'desktop.log'))
    warn req('GET',surface).to_json[0,3000] rescue nil
    raise
  ensure
    req('DELETE',"/v1/terminal-sessions/#{session['id']}") if session
    Process.kill('TERM',pid) rescue nil
    Timeout.timeout(10){Process.wait(pid)} rescue nil
  end
end
