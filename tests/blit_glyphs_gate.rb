#!/usr/bin/env ruby
# Blit Glyphs (control-panel/blitglyphs.hibr): the real pane, its rows built
# by the panel's own cp_rowsbuild and its rows worked by the panel's own
# calls (the pane's _do through dt_prefixfn, a dropdown through cp_rowset),
# in the installed Hibr, against a real blit-server built from BLIT_ROOT and
# against Blit 0.3.133, which has no glyph sets. What the rows say is
# compared here with what this gate reads from Blit itself, so the pane is
# never checked against its own reading.
#
#   BLIT_ROOT                 the Blit tree (default ../../hw-manager)
#   BLIT_GATE_BINARY          its blit-server (default BLIT_ROOT/build/blit/blit-server)
#   BLIT_GLYPHS_OLD_BINARY    a 0.3.133 blit-server; otherwise built once from
#                             releases/0.3.133.yaml's source_commit (git archive,
#                             tools/build-tcc.sh) and kept in the temporary folder
#   BLIT_GLYPHS_OLD_FONTS     its fonts root (default the archive's, or BLIT_ROOT's)
#   BLIT_GLYPHS_OLD_IME_ROOT  hibr-ime for that build (default
#                             BLIT_ROOT/build/hibr-ime-<its packaging/IME_VERSION>)
#   HIBR_BIN, HIBR_DESKTOP    which Hibr runs the pane (default the installed one)
require 'json'
require 'fileutils'
require 'net/http'
require 'tmpdir'
require 'open3'
require 'timeout'
require 'socket'
ROOT=File.expand_path('..',__dir__)
BUNDLE=ENV.fetch('BLIT_GLYPHS_BUNDLE',File.join(ROOT,'bundles/control-panel/blitglyphs.hibr'))
# The Blit pane, sourced beside it as the desktop sources every pane into
# one process: the two share no name, and the token is the one it saved.
BLIT_PANE=File.join(ROOT,'bundles/control-panel/blit.hibr')
BLIT=ENV.fetch('BLIT_ROOT',File.expand_path('../../hw-manager',__dir__))
HIBR=ENV.fetch('HIBR_BIN','/usr/bin/hibr')
HIBR_DESKTOP=ENV.fetch('HIBR_DESKTOP','/usr/share/hibr/desktop')
require File.join(BLIT,'tools/tests/gate_server')
BINARY=ENV.fetch('BLIT_GATE_BINARY',File.join(BLIT,'build/blit/blit-server'))
PORT=Integer(ENV.fetch('BLIT_GLYPHS_GATE_PORT','19640'))
OLD_PORT=Integer(ENV.fetch('BLIT_GLYPHS_GATE_OLD_PORT','19641'))
TOKEN='glyphs-test-token'
[PORT,OLD_PORT].each do |p|
  abort("glyphs gate port #{p} occupied") unless begin s=TCPServer.new('127.0.0.1',p);s.close;true;rescue Errno::EADDRINUSE;false;end
end
abort("no blit-server at #{BINARY}") unless File.executable?(BINARY)

# Blit 0.3.133, the release before glyph sets: given, or built from its
# source commit aside from any checkout, once per commit.
def old_server
  if (given=ENV['BLIT_GLYPHS_OLD_BINARY'])
    return [given,ENV.fetch('BLIT_GLYPHS_OLD_FONTS',File.join(BLIT,'assets/fonts'))]
  end
  commit=File.read(File.join(BLIT,'releases/0.3.133.yaml'))[/^source_commit:\s*([0-9a-f]{40})\s*$/,1]
  abort('releases/0.3.133.yaml names no source_commit') unless commit
  cache=File.join(Dir.tmpdir,"blit-glyphs-gate-#{Process.uid}-0.3.133-#{commit[0,12]}")
  bin=File.join(cache,'out/blit-server')
  fonts=ENV.fetch('BLIT_GLYPHS_OLD_FONTS',File.join(cache,'src/assets/fonts'))
  return [bin,fonts] if File.executable?(bin) && File.directory?(fonts)
  FileUtils.rm_rf(cache)
  src=File.join(cache,'src')
  FileUtils.mkdir_p(src)
  ok=system("git -C '#{BLIT}' archive #{commit} | tar -x -C '#{src}'")
  abort("git archive of 0.3.133 (#{commit}) failed") unless ok
  ime=File.read(File.join(src,'packaging/IME_VERSION')).strip
  ime_root=ENV.fetch('BLIT_GLYPHS_OLD_IME_ROOT',File.join(BLIT,"build/hibr-ime-#{ime}"))
  log=File.join(cache,'build.log')
  ok=system({'BLIT_IME_ROOT'=>ime_root},'nice','-n','19',File.join(src,'tools/build-tcc.sh'),bin,'server',
            chdir:src,out:log,err:[:child,:out])
  abort("building blit-server 0.3.133 failed:\n#{File.read(log)[-2000..] || File.read(log)}") unless ok
  [bin,fonts]
end

def start_server(binary,port,fonts,dir)
  FileUtils.mkdir_p(File.join(dir,'input'))
  env={**gate_display_env,'BLIT_LOGIN_AUTOSTART'=>'0',
       'BLIT_PSF_FONT'=>File.join(fonts,'Blit-Terminus16.psf'),'BLIT_FONT_ROOT'=>fonts,
       'BLIT_SETTINGS_PATH'=>File.join(dir,'settings.json'),'BLIT_INPUT_ROOT'=>File.join(dir,'input'),
       'BLIT_AUTH_TOKEN'=>TOKEN}
  pid=spawn(env,binary,port.to_s,out:File.join(dir,'server.log'),err:[:child,:out])
  Timeout.timeout(10) do
    loop do
      begin
        TCPSocket.new('127.0.0.1',port).close;break
      rescue Errno::ECONNREFUSED
        sleep 0.05
      end
    end
  end
  pid
end

def api(port,path)
  r=Net::HTTP.start('127.0.0.1',port){|h| h.get(path,'Authorization'=>"Bearer #{TOKEN}")}
  abort("GET #{path}: #{r.code}") unless r.code=='200'
  JSON.parse(r.body)
end

# The rows each dump printed, by its tag: [{kind,key,text,val,after}].
def rows_of(out)
  rows=Hash.new{|h,k| h[k]=[]}
  out.each_line do |l|
    next unless l.start_with?("ROW\t")
    _,tag,kind,key,text,val,after=l.chomp.split("\t",-1)
    # What a person reads as the label: the label, then what follows it.
    rows[tag] << {kind:kind,key:key,text:text,val:val,after:after,label:[text,after].reject(&:empty?).join(' ')}
  end
  rows
end

def glyph(cp)
  [cp.to_i(16)].pack('U')
end

def check(ok,what)
  abort("FAIL: #{what}") unless ok
end

# The hibr that runs the pane: the desktop's seam, the panel and its rows,
# the job runner and the one-line question, as the Blit pane's gate loads
# them, then the bundle(s).
def preamble(with_blit_pane)
  rows=File.join(HIBR_DESKTOP,'widgets/rows.hibr')
  <<~HIBR
    strict
    source #{HIBR_DESKTOP}/wm/seam.hibr
    source #{HIBR_DESKTOP}/wm/rtwire.hibr
    source #{HIBR_DESKTOP}/wm/names.hibr
    source #{HIBR_DESKTOP}/wm/settings.hibr
    #{File.exist?(File.join(HIBR_DESKTOP,'wm/glyphs.hibr')) ? "source #{HIBR_DESKTOP}/wm/glyphs.hibr" : ''}
    source #{HIBR_DESKTOP}/system/panel.hibr
    #{File.exist?(rows) ? "source #{rows}" : ''}
    source #{HIBR_DESKTOP}/widgets/search.hibr
    source #{HIBR_DESKTOP}/wm/jobs.hibr
    source #{HIBR_DESKTOP}/wm/ask.hibr
    #{with_blit_pane ? "source '#{BLIT_PANE}'" : ''}
    source '#{BUNDLE}'
    fn dt_want(int ms) { return 0; }
    # The panel's own build of the pane's rows, each printed for the gate.
    fn dump(tag) {
        local n i
        n := cp_rowsbuild 44 blit_glyphs
        for ((i = 0; i < n; i++)); do
            printf 'ROW\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n' "$tag" "${CP[44][$i][kind]}" "${CP[44][$i][key]}" \\
                "${CP[44][$i][text]}" "${CP[44][$i][val]}" "${CP[44][$i][after]-}"
        done
    }
    # Every request in flight, and every one waiting, done.
    fn finish() {
        local i=0
        while [ "$BGS_BUSY" = 1 ] || { [ "$BGS_STATE" = ok ] && [ -n "$BGS_WANTPAGE$BGS_WANTFIND" ]; }; do
            blit_gs_poll
            blit_gs_kick
            /bin/sleep 0.02
            i=$((i + 1))
            [ "$i" -lt 800 ] || { echo 'a request never finished' >&2; exit 1; }
        done
    }
    # A row worked as the panel works it: an action's key to the pane's _do.
    fn press(key) { dt_prefixfn blit_glyphs do 44 "$key" 1; }
    # The dropdown keyed key, set to v through the panel (cp_rowset).
    fn choose(key, v) {
        local n i
        n := cp_rowsbuild 44 blit_glyphs
        for ((i = 0; i < n; i++)); do
            if [ "${CP[44][$i][key]}" = "$key" ]; then
                [ "${CP[44][$i][set]}" = blit_gs_choose ] || { echo "row $key declares no list" >&2; exit 97; }
                cp_rowset 44 "$i" "$v"; return 0
            fi
        done
        echo "no row $key" >&2; exit 98
    }
    # The one-line question, answered as typed.
    BGS_TEST_TYPE=
    BGS_TEST_ASKED=
    fn dt_ask(title, label, value, then, ...rest) {
        BGS_TEST_ASKED=$label
        dt_appfn "" "$then" "$BGS_TEST_TYPE" 9
    }
    fn look(q) { BGS_TEST_TYPE=$q; press find; finish; }
    fn again() { BGS_NEXT=0; blit_gs_kick; finish; }
  HIBR
end

hang=TCPServer.new('127.0.0.1',0)
hang_port=hang.addr[1]
hang_worker=Thread.new do
  loop do
    socket=hang.accept
    Thread.new(socket){|s| sleep 8; s.close rescue nil}
  end
rescue IOError,Errno::EBADF
end
old_bin,old_fonts=old_server
pids=[]
Dir.mktmpdir('blit-glyphs') do |root|
  begin
    pids << start_server(BINARY,PORT,File.join(BLIT,'assets/fonts'),File.join(root,'new'))
    pids << start_server(old_bin,OLD_PORT,old_fonts,File.join(root,'old'))
    url="http://127.0.0.1:#{PORT}"
    sets=api(PORT,'/v1/fonts/sets')['sets']
    fonts=api(PORT,'/v1/fonts')
    version=api(PORT,'/v1/version')['server_version']
    blit1=api(PORT,'/v1/fonts/sets/blit?limit=128')
    blit2=api(PORT,"/v1/fonts/sets/blit?limit=128&after=#{blit1['names'].last['name']}")
    dev1=api(PORT,'/v1/fonts/sets/nerd-dev?limit=128')
    old_version=api(OLD_PORT,'/v1/version')['server_version']
    check(blit1['more']==true && blit1['names'].size==128 && blit2['names'].size==128,'Blit serves blit in pages of 128')
    check(old_version=='0.3.133',"the older Blit is 0.3.133, not #{old_version}")

    # One process with the Blit pane beside this one: no connection, then
    # the token saved by the Blit pane's own code, then every reading.
    script=File.join(root,'main.hibr')
    File.write(script,preamble(true)+<<~HIBR)
      [ "${CP_PANES[blit_glyphs][title]}" = "Blit Glyphs" ] || { echo 'pane title is not Blit Glyphs' >&2; exit 2; }
      [ "${CP_PANES[blit_glyphs][group]}" = hardware ] || { echo 'pane is not in the hardware group' >&2; exit 2; }
      icon=${CP_PANES[blit_glyphs][iconsaid]-${CP_PANES[blit_glyphs][icon]}}
      [ "$icon" = "@blit:▦" ] || { echo "pane icon said is $icon" >&2; exit 2; }
      [ "${CP_PANES[blit][title]}" = Blit ] || { echo 'the Blit pane is not beside it' >&2; exit 2; }
      # The desktop restores the Blit pane's server before any pane draws.
      BCP_URL='#{url}'
      # No connection saved: the setup row, and no request at all.
      dump none
      [ "$BGS_BUSY" = 0 ] && [ "$BGS_CONN" = none ] || { echo 'a request without a connection' >&2; exit 3; }
      # The search's scratch rows start nothing either.
      BCP_TOKEN=#{TOKEN}
      blit_cp_credentials 0 || exit 4
      BGS_NEXT=0
      n := blit_glyphs_rows 999999
      [ "$BGS_BUSY" = 0 ] || { echo 'scratch rows started a request' >&2; exit 5; }
      # Saved by the Blit pane: read on the next draw, in the background.
      dump first
      [ "$BGS_BUSY" = 1 ] || { echo "no read started: $BGS_STATUS" >&2; exit 6; }
      finish
      [ "$BGS_STATE" = ok ] || { echo "read failed: $BGS_STATUS" >&2; exit 7; }
      dump sets
      # A set chosen from the Browse list: its first page, then the next,
      # then back.
      choose browse blit
      finish
      dump blit1
      # One frame's build with a page of 128 names held, timed.
      before=$EPOCHREALTIME
      n := cp_rowsbuild 44 blit_glyphs
      printf 'BUILD\t%s\t%s\t%s\n' "$before" "$EPOCHREALTIME" "$n"
      press next
      finish
      dump blit2
      press prev
      finish
      dump blit1again
      # A set chosen from its own row.
      press set:nerd-dev
      finish
      dump dev1
      # Names looked up.
      look blit/bluetooth
      [ "$BGS_TEST_ASKED" = "Set and name:" ] || { echo "asked $BGS_TEST_ASKED" >&2; exit 8; }
      dump blitbt
      look nerd-fa/bluetooth
      dump fabt
      look blit/no-such-name
      dump unknown
      look blit/wifi-1
      dump deprecated
      look aws
      dump bare
      look 'Blit/Bluetooth'
      dump malformed
      # The token refused.
      BCP_TOKEN=wrong-token
      blit_cp_credentials 0 || exit 4
      again
      dump refused
      # The Blit pane pointed at another server, whose token is not saved.
      BCP_URL='http://127.0.0.1:1'
      again
      dump otherserver
      # Offline.
      BCP_TOKEN=#{TOKEN}
      blit_cp_credentials 0 || exit 4
      again
      dump offline
      # A server that never answers: drawing goes on while it waits.
      BCP_URL='http://127.0.0.1:#{hang_port}'
      blit_cp_credentials 0 || exit 4
      BGS_NEXT=0
      before=$EPOCHREALTIME
      dump hanging
      dump hanging2
      printf 'LATENCY\\t%s\\t%s\\n' "$before" "$EPOCHREALTIME"
      [ "$BGS_BUSY" = 1 ] || { echo 'no read in flight against the hanging server' >&2; exit 9; }
      finish
      dump timedout
      echo BLIT_GLYPHS_MAIN_DONE
    HIBR
    out,err,st=Open3.capture3({'XDG_RUNTIME_DIR'=>root,'XDG_CONFIG_HOME'=>File.join(root,'config')},HIBR,script)
    abort("pane script failed #{st}:\n#{out[-3000..]||out}\n#{err}") unless st.success? && out.include?('BLIT_GLYPHS_MAIN_DONE')
    abort("pane script complained:\n#{err}") unless err.strip.empty?
    rows=rows_of(out)
    find=->(tag,key){ rows[tag].find{|r| r[:key]==key} }

    # No connection: the row an absent pane has, saying where to set it up.
    check(rows['none'][0][:kind]=='head' && rows['none'][0][:text]=='Blit is not connected','no connection: the heading')
    check(find.('none','setup')&.dig(:text)=='Set up the server and API token in the Blit pane','no connection: the setup row')
    check(rows['none'].size==2,'no connection: nothing else')

    # The summary, the text fonts, the faces and every set, as Blit says.
    r=rows['sets']
    val=->(text){ r.find{|x| x[:text]==text}&.dig(:val) }
    check(val.('Blit')==version,'summary: Blit version')
    check(val.('Text fonts')==fonts['profiles'].size.to_s,'summary: text fonts')
    check(val.('Faces')==fonts['registry'].size.to_s,'summary: faces')
    check(val.('Glyph sets')==sets.size.to_s,'summary: glyph sets')
    check(find.('sets','status')[:text]=="Connected: Blit #{version}",'status: connected')
    active=fonts['profiles'].find{|p| p['id']==fonts['active']['id']}
    check(r.any?{|x| x[:label]=="#{active['title']} (#{active['id']})" && x[:val]=="#{fonts['active']['size_px']} px"},'the text font in use')
    fonts['profiles'].each do |p|
      x=find.('sets',"font:#{p['id']}")
      check(x && x[:text].empty? && x[:label].start_with?("#{p['title']} (#{p['id']}") && x[:val].start_with?(p['source']),"text font #{p['id']}")
    end
    fonts['registry'].each do |f|
      x=find.('sets',"face:#{f['id']}")
      want=f['family'] ? "#{f['family']} (#{f['id']})" : f['id']
      check(x && x[:text].empty? && x[:val]==f['role'] && x[:label]==want,"face #{f['id']} by its role")
    end
    set_rows=r.select{|x| x[:key].start_with?('set:')}
    check(set_rows.size==sets.size,"#{set_rows.size} set rows for #{sets.size} sets")
    sets.each_with_index do |s,i|
      x=set_rows[i]
      check(x[:key]=="set:#{s['id']}" && x[:text].empty?,"set #{s['id']} in Blit's order")
      check(x[:val]==(s['count']==1 ? '1 name' : "#{s['count']} names"),"set #{s['id']}: #{x[:val]} for #{s['count']}")
      check(x[:label].start_with?("#{s['id']} (#{s['owner']}, #{s['scope']}, "),"set #{s['id']}: owner and scope")
    end
    browse=find.('sets','browse')
    check(browse && browse[:kind]=='set' && browse[:val]=='none','the Browse list, nothing browsed')
    check(r.any?{|x| x[:text].start_with?('Installing and removing sets come later')},'installing: the row that explains it')

    # Pages: the names, in order, each its glyph and codepoint, as Blit pages them.
    page_ok=->(tag,page){
      names=rows[tag].select{|x| x[:key].start_with?('name:')}
      check(names.map{|x| x[:label].split(' ').first}==page['names'].map{|n| n['name']},"#{tag}: the names Blit pages")
      check(names.all?{|x| x[:text].empty?},"#{tag}: a name is never a label the catalogue translates")
      names.zip(page['names']).each do |x,n|
        want="#{n['codepoints'].map{|c| glyph(c)}.join} #{n['codepoints'].map{|c| "U+#{c.upcase}"}.join(' ')}"
        check(x[:val]==want,"#{tag}: #{n['name']} is #{x[:val].inspect}, not #{want.inspect}")
        check(x[:label]=="#{n['name']} (alias of #{n['alias_of']})","#{tag}: #{n['name']} marked an alias") if n['alias_of']
      end
    }
    page_ok.('blit1',blit1)
    page_ok.('blit2',blit2)
    page_ok.('blit1again',blit1)
    page_ok.('dev1',dev1)
    check(find.('blit1','page')[:val]=='1-128' && find.('blit2','page')[:val]=='129-256','page numbers')
    check(find.('blit1','next') && !find.('blit1','prev') && find.('blit2','prev'),'next and previous page rows')
    check(find.('blit1','browse')[:val]=='blit' && find.('dev1','browse')[:val]=='nerd-dev','the Browse list follows the set')
    check(rows['dev1'].any?{|x| x[:label]=='aws (alias of amazonwebservices)'},'an alias is marked')

    # Lookups.
    found=->(tag){ find.(tag,'found') }
    check(found.('blitbt')[:label]=='blit/bluetooth' && found.('blitbt')[:val]=="#{glyph('101006')} U+101006",'blit/bluetooth is U+101006')
    check(found.('fabt')[:label]=='nerd-fa/bluetooth' && found.('fabt')[:val]=="#{glyph('f293')} U+F293",'nerd-fa/bluetooth is U+F293')
    check(found.('unknown')[:label]=='blit/no-such-name' && found.('unknown')[:val]=='unknown name','an unknown name says so')
    check(found.('deprecated')[:label]=='blit/wifi-1 (deprecated, use cellular-1)','a deprecated name and its replacement')
    check(found.('bare')[:label]=='nerd-dev/aws (alias of amazonwebservices)','a bare name, in the set browsed')
    check(found.('malformed')[:val]=='not a set and name','an address Blit would refuse is not sent')

    # Failures.
    check(find.('refused','status')[:text].include?('HTTP 401'),"401: #{find.('refused','status')[:text]}")
    check(find.('otherserver','setup') && rows['otherserver'].any?{|x| x[:text]=="The Blit pane's server has no saved token"},'another server: the setup row')
    check(find.('offline','status')[:text]=='Offline or request timed out','offline')
    check(find.('timedout','status')[:text]=='Offline or request timed out','a server that never answers times out')
    t=out.lines.find{|l| l.start_with?("LATENCY\t")}.split("\t")[1,2].map(&:to_f)
    check(t[1]-t[0]<0.25,"drawing waited on the network (#{t[1]-t[0]} s)")
    bt=out.lines.find{|l| l.start_with?("BUILD\t")}.split("\t")
    build_s=bt[2].to_f-bt[1].to_f
    check(build_s<0.1,"one build of #{bt[3].strip} rows took #{build_s} s")

    # Blit 0.3.133, with this bundle alone and a connection file written by
    # hand: its fonts, and the glyph sets row that says what they need.
    old_fonts_api=api(OLD_PORT,'/v1/fonts')
    cfg=File.join(root,'oldconfig/hibr/blit')
    FileUtils.mkdir_p(cfg,mode:0o700)
    File.chmod(0o700,File.dirname(cfg),cfg)
    File.write(File.join(cfg,'connection.json'),JSON.generate('url'=>"http://127.0.0.1:#{OLD_PORT}",'token'=>TOKEN))
    File.chmod(0o600,File.join(cfg,'connection.json'))
    old_script=File.join(root,'old.hibr')
    File.write(old_script,preamble(false)+<<~HIBR)
      [ -z "${BCP_URL-}" ] || { echo 'the Blit pane is loaded' >&2; exit 2; }
      dump start
      finish
      [ "$BGS_STATE" = old ] || { echo "not seen as an older Blit: $BGS_STATE $BGS_STATUS" >&2; exit 3; }
      dump old
      press set:blit
      look blit/bluetooth
      dump oldpressed
      echo BLIT_GLYPHS_OLD_DONE
    HIBR
    out,err,st=Open3.capture3({'XDG_RUNTIME_DIR'=>root,'XDG_CONFIG_HOME'=>File.join(root,'oldconfig')},HIBR,old_script)
    abort("old pane script failed #{st}:\n#{out[-3000..]||out}\n#{err}") unless st.success? && out.include?('BLIT_GLYPHS_OLD_DONE')
    abort("old pane script complained:\n#{err}") unless err.strip.empty?
    rows=rows_of(out)
    o=rows['old']
    check(find.('old','status')[:text]=='Connected: Blit 0.3.133, without glyph sets','older Blit: status')
    check(find.('old','old')&.dig(:text)=='Glyph sets need Blit 0.3.134 or newer' && find.('old','old')[:after]=='(this is 0.3.133)','older Blit: the needs row')
    check(o.none?{|x| x[:key].start_with?('set:') || x[:key]=='browse' || x[:key]=='find'},'older Blit: no set, browse or lookup rows')
    check(o.count{|x| x[:key].start_with?('face:')}==old_fonts_api['registry'].size,'older Blit: its faces')
    check(rows['oldpressed'].none?{|x| x[:key].start_with?('name:') || x[:key]=='found'},'older Blit: nothing browsed or looked up')

    puts "BLIT_GLYPHS_PASS hibr=#{HIBR} blit=#{version} sets=#{sets.size}_rows_and_counts pages=blit_1+2+back,nerd-dev_1 " \
         "lookup=blit/bluetooth=U+101006,nerd-fa/bluetooth=U+F293,unknown,deprecated,alias,malformed " \
         "older=0.3.133_needs_0.3.134 none=setup_row other_server=setup_row auth=401 offline=reported " \
         "draw=no_io_wait(#{format('%.3f',t[1]-t[0])}s) build=#{bt[3].strip}_rows_in_#{format('%.3f',build_s)}s scratch=no_io"
  ensure
    pids.each{|p| Process.kill('TERM',p) rescue nil}
    pids.each{|p| Timeout.timeout(10){Process.wait(p)} rescue nil}
  end
end
hang.close
hang_worker.kill
hang_worker.join
