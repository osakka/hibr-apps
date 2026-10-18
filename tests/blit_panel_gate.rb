#!/usr/bin/env ruby
# Actual Hibr callbacks and bounded worker against the actual Blit API.
require 'json'
require 'net/http'
require 'tmpdir'
require 'open3'
require 'timeout'
require 'socket'
ROOT=File.expand_path('..',__dir__)
BLIT=ENV.fetch('BLIT_ROOT',File.expand_path('../../hw-manager',__dir__))
BINARY=ENV.fetch('BLIT_GATE_BINARY',File.join(BLIT,'build/blit/blit-server'))
PORT=Integer(ENV.fetch('BLIT_PANEL_GATE_PORT','19495'))
abort('panel gate port occupied') unless begin s=TCPServer.new('127.0.0.1',PORT);s.close;true;rescue Errno::EADDRINUSE;false;end
hang=TCPServer.new('127.0.0.1',0)
hang_port=hang.addr[1]
hang_worker=Thread.new do
  socket=hang.accept
  sleep 8
  socket.close
rescue IOError,Errno::EBADF
end
Dir.mktmpdir('blit-panel') do |root|
  Dir.mkdir(File.join(root,'input'))
  log=File.join(root,'server.log')
  env={'SDL_VIDEODRIVER'=>'dummy','BLIT_RENDERER'=>'software','BLIT_LOGIN_AUTOSTART'=>'0','BLIT_PANE_LAYOUT'=>'1x2',
       'BLIT_PSF_FONT'=>File.join(BLIT,'assets/fonts/Blit-Hibr-Terminus16.psf'),
       'BLIT_SETTINGS_PATH'=>File.join(root,'settings.json'),'BLIT_INPUT_ROOT'=>File.join(root,'input'),
       'BLIT_AUTH_TOKEN'=>'panel-test-token','LD_LIBRARY_PATH'=>File.join(BLIT,'build/sdl3-kms')}
  pid=spawn(env,BINARY,PORT.to_s,out:log,err:[:child,:out])
  begin
    Timeout.timeout(10) do
      loop do
        begin
          s=TCPSocket.new('127.0.0.1',PORT);s.close;break
        rescue Errno::ECONNREFUSED
          sleep 0.05
        end
      end
    end
    script=File.join(root,'test.hibr')
    File.write(script,<<~HIBR)
      strict
      source /usr/share/hibr/desktop/system/panel.hibr
      source '#{ROOT}/bundles/control-panel/blit.hibr'
      [ "${CP_PANES[blit][title]}" = Blit ] || { echo 'pane title is not Blit' >&2; exit 1; }
      BCP_TEST_WAKE=0
      fn dt_want(int ms) {
          [ "$BCP_TEST_WAKE" = 0 ] || [ "$ms" -ge "$BCP_TEST_WAKE" ] || BCP_TEST_WAKE=$ms
          [ "$BCP_TEST_WAKE" != 0 ] || BCP_TEST_WAKE=$ms
          return 0
      }
      fn finish() {
          local i=0
          while [ "$BCP_BUSY" = 1 ]; do
              blit_cp_poll
              /bin/sleep 0.02
              i=$((i + 1))
              [ "$i" -lt 800 ] || { echo 'worker never finished' >&2; exit 1; }
          done
      }
      BCP_URL='http://127.0.0.1:#{PORT}'
      BCP_TOKEN=panel-test-token
      blit_cp_start refresh
      finish
      [ "$BCP_BASE_REV" -ge 0 ] || { echo "refresh failed: $BCP_STATUS" >&2; exit 1; }
      n := blit_rows 44
      [ "$n" -gt 20 ] || { echo 'pane rows missing' >&2; exit 1; }
      # Old three-second polling launches here even though a quiet refresh
      # is not due. Actual API worker and callbacks, not source inspection.
      BCP_LAST=$((EPOCHSECONDS - 4))
      BCP_NEXT=$((EPOCHSECONDS + 15))
      BCP_TEST_WAKE=0
      before=$BCP_STATUS
      n := blit_rows 44
      [ "$BCP_BUSY" = 0 ] || { echo 'idle redraw launched early refresh' >&2; exit 20; }
      [ "$BCP_TEST_WAKE" -ge 14000 ] || { echo "idle wake too aggressive: $BCP_TEST_WAKE" >&2; exit 21; }
      BCP_NEXT=0
      BCP_TEST_WAKE=0
      n := blit_rows 44
      [ "$BCP_BUSY" = 1 ] && [ "$BCP_STATUS" = "$before" ] || { echo 'automatic refresh changed visible status' >&2; exit 22; }
      [ "$BCP_TEST_WAKE" = 250 ] || { echo 'busy wake differs from bounded polling' >&2; exit 23; }
      finish
      [ $((BCP_NEXT - EPOCHSECONDS)) -ge 14 ] || { echo 'refresh completion did not schedule idle deadline' >&2; exit 24; }
      BCP_NEXT=0
      n := blit_rows 999999
      [ "$BCP_BUSY" = 0 ] || { echo 'search scratch rows launched a request' >&2; exit 25; }
      BCP_NEXT=$((EPOCHSECONDS + 15))
      base=$BCP_BASE_REV
      output=${BCP_SNAPSHOT[displays][displays][0][name]}
      blit_cp_toggle "$output" 1
      [ "${BCP_DRAFT[auxiliary_displays][0][output]}" = "$output" ] || exit 2
      blit_do 44 apply 1
      finish
      [ "${BCP_LIVE[bindings][0][state]}" = waiting_authentication ] || { echo "apply failed: $BCP_STATUS" >&2; exit 3; }
      [ "$BCP_BASE_REV" = "$base" ] || { echo 'Apply changed saved revision' >&2; exit 4; }
      blit_do 44 save 1
      finish
      [ "$BCP_DIRTY" = 0 ] && [ "$BCP_BASE_REV" -gt "$base" ] || { echo "save failed: $BCP_STATUS" >&2; exit 5; }
      blit_cp_exported '#{root}/export.json'
      blit_cp_toggle "$output" 1
      blit_cp_imported '#{root}/export.json'
      [ "${BCP_DRAFT[auxiliary_displays][0][output]}" = "$output" ] && [ "$BCP_DIRTY" = 1 ] || exit 6
      BCP_BASE_REV=999999
      blit_do 44 save 1
      finish
      case "$BCP_STATUS" in 'HTTP 409:'*) ;; *) echo "conflict hidden: $BCP_STATUS" >&2; exit 7 ;; esac
      [ "$BCP_DIRTY" = 1 ] || { echo 'failed save destroyed draft' >&2; exit 8; }
      blit_do 44 reload 1
      finish
      blit_do 44 scale 1
      finish
      [ "${BCP_SNAPSHOT[fonts][active][scale]}" = 1.1 ] || { echo "scale failed: $BCP_STATUS" >&2; exit 9; }
      /bin/sleep 0.7
      blit_cp_start refresh
      finish
      BCP_DIRTY=1
      command chmod 0555 '#{root}'
      blit_do 44 save 1
      finish
      command chmod 0700 '#{root}'
      case "$BCP_STATUS" in 'HTTP 503:'*) ;; *) echo "save failure hidden: $BCP_STATUS" >&2; exit 12 ;; esac
      [ "$BCP_DIRTY" = 1 ] || { echo 'save failure discarded draft' >&2; exit 13; }
      BCP_FAILURES=0
      BCP_TOKEN=wrong-token
      blit_cp_start refresh
      finish
      case "$BCP_STATUS" in 'HTTP 401:'*) ;; *) echo "auth hidden: $BCP_STATUS" >&2; exit 10 ;; esac
      [ $((BCP_NEXT - EPOCHSECONDS)) -ge 14 ] || { echo 'first read failure lacks backoff' >&2; exit 26; }
      blit_cp_start refresh
      finish
      [ $((BCP_NEXT - EPOCHSECONDS)) -ge 29 ] || { echo 'second read failure lacks backoff' >&2; exit 27; }
      blit_cp_start refresh
      finish
      [ $((BCP_NEXT - EPOCHSECONDS)) -ge 59 ] || { echo 'third read failure lacks capped backoff' >&2; exit 28; }
      BCP_URL=invalid-url
      BCP_NEXT=0
      n := blit_rows 44
      count=$BCP_FAILURES
      n := blit_rows 44
      [ "$BCP_BUSY" = 0 ] && [ "$BCP_FAILURES" = "$count" ] || { echo 'invalid connection retries every redraw' >&2; exit 29; }
      BCP_URL='http://127.0.0.1:1'
      blit_cp_start refresh
      finish
      [ "$BCP_STATUS" = 'Offline or request timed out' ] || exit 11
      BCP_URL='http://127.0.0.1:#{hang_port}'
      before=$EPOCHREALTIME
      blit_cp_start refresh
      n := blit_rows 44
      printf 'CALLBACK_LATENCY:%s:%s\\n' "$before" "$EPOCHREALTIME"
      finish
      [ "$BCP_STATUS" = 'Offline or request timed out' ] || exit 14
      # Masking is a callback test; no terminal UI or screenshot is inferred.
      fn dt_wclear(...args) { return 0; }
      fn console(...args) { return 0; }
      fn dt_tput(...args) { return 0; }
      fn dt_textdraw(...args) { printf 'masked:%s\\n' "${args[4]}"; }
      fn dt_wreg(...args) { return 0; }
      fn dt_dlgbtns(...args) { return 0; }
      BCP_DIALOG[9][value]=secret-must-be-masked
      BCP_DIALOG[9][key]=token
      BCP_DIALOG[9][focus]=value
      BCP_DIALOG[9][cursor]=0
      blitconn_draw 9 9 64 0 0
      echo BLIT_PANEL_PASS
    HIBR
    out,err,st=Open3.capture3({'XDG_RUNTIME_DIR'=>root},'/usr/bin/hibr',script)
    abort("panel callbacks failed #{st}:\n#{out}\n#{err}\n#{File.read(log)}") unless st.success? && out.include?('BLIT_PANEL_PASS')
    abort('token leaked through dialog') if out.include?('secret-must-be-masked')
    timing=out.lines.find { |l| l.start_with?('CALLBACK_LATENCY:') }.split(':')[1,2].map(&:to_f)
    abort('network I/O blocked pane callbacks') unless timing[1]-timing[0]<0.25
    abort('token leaked through export') if File.read(File.join(root,'export.json')).include?('panel-test-token')
    document=JSON.parse(File.read(File.join(root,'export.json')))
    abort('export is not structured settings') unless document['auxiliary_displays'].is_a?(Array)
    puts 'BLIT_PANEL_PASS callbacks=actual_hibr api=actual_blit refresh=quiet_15s backoff=15_30_60 scratch=no_io apply_save=separate conflict=preserved auth=reported offline=reported scale=1.1 token=masked export=no_secrets'
  ensure
    File.chmod(0700,root)
    Process.kill('TERM',pid) rescue nil
    Timeout.timeout(10){Process.wait(pid)} rescue nil
  end
end
hang.close
hang_worker.kill
hang_worker.join
