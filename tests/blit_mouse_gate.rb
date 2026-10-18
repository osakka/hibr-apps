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
PORT=Integer(ENV.fetch('BLIT_MOUSE_GATE_PORT','19520'))
Dir.mktmpdir('blit-mouse') do |root|
  input=File.join(root,'input');Dir.mkdir(input)
  2.times do |i|
    File.write(File.join(input,"event#{i}"),'')
    File.write(File.join(input,"event#{i}.identity"),"bustype=3\nvendor=046d\nproduct=c52#{i}\nversion=0111\nphys=usb-0000:00:14.0-#{i}/input0\nname=Pointer #{i}\nkinds=#{i==0 ? 'keyboard,pointer' : 'pointer'}\ncapabilities=rel-x,rel-y,buttons,keys\n")
  end
  env={'SDL_VIDEODRIVER'=>'dummy','BLIT_RENDERER'=>'software','BLIT_LOGIN_AUTOSTART'=>'0',
       'BLIT_SETTINGS_PATH'=>File.join(root,'settings.json'),'BLIT_INPUT_ROOT'=>input,
       'BLIT_PSF_FONT'=>File.join(BLIT,'assets/fonts/Blit-Hibr-Terminus16.psf'),
       'LD_LIBRARY_PATH'=>File.join(BLIT,'build/sdl3-kms')}
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
      source '#{ROOT}/bundles/control-panel/blit.hibr'
      BCP_URL=http://127.0.0.1:#{PORT}
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
      blit_mouse_do 45 device 1
      [ "$BCP_POINTER_ID" != "$id" ] || exit 24
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
