#!/usr/bin/env ruby
# Actual Hibr callbacks and bounded worker against the actual Blit API.
require 'json'
require 'net/http'
require 'tmpdir'
require 'open3'
require 'timeout'
require 'socket'
ROOT=File.expand_path('..',__dir__)
BUNDLE=ENV.fetch('BLIT_PANEL_BUNDLE',File.join(ROOT,'bundles/control-panel/blit.hibr'))
BLIT=ENV.fetch('BLIT_ROOT',File.expand_path('../../hw-manager',__dir__))
# Blit's own mocked display (native KMS on its DRM mock; ADR 0184).
require File.join(BLIT,'tools/tests/gate_server')
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
  env={**gate_display_env,'BLIT_LOGIN_AUTOSTART'=>'0','BLIT_PANE_LAYOUT'=>'1x2',
       'BLIT_PSF_FONT'=>File.join(BLIT,'assets/fonts/Blit-Hibr-Terminus16.psf'),
       'BLIT_SETTINGS_PATH'=>File.join(root,'settings.json'),'BLIT_INPUT_ROOT'=>File.join(root,'input'),
       'BLIT_AUTH_TOKEN'=>'panel-test-token'}
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
      source /usr/share/hibr/desktop/wm/settings.hibr
      source /usr/share/hibr/desktop/system/panel.hibr
      source /usr/share/hibr/desktop/wm/jobs.hibr
      source /usr/share/hibr/desktop/wm/ask.hibr
      source '#{BUNDLE}'
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
      blit_cp_credentials 0 || exit 40
      blit_cp_start refresh
      finish
      [ "$BCP_BASE_REV" -ge 0 ] || { echo "refresh failed: $BCP_STATUS" >&2; exit 1; }
      BCP_DROP_KEY[44]=primary
      blit_cp_selected 44 "${BCP_SNAPSHOT[topology][panes][0][id]}"
      [ "${BCP_DRAFT[login][preferred_pane_id]}" = "${BCP_SNAPSHOT[topology][panes][0][id]}" ] || exit 55
      blit_cp_selected 44 auto
      [ "${BCP_DRAFT[login][preferred_pane_id]}" = null ] || exit 56
      blit_cp_choose fallback wait
      blit_cp_choose fallback invalid
      [ "${BCP_DRAFT[login][fallback]}" = wait ] || exit 57
      blit_cp_choose fallback first_available
      n := blit_rows 44
      [ "$n" -gt 20 ] || { echo 'pane rows missing' >&2; exit 1; }
      i=0; sliders=0
      while [ "$i" -lt "$n" ]; do
          [ "${CP[44][$i][wtype]}" != slider ] || sliders=$((sliders + 1))
          i=$((i + 1))
      done
      # Font size, columns and rows, then corners and scanlines for each of
      # the gate server's two panes.
      [ "$sliders" = 7 ] || { echo "font size/columns/rows/effects must use native sliders ($sliders)" >&2; exit 30; }
      i=0; font_size_found=0
      while [ "$i" -lt "$n" ]; do
          [ "${CP[44][$i][key]}" != font_size ] || font_size_found=1
          i=$((i + 1))
      done
      [ "$font_size_found" = 1 ] || { echo 'pixel font size control missing' >&2; exit 41; }
      expected_source=${BCP_SNAPSHOT[settings][effective][presentation_configuration][backend_source]:-"Not reported by server"}
      i=0; source_found=0; sdl_rows=0
      while [ "$i" -lt "$n" ]; do
          if [ "${CP[44][$i][text]}" = "Backend source" ]; then
              [ "${CP[44][$i][val]}" = "$expected_source" ] || exit 51
              source_found=1
          fi
          case "${CP[44][$i][text]}" in
          "SDL video driver"|"Active renderer"|"Requested backend"|"Restart required") sdl_rows=$((sdl_rows + 1)) ;;
          esac
          i=$((i + 1))
      done
      # Blit 0.2.22 (ADR 0184): native KMS only, so no SDL renderer/driver rows.
      [ "$source_found" = 1 ] && [ "$sdl_rows" = 0 ] || exit 52
      provenance := json get BCP_SNAPSHOT .settings.effective.presentation_configuration
      json parse 'BCP_SNAPSHOT[settings][effective][presentation_configuration]' '{"backend_source":"saved-settings","backend_environment_valid":false}'
      n := blit_rows 999999
      i=0; invalid_found=0
      while [ "$i" -lt "$n" ]; do
          if [ "${CP[999999][$i][text]}" = "Startup default" ]; then
              [ "${CP[999999][$i][val]}" = "Invalid; display disabled" ] || exit 53
              invalid_found=1
          fi
          i=$((i + 1))
      done
      [ "$invalid_found" = 1 ] || exit 54
      json parse 'BCP_SNAPSHOT[settings][effective][presentation_configuration]' "$provenance"
      # Rendering: what draws each display, from the diagnostics the
      # snapshot carries. The gate server's mocked display composes on the
      # CPU, so the other states are injected the same way as above.
      rendering := json get BCP_SNAPSHOT .diagnostics.render.outputs
      json parse 'BCP_SNAPSHOT[diagnostics][render][outputs]' '[{"display_id":"display-93","compositor":{"active":"gles","requested":"gles","reason":"","renderer":"AMD Radeon Graphics (radeonsi, rembrandt) | OpenGL ES 3.2 Mesa 25.0.7"}},{"display_id":"display-102","compositor":{"active":"cpu","requested":"gles","reason":"no GBM scanout surface for the output","renderer":""}},{"display_id":"display-7","compositor":{"active":"cpu","requested":"cpu","reason":"","renderer":""}}]'
      n := blit_rows 999999
      i=0; seen=0
      while [ "$i" -lt "$n" ]; do
          case "${CP[999999][$i][text]}" in
          display-93) [ "${CP[999999][$i][val]}" = "GPU (GLES): AMD Radeon Graphics" ] || { echo "gpu row: ${CP[999999][$i][val]}" >&2; exit 60; }; seen=$((seen + 1)) ;;
          display-102) [ "${CP[999999][$i][val]}" = "Software (CPU); GPU unavailable: no GBM scanout surface for the output" ] || { echo "fallback row: ${CP[999999][$i][val]}" >&2; exit 61; }; seen=$((seen + 1)) ;;
          display-7) [ "${CP[999999][$i][val]}" = "Software (CPU)" ] || exit 62; seen=$((seen + 1)) ;;
          esac
          i=$((i + 1))
      done
      [ "$seen" = 3 ] || { echo "rendering rows missing ($seen)" >&2; exit 63; }
      json parse 'BCP_SNAPSHOT[diagnostics][render][outputs]' "$rendering"
      i=0; compositor_row=0; timing_row=0
      while [ "$i" -lt "$n" ]; do
          [ "${CP[999999][$i][key]}" != compositor ] || compositor_row=1
          [ "${CP[999999][$i][key]}" != frame_timing ] || timing_row=1
          i=$((i + 1))
      done
      [ "$compositor_row" = 1 ] && [ "$timing_row" = 1 ] || { echo 'compositor/frame timing controls missing' >&2; exit 64; }
      blit_cp_choose compositor cpu
      blit_cp_choose compositor opengl
      blit_cp_choose frame_timing immediate
      blit_cp_choose frame_timing soon
      [ "${BCP_DRAFT[server][kms_compositor]}" = cpu ] && [ "${BCP_DRAFT[server][kms_frame_timing]}" = immediate ] || { echo 'rendering choices not staged' >&2; exit 65; }
      blit_do 44 frame_timing 1
      [ "${BCP_DRAFT[server][kms_frame_timing]}" = late ] || { echo 'frame timing does not step' >&2; exit 66; }
      blit_cp_choose frame_timing immediate
      # Pane effects: one pair of sliders per pane Blit reports, staged in
      # the draft and applied by Save; a slider at 0 drops that effect.
      eo=${BCP_EFFECTS[panes][0][output]}
      [ -n "$eo" ] && [ "${BCP_EFFECTS[panes][1][pane_ordinal]}" = 2 ] || { echo 'effects panes not read' >&2; exit 70; }
      blit_slide 44 "corners:$eo:1" 12
      blit_slide 44 "scanlines:$eo:2" 30
      blit_slide 44 "corners:$eo:1" 65
      blit_slide 44 "scanlines:$eo:2" -1
      blit_do 44 "scanlines:$eo:2" 1
      [ "${BCP_DRAFT[effects][$eo][1][corners][radius_px]}" = 12 ] &&
      [ "${BCP_DRAFT[effects][$eo][2][scanlines][intensity]}" = 35 ] || { echo 'effects not staged' >&2; exit 71; }
      [ -z "${BCP_DRAFT[effects][$eo][1][scanlines][intensity]}" ] || { echo 'an effect at 0 was written' >&2; exit 72; }
      n := blit_rows 999999
      i=0; shown=
      while [ "$i" -lt "$n" ]; do
          [ "${CP[999999][$i][key]}" != "corners:$eo:1" ] || shown="${CP[999999][$i][val]} ${CP[999999][$i][after]}"
          i=$((i + 1))
      done
      [ "$shown" = "12 (12 px)" ] || { echo "corner row: $shown" >&2; exit 73; }
      output=${BCP_SNAPSHOT[displays][displays][0][state][connector]:-${BCP_SNAPSHOT[displays][displays][0][name]}}
      blit_slide 44 "columns:$output" 3
      blit_slide 44 "rows:$output" 2
      [ "${BCP_DRAFT[display_layouts][$output][columns]}" = 3 ] &&
      [ "${BCP_DRAFT[display_layouts][$output][rows]}" = 2 ] || exit 31
      blit_do 44 save 1
      finish
      [ "${BCP_SNAPSHOT[settings][document][display_layouts][$output][columns]}" = 3 ] || exit 32
      [ "${BCP_SNAPSHOT[settings][document][server][kms_compositor]}" = cpu ] || { echo 'compositor not saved' >&2; exit 67; }
      [ "${BCP_SNAPSHOT[settings][effective][kms_frame_timing]}" = immediate ] || { echo 'frame timing not applied' >&2; exit 68; }
      blit_cp_start refresh; finish
      [ "${BCP_EFFECTS[panes][0][effects][corners][radius_px]}" = 12 ] &&
      [ "${BCP_EFFECTS[panes][1][effects][scanlines][intensity]}" = 35 ] || { echo 'saved effects not live' >&2; exit 74; }
      blit_slide 44 "corners:$eo:1" 0
      blit_do 44 save 1
      finish
      blit_cp_start refresh; finish
      [ -z "${BCP_EFFECTS[panes][0][effects][corners][radius_px]}" ] &&
      [ "${BCP_EFFECTS[panes][1][effects][scanlines][intensity]}" = 35 ] || { echo 'corners not turned off' >&2; exit 75; }
      BCP_TOKEN=panel-test-token
      blit_cp_credentials 0 || { echo 'credential save failed' >&2; exit 33; }
      cp_save
      BCP_TOKEN=
      blit_cp_credentials || exit 34
      [ "$BCP_TOKEN" = panel-test-token ] || { echo 'token not restored' >&2; exit 35; }
      original=$BCP_URL
      BCP_URL=http://other-host:8080
      blit_cp_credentials
      [ -z "$BCP_TOKEN" ] || { echo 'credential crossed origins' >&2; exit 36; }
      BCP_URL=$original
      blit_cp_credentials
      command chmod 0644 "$XDG_CONFIG_HOME/hibr/blit/connection.json"
      blit_cp_credentials && { echo 'insecure token accepted' >&2; exit 37; }
      [ -z "$BCP_TOKEN" ] || exit 38
      command chmod 0600 "$XDG_CONFIG_HOME/hibr/blit/connection.json"
      blit_cp_credentials
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
      [ "$BCP_TEST_WAKE" -gt 0 ] && [ "$BCP_TEST_WAKE" -le 250 ] || { echo "busy wake is not bounded polling: $BCP_TEST_WAKE" >&2; exit 23; }
      finish
      [ $((BCP_NEXT - EPOCHSECONDS)) -ge 14 ] || { echo 'refresh completion did not schedule idle deadline' >&2; exit 24; }
      BCP_NEXT=0
      n := blit_rows 999999
      [ "$BCP_BUSY" = 0 ] || { echo 'search scratch rows launched a request' >&2; exit 25; }
      BCP_NEXT=$((EPOCHSECONDS + 15))
      base=$BCP_BASE_REV
      output=${BCP_SNAPSHOT[displays][displays][0][state][connector]:-${BCP_SNAPSHOT[displays][displays][0][name]}}
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
      blit_do 44 font_size 1
      finish
      [ "${BCP_SNAPSHOT[fonts][active][size_px]}" = 17 ] || { echo "pixel size failed: $BCP_STATUS" >&2; exit 9; }
      json set BCP_DRAFT .login.fallback wait -s
      BCP_DIRTY=1
      old_base=$BCP_BASE_REV
      blit_slide 44 font_size 18
      blit_slide 44 font_size 23
      blit_slide 44 font_size 31
      finish
      [ "${BCP_SNAPSHOT[fonts][active][size_px]}" = 31 ] || { echo 'drag lost its final value' >&2; exit 39; }
      [ "${BCP_DRAFT[font][size_px]}" = 31 ] && [ -z "${BCP_DRAFT[font][scale]}" ] || exit 42
      [ "${BCP_DRAFT[login][fallback]}" = wait ] && [ "$BCP_DIRTY" = 1 ] && [ "$BCP_BASE_REV" = "$old_base" ] || exit 43
      blit_do 44 font_size -1
      finish
      [ "${BCP_SNAPSHOT[fonts][active][size_px]}" = 30 ] || exit 44
      blit_do 44 font_size 1
      blit_do 44 font_size 1
      blit_do 44 font_size 1
      finish
      [ "${BCP_SNAPSHOT[fonts][active][size_px]}" = 33 ] || exit 48
      blit_slide 44 font_size 8
      finish
      [ "${BCP_SNAPSHOT[fonts][active][size_px]}" = 8 ] || exit 45
      blit_slide 44 font_size 64
      finish
      [ "${BCP_SNAPSHOT[fonts][active][size_px]}" = 64 ] || exit 46
      blit_slide 44 font_size 7
      blit_slide 44 font_size 65
      [ "$BCP_BUSY" = 0 ] || exit 47
      font_snapshot := json get BCP_SNAPSHOT .fonts
      json parse 'BCP_SNAPSHOT[fonts]' '{"active":{"id":"legacy","scale":1.0}}'
      n := blit_rows 999999
      i=0
      while [ "$i" -lt "$n" ]; do
          [ "${CP[999999][$i][key]}" != font_size ] || exit 49
          i=$((i + 1))
      done
      blit_slide 44 font_size 20
      [ "$BCP_BUSY" = 0 ] || exit 50
      json parse 'BCP_SNAPSHOT[fonts]' "$font_snapshot"
      # #368: a font size chosen while the slider is held is shown, not
      # written; letting go writes it once.
      finish
      CP_MSLIDE[44]="3 10"
      blit_slide 44 font_size 25
      blit_slide 44 font_size 40
      [ "$BCP_BUSY" = 0 ] && [ "$BCP_FONT_HELD" = 40 ] || { echo 'a held slider wrote the font' >&2; exit 60; }
      [ "${BCP_SNAPSHOT[fonts][active][size_px]}" = 64 ] || exit 61
      n := blit_rows 44
      i=0; shown=
      while [ "$i" -lt "$n" ]; do
          [ "${CP[44][$i][key]}" != font_size ] || shown=${CP[44][$i][val]}
          i=$((i + 1))
      done
      [ "$shown" = 40 ] || { echo "held size not shown: $shown" >&2; exit 62; }
      finish
      CP_MSLIDE[44]=
      blit_cp_tick 44
      finish
      [ "${BCP_SNAPSHOT[fonts][active][size_px]}" = 40 ] && [ -z "$BCP_FONT_HELD" ] || { echo 'release did not apply the held size' >&2; exit 63; }
      /bin/sleep 0.7
      blit_do 44 reload 1
      finish
      # #364: Blit saving the pane's own font change moves the revision; the
      # pane rebases and keeps its staged edits instead of calling that
      # somebody else's change. An outside change still says so.
      json set BCP_DRAFT .login.fallback wait -s
      BCP_DIRTY=1
      base=$BCP_BASE_REV
      blit_slide 44 font_size 21
      finish
      i=0
      while :; do
          /bin/sleep 0.3
          blit_cp_start refresh; finish
          [ "${BCP_SNAPSHOT[settings][revision]}" = "$base" ] || break
          i=$((i + 1)); [ "$i" -lt 20 ] || { echo 'Blit never saved the font change' >&2; exit 64; }
      done
      [ "$BCP_BASE_REV" = "${BCP_SNAPSHOT[settings][revision]}" ] || { echo "own font save not rebased: $BCP_STATUS" >&2; exit 65; }
      [ "$BCP_STATUS" != "Saved settings changed; reload before saving" ] || exit 66
      [ "${BCP_DRAFT[login][fallback]}" = wait ] && [ "$BCP_DIRTY" = 1 ] || { echo 'rebase lost the staged edit' >&2; exit 67; }
      raw := json get BCP_SNAPSHOT .settings.document
      json parse outside "$raw"
      fb=wait; [ "${outside[login][fallback]}" != wait ] || fb=first_available
      json set outside .login.fallback "$fb" -s
      json parse oput '{}'; raw := json emit outside; json parse 'oput[document]' "$raw"
      raw := json emit oput
      blit_cp_http PUT /v1/settings "$raw" "${BCP_SNAPSHOT[settings][revision]}" || { echo "outside PUT failed: $BCP_HTTP_CODE" >&2; exit 68; }
      blit_cp_start refresh; finish
      [ "$BCP_STATUS" = "Saved settings changed; reload before saving" ] || { echo "outside change not flagged: $BCP_STATUS" >&2; exit 69; }
      blit_do 44 reload 1
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
      DTA[9][label]="API Token:"
      DTA[9][buf]=secret-must-be-masked
      DTA[9][masked]=1
      DTA[9][focus]=text
      DTA[9][cur]=0
      DTA[9][hint]=
      dtask_draw 9 9 64 0 0
      echo BLIT_PANEL_PASS
    HIBR
    out,err,st=Open3.capture3({'XDG_RUNTIME_DIR'=>root,'XDG_CONFIG_HOME'=>File.join(root,'config')},'/usr/bin/hibr',script)
    abort("panel callbacks failed #{st}:\n#{out}\n#{err}\n#{File.read(log)}") unless st.success? && out.include?('BLIT_PANEL_PASS')
    abort('token leaked through dialog') if out.include?('secret-must-be-masked')
    timing=out.lines.find { |l| l.start_with?('CALLBACK_LATENCY:') }.split(':')[1,2].map(&:to_f)
    abort('network I/O blocked pane callbacks') unless timing[1]-timing[0]<0.25
    abort('token leaked through export') if File.read(File.join(root,'export.json')).include?('panel-test-token')
    document=JSON.parse(File.read(File.join(root,'export.json')))
    abort('export is not structured settings') unless document['auxiliary_displays'].is_a?(Array)
    reload_script=File.join(root,'reload.hibr')
    File.write(reload_script, <<~HIBR)
      strict
      source /usr/share/hibr/desktop/wm/settings.hibr
      source /usr/share/hibr/desktop/wm/jobs.hibr
      source '#{BUNDLE}'
      # Match the installed session: cp_panes sources bundles first,
      # dt_open loads preferences afterwards, and only then a pane runs.
      source "$DT_CONF"
      [ "$BCP_URL" = 'http://127.0.0.1:#{PORT}' ] || exit 2
      blit_cp_start refresh
      [ "$BCP_TOKEN" = panel-test-token ] || exit 1
      while [ "$BCP_BUSY" = 1 ]; do blit_cp_poll; /bin/sleep 0.02; done
      [ "$BCP_BASE_REV" -ge 0 ] || exit 3
    HIBR
    _,err,st=Open3.capture3({'XDG_CONFIG_HOME'=>File.join(root,'config'),'XDG_RUNTIME_DIR'=>root},'/usr/bin/hibr',reload_script)
    abort("credential not restored in a new process:#{err}") unless st.success?
    abort('token was written into executable desktop settings') if File.read(File.join(root,'config/hibr/desktop.hibr')).include?('panel-test-token')
    puts 'BLIT_PANEL_PASS callbacks=actual_hibr api=actual_blit refresh=quiet_15s backoff=15_30_60 scratch=no_io apply_save=separate conflict=preserved auth=reported offline=reported font_size=8..64_pixels drag=latest_value effects=staged_saved_live draft=preserved token=masked export=no_secrets'
  ensure
    File.chmod(0700,root)
    Process.kill('TERM',pid) rescue nil
    Timeout.timeout(10){Process.wait(pid)} rescue nil
  end
end
hang.close
hang_worker.kill
hang_worker.join
