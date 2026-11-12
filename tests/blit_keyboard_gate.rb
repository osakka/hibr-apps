#!/usr/bin/env ruby
# The Blit Keyboard pane's real callbacks against Blit: only keyboards are
# offered, repeat shows only for a keyboard that repeats, and repeat, the
# lock lamps at start and the modifier roles are staged and saved per
# keyboard through the shared settings draft.
require 'tmpdir'
require 'open3'
require 'socket'
require 'timeout'
require 'json'
require 'net/http'
ROOT=File.expand_path('..',__dir__)
BLIT=ENV.fetch('BLIT_ROOT',File.expand_path('../../hw-manager',__dir__))
require File.join(BLIT,'tools/tests/gate_server')
PORT=Integer(ENV.fetch('BLIT_KEYBOARD_GATE_PORT','19521'))
Dir.mktmpdir('blit-keyboard') do |root|
  input=File.join(root,'input');Dir.mkdir(input)
  devices=[
    ['Gate Keyboard','keyboard','keys,repeat',"repeat=250,33\n"],
    ['Gate Mouse','pointer','rel-x,rel-y,buttons',''],
    ['Gate Keypad','keyboard','keys','']
  ]
  devices.each_with_index do |(name,kinds,caps,extra),i|
    File.write(File.join(input,"event#{i}"),'')
    File.write(File.join(input,"event#{i}.identity"),"bustype=3\nvendor=05ac\nproduct=025#{i}\nversion=0100\nphys=usb-0000:00:14.0-#{i}/input0\nname=#{name}\nkinds=#{kinds}\ncapabilities=#{caps}\n#{extra}")
  end
  env={**gate_display_env,'BLIT_LOGIN_AUTOSTART'=>'0',
       'BLIT_SETTINGS_PATH'=>File.join(root,'settings.json'),'BLIT_INPUT_ROOT'=>input,
       'BLIT_PSF_FONT'=>File.join(BLIT,'assets/fonts/Blit-Terminus16.psf')}
  pid=spawn(env,ENV.fetch('BLIT_GATE_BINARY',File.join(BLIT,'build/blit/blit-server')),PORT.to_s,out:File.join(root,'server.log'),err:[:child,:out])
  begin
    Timeout.timeout(10){loop{begin;s=TCPSocket.new('127.0.0.1',PORT);s.close;break;rescue Errno::ECONNREFUSED;sleep 0.05;end}}
    Timeout.timeout(10) do
      loop do
        list=JSON.parse(Net::HTTP.get(URI("http://127.0.0.1:#{PORT}/v1/input/devices")))['devices']
        break if list.length==3
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
      fn hasrow(int w, int n, text) {
          local i
          for ((i = 0; i < n; i++)); do [ "${CP[$w][$i][text]}" = "$text" ] && return 0; done
          return 1
      }
      fn finish() {
          local i=0
          while [ "$BCP_BUSY" = 1 ]; do blit_cp_poll; /bin/sleep 0.02; i=$((i+1)); [ "$i" -lt 800 ] || exit 90; done
      }
      # Blit's index of the device with this name.
      fn devindex(name) {
          local i=0
          while [ -n "${BCP_SNAPSHOT[input_devices][devices][$i][id]}" ]; do
              [ "${BCP_SNAPSHOT[input_devices][devices][$i][name]}" != "$name" ] || { ret "$i"; return 0; }
              i=$((i + 1))
          done
          ret -1
      }
      [ "${CP_PANES[blit_keyboard][title]}" = 'Blit Keyboard' ] || exit 10
      blit_cp_start refresh; finish
      n := blit_keyboard_rows 46
      [ "$n" -ge 15 ] || { echo "missing keyboard rows:$n:$BCP_STATUS"; exit 11; }
      # Only keyboards are offered: the mouse is not.
      blit_cp_choices kbdevice
      [ "${#BCP_CHOICES[@]}" = 2 ] || { echo "keyboards offered:${BCP_CHOICES[*]}"; exit 12; }
      k := devindex 'Gate Keyboard'; p := devindex 'Gate Keypad'
      blit_cp_choose kbdevice "${BCP_SNAPSHOT[input_devices][devices][$k][id]}"
      kid=$BCP_KEYBOARD_ID
      n := blit_keyboard_rows 46
      hasrow 46 "$n" "Repeat Delay" && hasrow 46 "$n" "Repeat Rate" || { echo 'repeat rows missing'; exit 13; }
      # Unset is offered until a lamp is set; then off and on.
      blit_cp_choices capsboot
      [ "${BCP_CHOICES[*]}" = 'unset off on' ] && [ "$BCP_CHOICE_CURRENT" = unset ] || exit 14
      blit_keyboard_slide 46 delay 400
      blit_keyboard_slide 46 rate 25
      blit_keyboard_slide 46 delay 99999
      blit_cp_choose capsboot on
      blit_cp_choose numboot on
      blit_cp_choose capskey control
      blit_cp_choose superkey alt
      blit_cp_choose capskey escape
      blit_cp_choices capsboot
      [ "${BCP_CHOICES[*]}" = 'off on' ] && [ "$BCP_CHOICE_CURRENT" = on ] || exit 15
      [ "${BCP_DRAFT[input_devices][$kid][repeat_delay_ms]}" = 400 ] || exit 16
      [ "${BCP_DRAFT[input_devices][$kid][modifiers][58]}" = control ] || exit 17
      [ "${BCP_DRAFT[input_devices][$kid][modifiers][125]}" = alt ] && [ "${BCP_DRAFT[input_devices][$kid][modifiers][126]}" = alt ] || exit 18
      blit_keyboard_do 46 delay 1
      [ "${BCP_DRAFT[input_devices][$kid][repeat_delay_ms]}" = 425 ] || exit 19
      [ "$BCP_BUSY" = 0 ] && [ "$BCP_DIRTY" = 1 ] || exit 20
      blit_keyboard_do 46 save 1; finish
      [ "$BCP_DIRTY" = 0 ] || { echo "save failed:$BCP_STATUS"; exit 21; }
      case $BCP_STATUS in Saved,*) echo "refused:$BCP_STATUS"; exit 31 ;; esac
      blit_cp_start refresh; finish
      k := devindex 'Gate Keyboard'
      [ "${BCP_SNAPSHOT[input_devices][devices][$k][configuration][repeat_delay_ms]}" = 425 ] || { echo "delay:$(json get BCP_SNAPSHOT .input_devices.devices[$k].configuration)"; exit 22; }
      [ "${BCP_SNAPSHOT[input_devices][devices][$k][configuration][repeat_rate_hz]}" = 25 ] || exit 23
      [ "${BCP_SNAPSHOT[input_devices][devices][$k][configuration][caps_lock_boot]}" = true ] || exit 24
      [ "${BCP_SNAPSHOT[input_devices][devices][$k][configuration][num_lock_boot]}" = true ] || exit 25
      [ "${BCP_SNAPSHOT[input_devices][devices][$k][configuration][modifiers][58]}" = control ] || exit 26
      [ "${BCP_SNAPSHOT[input_devices][devices][$k][configuration][modifiers][125]}" = alt ] || exit 27
      # A keyboard that does not repeat says so and offers no repeat rows.
      p := devindex 'Gate Keypad'
      blit_cp_choose kbdevice "${BCP_SNAPSHOT[input_devices][devices][$p][id]}"
      n := blit_keyboard_rows 46
      ! hasrow 46 "$n" "Repeat Delay" || { echo 'a non-repeating keyboard offered repeat'; exit 28; }
      hasrow 46 "$n" "This keyboard does not repeat keys" || exit 29
      [ -z "${BCP_SNAPSHOT[input_devices][devices][$p][configuration][caps_lock_boot]}" ] || exit 30
      # What Blit refuses is said, not reported as saved: repeat staged by
      # hand for the keyboard that does not repeat.
      blit_keyboard_put repeat_delay_ms 400
      blit_keyboard_do 46 save 1; finish
      case $BCP_STATUS in "Saved, but Blit refused 1:"*) ;; *) echo "refusal not shown:$BCP_STATUS"; exit 32 ;; esac
      echo BLIT_KEYBOARD_CALLBACK_PASS
    HIBR
    out,err,status=Open3.capture3({'HOME'=>root,'XDG_CONFIG_HOME'=>File.join(root,'config'),'TMPDIR'=>root},'/usr/bin/hibr',script)
    abort("keyboard callbacks failed #{status.exitstatus}:#{out}\n#{err}\n#{File.read(File.join(root,'server.log'))[-3000..]}") unless status.success?
    puts out
  ensure
    Process.kill('TERM',pid) rescue nil
    Process.wait(pid) rescue nil
  end
end
