local md5 = require 'md5'
local json = require 'dkjson'

SugarREST = {}

function SugarREST:new(auth)
  local obj = {}
    obj.login = 'login'
    obj.password = 'pass'
    -- obj.url = 'http://httpbin.org/post'
    obj.url = 'http://localhost/service/v4_1/rest.php'
    obj.sessionId = ''

  -- после повторного обращения к self.url он пустой

  function obj:restCall(method, restData)
  	local cURL = require 'cURL'
  	local data = {
      method = method,
      input_type = 'JSON',
      response_type = 'JSON',
      rest_data = restData
    }
  	local response = ''
    local request = cURL.easy{
      url = self.url,
      ssl_verifypeer = false,
      ssl_verifyhost = false,
      post = true,
      httppost = cURL.form(data)
    }
    request:perform({writefunction = function(str) response = str end})
    request:close()
    return json.decode(response)
  end

  function obj:getSessionId()
  	if (self.sessionId == nil or self.sessionId == '') then
  	  local restData = string.format('{"user_auth":{"user_name":"%s","password":"%s","version":"1"},"application_name":"RestTest","name_value_list":[]}', obj.login, md5.sumhexa(obj.password))
      local session = self:restCall('login', restData)
      self.sessionId = session.id
    end
  	return self.sessionId
  end

  function obj:createCall(direction, status, duration, localPhone, extPhone)
    local name = extPhone
    local user = self:getContact(localPhone)
    local contact = self:getContact(extPhone)
    local parentId = ''
    local parentType = ''

    if not contact then
      name = 'Неизвестный номер: ' .. extPhone
    else
      if ( type(contact.name_value_list.account_id ) ~= 'table' ) then
        parentType = contact['module_name']
        parentId = contact['id']
      else
        parentType = 'Accounts'
        parentId = contact.name_value_list.account_id['value']
      end
    end

    local fields = json.encode({
      { name = 'name', value = name },
      { name = 'direction', value = direction }, -- { Inbound, Outbound }
      { name = 'status', value = status }, -- { Planned, Held, Not Held }
      { name = 'date_start', value = os.date('!%Y-%m-%d %H:%M:%S') }, -- Время в UTC
      { name = 'duration_hours', value = math.floor(duration/3600) },
      { name = 'duration_minutes', value = math.floor(duration/60) },
      { name = 'assigned_user_id', value = ( not user and '1' or user['id']) },
      { name = 'parent_type', value = parentType },
      { name = 'parent_id', value = parentId },
      { name = 'cvtk_phone_number_c', value = extPhone },

    })    
    local restData = string.format('{"session":"%s","module_name":"Calls","name_value_list": %s}', self:getSessionId(), fields)
    local call = self:restCall('set_entry', restData)
    return call['id']
  end
  
  function obj:getUser(exten)
    local query = string.format('"query":"users.phone_work=\'%s\'"', exten)
    local fields = '"order_by":"","offset":0,"favorites":false,"deleted":0,"max_results":1'
    local restData = string.format('{"session":"%s","module_name":"Employees", %s, %s}', self:getSessionId(), query, fields)
    local user = self:restCall('get_entry_list', restData)
    return user.entry_list[1]
  end

  function obj:getContact(phone)
    if (phone == nil or phone == '' or #phone < 4) then return false end
    local phone = phone:sub(-10)
    local searchFields = { 
      'phone_home',
      'phone_mobile',
      'phone_work',
      'phone_other',
      'phone_fax',
    }
    local searchModule = {        -- { modul_name = db_table}
      Employees = 'users',
      Contacts = 'contacts',
    }
    local properties = [[
      "order_by": "",
      "offset": 0,
      "favorites": false,
      "deleted": 0,
      "max_results": 1
    ]]
    for moduleName, tableName in pairs(searchModule) do
      local query = ''
      local restData = ''
      for field = 1, #searchFields do
        query = query .. tableName .. '.' .. searchFields[field] .. ' LIKE \'%' .. phone .. '%\'' .. (field ~= #searchFields and ' OR ' or '')
      end
      restData = string.format('{"session":"%s","module_name":"%s","query":"(%s)", %s}', self:getSessionId(), moduleName, query, properties)
      local response = self:restCall('get_entry_list', restData)
      if (response.result_count ~= 0) then
        return response.entry_list[1] 
      end
    end
    return false
  end
  setmetatable(obj, self)
  self.__index = self; return obj
end