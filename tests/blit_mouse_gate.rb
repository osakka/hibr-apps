#!/usr/bin/env ruby
# Actual native callbacks against Blit; mixed-kind devices are not ignored.
require 'tmpdir'
require 'open3'
require 'socket'
require 'timeout'
require 'json'
require 'net/http'
ROOT=File.expand_path('..',__dir__)
BLIT=ENV.fetch('BLIT_ROOT',File.expand_path('../../hw-manager',__dir__))
# Blit's own mocked display (native KMS on its DRM mock; ADR 0184).
require File.join(BLIT,'tools/tests/gate_server')
PORT=Integer(ENV.fetch('BLIT_MOUSE_GATE_PORT','19520'))
Dir.mktmpdir('blit-mouse') do |root|
  input=File.join(root,'input');Dir.mkdir(input)
  2.times do |i|
    File.write(File.join(input,"event#{i}"),'')
    File.write(File.join(input,"event#{i}.identity"),"bustype=3\nvendor=046d\nproduct=c52#{i}\nversion=0111\nphys=usb-0000:00:14.0-#{i}/input0\nname=Pointer #{i}\nkinds=#{i==0 ? 'keyboard,pointer' : 'pointer'}\ncapabilities=rel-x,rel-y,buttons,keys#{i==1 ? ',touchpad' : ''}\n")
  end
  env={**gate_display_env,'BLIT_LOGIN_AUTOSTART'=>'0',
       'BLIT_SETTINGS_PATH'=>File.join(root,'settings.json'),'BLIT_INPUT_ROOT'=>input,
       'BLIT_PSF_FONT'=>File.join(BLIT,'assets/fonts/Blit-Terminus16.psf')}
  pid=spawn(env,ENV.fetch('BLIT_GATE_BINARY',File.join(BLIT,'build/blit/blit-server')),PORT.to_s,out:File.join(root,'server.log'),err:[:child,:out])
  begin
    Timeout.timeout(10){loop{begin;s=TCPSocket.new('127.0.0.1',PORT);s.close;break;rescue Errno::ECONNREFUSED;sleep 0.05;end}}
    Timeout.timeout(10) do
      loop do
        devices=JSON.parse(Net::HTTP.get(URI("http://127.0.0.1:#{PORT}/v1/input/devices")))['devices']
        break if devices.length==2
        sleep 0.05
      end
    end
    script=File.join(root,'test.hibr')
    File.write(script,<<~HIBR)
      strict
      source /usr/share/hibr/desktop/wm/settings.hibr
      source /usr/share/hibr/desktop/system/panel.hibr
      source /usr/share/hibr/desktop/wm/jobs.hibr
      source /usr/share/hibr/desktop/wm/ask.hibr
      source '#{ROOT}/bundles/control-panel/blit.hibr'
      BCP_URL=http://127.0.0.1:#{PORT}
      # Whether the rows the pane draws hold one with this text.
      fn hasrow(int w, int n, text) {
          local i
          for ((i = 0; i < n; i++)); do [ "${CP[$w][$i][text]}" = "$text" ] && return 0; done
          return 1
      }
      fn finish() {
          local i=0
          while [ "$BCP_BUSY" = 1 ]; do blit_cp_poll; /bin/sleep 0.02; i=$((i+1)); [ "$i" -lt 800 ] || exit 90; done
      }
      [ "${CP_PANES[blit_mouse][title]}" = 'Blit Mouse' ] || exit 10
      blit_cp_start refresh; finish
      n := blit_mouse_rows 45
      [ "$n" -ge 20 ] || { echo "missing mouse rows:$n:$BCP_STATUS"; exit 11; }
      [ -n "${BCP_SNAPSHOT[settings][effective][pointer][shape]}" ] || exit 12
      selected := blit_mouse_index
      [ "$selected" = 0 ] || { echo 'mixed keyboard/pointer ignored'; exit 13; }
      id=$BCP_POINTER_ID
      # Popup callbacks apply the exact choice, never another cp_next step.
      BCP_DROP_KEY[45]=shape
      blit_cp_selected 45 precision
      [ "${BCP_DRAFT[pointer][shape]}" = precision ] || exit 25
      blit_cp_selected 45 invalid
      [ "${BCP_DRAFT[pointer][shape]}" = precision ] || exit 26
      blit_cp_choose shape arrow
      blit_cp_choose palette amber
      [ "${BCP_DRAFT[pointer][palette]}" = amber ] || exit 27
      blit_cp_choose palette pearl
      BCP_DROP_KEY[45]=device
      blit_cp_choices device
      blit_cp_selected 45 "${BCP_CHOICES[1]}"
      [ "$BCP_POINTER_ID" != "$id" ] || exit 28
      blit_cp_choose device "$id"
      blit_mouse_do 45 shape 1
      blit_mouse_do 45 palette 1
      blit_mouse_do 45 shadow 1
      blit_mouse_slide 45 size 48
      blit_mouse_slide 45 sensitivity 175
      blit_mouse_slide 45 wheel 4
      blit_mouse_do 45 natural 1
      blit_mouse_do 45 acceleration 1
      [ "${BCP_DRAFT[pointer][shape]}" = hand ] && [ "${BCP_DRAFT[pointer][palette]}" = obsidian ] || exit 14
      [ "${BCP_DRAFT[pointer][size_px]}" = 48 ] && [ "${BCP_DRAFT[pointer][shadow]}" = false ] || exit 15
      [ "$BCP_BUSY" = 0 ] && [ "$BCP_DIRTY" = 1 ] || exit 16
      blit_mouse_do 45 save 1; finish
      [ "$BCP_DIRTY" = 0 ] || { echo "save failed:$BCP_STATUS"; exit 17; }
      blit_cp_start refresh; finish
      [ "${BCP_SNAPSHOT[settings][effective][pointer][size_px]}" = 48 ] || exit 18
      [ "${BCP_SNAPSHOT[input_devices][devices][0][configuration][sensitivity_percent]}" = 175 ] || exit 19
      [ "${BCP_SNAPSHOT[input_devices][devices][0][configuration][scroll_step]}" = 4 ] || exit 20
      [ "${BCP_SNAPSHOT[input_devices][devices][0][configuration][acceleration][profile]}" = adaptive ] || exit 21
      [ "${BCP_SNAPSHOT[input_devices][devices][0][configuration][natural_scroll]}" = true ] || exit 22
      [ "${BCP_SNAPSHOT[input_devices][devices][1][configuration][sensitivity_percent]}" = 100 ] || exit 23
      # Tap to Click is a touchpad's alone: not offered for the mouse, offered
      # off for the touchpad, and saved like any other device setting.
      n := blit_mouse_rows 45
      ! hasrow 45 "$n" "Tap to Click" || { echo 'a mouse offered tap'; exit 29; }
      ! hasrow 45 "$n" "Tap and Drag" || { echo 'a mouse offered tap and drag'; exit 35; }
      ! hasrow 45 "$n" "Disable While Typing" || { echo 'a mouse offered disable while typing'; exit 36; }
      blit_mouse_do 45 tap 1
      [ -z "${BCP_DRAFT[input_devices][$id][tap_to_click]}" ] || exit 30
      blit_mouse_do 45 device 1
      [ "$BCP_POINTER_ID" != "$id" ] || exit 24
      n := blit_mouse_rows 45
      hasrow 45 "$n" "Tap to Click" || { echo 'the touchpad offered no tap'; exit 31; }
      [ "${BCP_SNAPSHOT[input_devices][devices][1][configuration][tap_to_click]}" = false ] || exit 32
      blit_mouse_do 45 tap 1
      blit_mouse_do 45 save 1; finish
      [ "$BCP_DIRTY" = 0 ] || { echo "tap save failed:$BCP_STATUS"; exit 33; }
      blit_cp_start refresh; finish
      [ "${BCP_SNAPSHOT[input_devices][devices][1][configuration][tap_to_click]}" = true ] || exit 34
      # Tap and Drag and Disable While Typing (Blit ADR 0193): a touchpad's,
      # on by default, switched off and saved like the rest.
      n := blit_mouse_rows 45
      hasrow 45 "$n" "Tap and Drag" || { echo 'the touchpad offered no tap and drag'; exit 37; }
      hasrow 45 "$n" "Disable While Typing" || { echo 'the touchpad offered no disable while typing'; exit 38; }
      blit_mouse_do 45 tapdrag 1
      blit_mouse_do 45 dwt 1
      blit_mouse_do 45 save 1; finish
      [ "$BCP_DIRTY" = 0 ] || { echo "drag save failed:$BCP_STATUS"; exit 39; }
      blit_cp_start refresh; finish
      [ "${BCP_SNAPSHOT[input_devices][devices][1][configuration][tap_and_drag]}" = false ] || exit 40
      [ "${BCP_SNAPSHOT[input_devices][devices][1][configuration][disable_while_typing]}" = false ] || exit 41
      echo BLIT_MOUSE_CALLBACK_PASS
    HIBR
    out,err,status=Open3.capture3({'HOME'=>root,'XDG_CONFIG_HOME'=>File.join(root,'config'),'TMPDIR'=>root},'/usr/bin/hibr',script)
    abort("mouse callbacks failed #{status.exitstatus}:#{out}\n#{err}\n#{File.read(File.join(root,'server.log'))}") unless status.success?
    puts out
  ensure
    Process.kill('TERM',pid) rescue nil
    Process.wait(pid) rescue nil
  end
end
