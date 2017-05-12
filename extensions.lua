crm = require '/etc/asterisk/integration/SugarREST'
crm = SugarREST:new('some')

isp = 'XXXXXX'
mixMonTmp = '/tmp/'
mixMonDir = '/var/www/html/mixmonitor/'
mixMon = ''
localPhone, extPhone, mixMon = ''

extensions = {}
extensions.users = {}
extensions.isp = {}
hints = {
  blf = {
    ['1000'] = 'SIP/1000',
    ['1111'] = 'SIP/1111',
    ['1112'] = 'SIP/1112'
  },
}

menu = function (c, e)
  local randStr = ''
  for i = 1, 32 do randStr = randStr .. string.char(math.random(65, 90)) end
  mixMon = mixMonTmp .. randStr
  channel["MONITOR_FILENAME"]:set(mixMon)
  app.read("INPUT", "/var/lib/asterisk/cstm/intro", 4, nil, nil, 5)
  local input = channel["INPUT"]:get()

  if input == '1' then
    app.queue("sales", "tTwW", nil, nil, "600")
    app.hangup()
  elseif input == '2' then
    app.queue("supply", "tTwW", nil, nil, "45")
    app.queue("sales", "tTwW", nil, nil, "600")
    app.hangup()
  elseif input == '3' then
    app.queue("accounting", "tTwW", nil, nil, "45")
    app.queue("sales", "tTwW", nil, nil, "600")
    app.hangup()
  elseif string.len(input) == 4 then
    app.mixmonitor(mixMon .. '.wav', 'ab')
    channel['MEMBERINTERFACE']:set(input)
    app.dial('SIP/' .. input, 45, 'tT')
  else
    app.queue("sales", "tTwW", nil, nil, "600")
  end
end

extensions.isp['h'] = function()
  local lPhone, ePhone, status, duration, callId, wavToMp3 = ''
  lPhone = channel['MEMBERINTERFACE']:get()
  ePhone = channel.CALLERID('number'):get()
  status = (channel["DIALSTATUS"]:get() == 'ANSWER' and 'Held' or 'Not Held')
  duration = channel.CDR("billsec"):get()
  if (lPhone == nil or lPhone == '') then
    callId = crm:createCall('Inbound', status, duration, lPhone, ePhone)
  else 
    callId = crm:createCall('Inbound', status, duration, string.match(lPhone, "%d+"), ePhone)
    wavToMp3 = string.format('/usr/bin/lame -b 16 -silent %s %s', mixMon .. '.wav', mixMonDir .. callId .. '.mp3')
    app.stopmixmonitor()
    app.system(wavToMp3)
  end
  app.hangup()
end

extensions.isp["XXXXXX"] = function(c, e) menu(c, e) end
extensions.isp["XXXXXY"] = function(c, e) menu(c, e) end

extensions.users['h'] = function()
  local duration = channel.CDR("billsec"):get()
  local status = (channel["DIALSTATUS"]:get() == 'ANSWER' and 'Held' or 'Not Held')
  local callId = crm:createCall('Outbound', status, duration, localPhone, extPhone)
  local wavToMp3 = string.format('/usr/bin/lame -b 16 -silent %s %s', mixMon, mixMonDir .. callId .. '.mp3')
  app.stopmixmonitor()
  if status == 'Held' then 
    app.system(wavToMp3) 
  end
  if #extPhone == 4 then
    callId = crm:createCall('Inbound', status, duration, extPhone, localPhone)
    wavToMp3 = string.format('/usr/bin/lame -b 16 -silent %s %s', mixMon, mixMonDir .. callId .. '.mp3')
    if status == 'Held' then app.system(wavToMp3) end
  end
  app.hangup()
end

extensions.users['_X.'] = function(c, e)
  localPhone = channel.CALLERID('number'):get()
  extPhone = e

  local randStr = ''
  for i = 1, 32 do randStr = randStr .. string.char(math.random(65, 90)) end
  mixMon = mixMonTmp .. randStr ..  '.wav'
  app.mixmonitor(mixMon, 'ab')

  app.dial((#extPhone == 4 and 'SIP/' or 'SIP/' .. isp .. '/') .. extPhone, 45, 'tT')
end