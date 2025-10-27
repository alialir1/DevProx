local JSON    = dofile("./libs/dkjson.lua")
local json    = dofile("./libs/JSON.lua")
local URL     = dofile("./libs/url.lua")
local https   = require("ssl.https")

_G.__BOTAPI_MODE__ = true

local function api_call(method, params)
  local query = {}
  for k, v in pairs(params or {}) do
    table.insert(query, k .. "=" .. URL.escape(tostring(v)))
  end
  local url = "https://api.telegram.org/bot" .. TokenBot .. "/" .. method .. (next(query) and ("?" .. table.concat(query, "&")) or "")
  local body, code = https.request(url)
  if code ~= 200 then
    return nil, code
  end
  local ok, decoded = pcall(JSON.decode, body)
  if not ok then
    return nil, 500
  end
  return decoded, 200
end

-- Minimal tdcli shim
function tdcli_function(tbl, cb, extra)
  local id = tbl and tbl.ID or tbl.id
  local function done(result)
    if cb then
      pcall(cb, extra, result)
    end
  end
  if id == "SendMessage" then
    local chat_id = tbl.chat_id_ or tbl.chat_id
    local reply_to = tbl.reply_to_message_id_ or 0
    local content = tbl.input_message_content_ or {}
    local cID = content.ID or content.id
    if cID == "InputMessageText" then
      api_call("sendMessage", {chat_id = chat_id, reply_to_message_id = reply_to, text = content.text_ or content.text or "", parse_mode = "Markdown", disable_web_page_preview = true})
      return done({ID = "Ok"})
    elseif cID == "InputMessagePhoto" then
      api_call("sendPhoto", {chat_id = chat_id, reply_to_message_id = reply_to, photo = content.photo_ and (content.photo_.path_ or content.photo_) or content.photo, caption = content.caption_ or ""})
      return done({ID = "Ok"})
    elseif cID == "InputMessageSticker" then
      api_call("sendSticker", {chat_id = chat_id, reply_to_message_id = reply_to, sticker = content.sticker_})
      return done({ID = "Ok"})
    elseif cID == "InputMessageVoice" then
      api_call("sendVoice", {chat_id = chat_id, reply_to_message_id = reply_to, voice = content.voice_, caption = content.caption_ or ""})
      return done({ID = "Ok"})
    elseif cID == "InputMessageAudio" then
      api_call("sendAudio", {chat_id = chat_id, reply_to_message_id = reply_to, audio = content.audio_, caption = content.caption_ or ""})
      return done({ID = "Ok"})
    elseif cID == "InputMessageVideo" then
      api_call("sendVideo", {chat_id = chat_id, reply_to_message_id = reply_to, video = content.video_, caption = content.caption_ or ""})
      return done({ID = "Ok"})
    elseif cID == "InputMessageDocument" then
      api_call("sendDocument", {chat_id = chat_id, reply_to_message_id = reply_to, document = content.document_, caption = content.caption_ or ""})
      return done({ID = "Ok"})
    elseif cID == "InputMessageContact" then
      local c = content.contact_ or {}
      api_call("sendContact", {chat_id = chat_id, reply_to_message_id = reply_to, phone_number = c.phone_number_, first_name = c.first_name_ or "", last_name = c.last_name_ or ""})
      return done({ID = "Ok"})
    else
      return done({ID = "Ok"})
    end
  elseif id == "DeleteMessages" then
    local chat_id = tbl.chat_id_ or tbl.chat_id
    local mids = tbl.message_ids_ or {}
    for _, mid in pairs(mids) do
      api_call("deleteMessage", {chat_id = chat_id, message_id = mid})
    end
    return done({ID = "Ok"})
  elseif id == "ChangeChatMemberStatus" then
    local chat_id = tbl.chat_id_ or tbl.chat_id
    local user_id = tbl.user_id_ or tbl.user_id
    local status = tbl.status_ and tbl.status_.ID or ""
    if status == "ChatMemberStatusKicked" then
      api_call("banChatMember", {chat_id = chat_id, user_id = user_id})
      return done({ID = "Ok"})
    elseif status == "ChatMemberStatusLeft" then
      api_call("unbanChatMember", {chat_id = chat_id, user_id = user_id, only_if_banned = true})
      return done({ID = "Ok"})
    else
      return done({ID = "Ok"})
    end
  elseif id == "GetUser" then
    local user_id = tbl.user_id_ or tbl.user_id
    local res = api_call("getChat", {chat_id = user_id})
    local data = res and res[1] or res -- not used
    local user = {}
    if res and res.ok and res.result then
      local r = res.result
      user = {id_ = r.id, first_name_ = r.first_name or r.title or "", username_ = r.username}
    end
    return done(user)
  elseif id == "GetMessage" then
    -- Not supported in Bot API; return empty
    return done({})
  elseif id == "GetChatMember" then
    local chat_id = tbl.chat_id_ or tbl.chat_id
    local user_id = tbl.user_id_ or tbl.user_id
    local res = api_call("getChatMember", {chat_id = chat_id, user_id = user_id})
    local out = {}
    if res and res.ok and res.result then
      out.status_ = {ID = res.result.status == "administrator" and "ChatMemberStatusEditor" or (res.result.status == "creator" and "ChatMemberStatusCreator" or "ChatMemberStatusMember")}
    end
    return done(out)
  elseif id == "GetChannelMembers" then
    local chat_id = tbl.channel_id_ or tbl.chat_id
    local filter = tbl.filter_ and tbl.filter_.ID or ""
    local out = {members_ = {}, total_count_ = 0}
    if filter == "ChannelMembersAdministrators" then
      local res = api_call("getChatAdministrators", {chat_id = "-100" .. tostring(chat_id)})
      if res and res.ok and res.result then
        for i, adm in ipairs(res.result) do
          out.members_[i] = {user_id_ = adm.user.id}
        end
        out.total_count_ = #res.result
      end
    end
    return done(out)
  elseif id == "SendChatAction" then
    local chat_id = tbl.chat_id_ or tbl.chat_id
    api_call("sendChatAction", {chat_id = chat_id, action = "typing"})
    return done({ID = "Ok"})
  else
    return done({ID = "Ok"})
  end
end

-- Load original bot after shim so it can call tdcli_function safely
dofile("./DevProx.lua")

local function map_message_to_tdcli(m)
  local content = {}
  if m.text then
    content.text_ = m.text
  end
  if m.new_chat_members and #m.new_chat_members > 0 then
    content.members_ = {}
    for i, u in ipairs(m.new_chat_members) do
      content.members_[i - 1] = {id_ = u.id}
    end
  end
  if m.left_chat_member then
    content.members_ = {[0] = {id_ = m.left_chat_member.id}}
  end
  local msg = {
    chat_id_ = m.chat and m.chat.id or nil,
    id_ = m.message_id,
    sender_user_id_ = m.from and m.from.id or nil,
    reply_to_message_id_ = (m.reply_to_message and m.reply_to_message.message_id) or 0,
    content_ = content
  }
  return msg
end

local function map_update_to_tdcli(update)
  if update.message then
    return { ID = "UpdateNewMessage", message_ = map_message_to_tdcli(update.message) }
  end
  if update.callback_query then
    local cq = update.callback_query
    return {
      ID = "UpdateNewCallbackQuery",
      chat_id_ = cq.message and cq.message.chat and cq.message.chat.id or nil,
      message_id_ = cq.message and cq.message.message_id or nil,
      payload_ = { data_ = cq.data },
      sender_user_id_ = cq.from and cq.from.id or nil,
      id_ = cq.id
    }
  end
  if update.edited_message then
    local em = update.edited_message
    return { ID = "UpdateMessageEdited", chat_id_ = em.chat.id, message_id_ = em.message_id }
  end
  return nil
end

local function start_long_poll()
  local offset = 0
  while true do
    local res, code = api_call("getUpdates", {timeout = 50, offset = offset})
    if res and res.ok then
      for _, upd in ipairs(res.result or {}) do
        offset = upd.update_id + 1
        local data = map_update_to_tdcli(upd)
        if data and type(tdcli_update_callback) == "function" then
          pcall(tdcli_update_callback, data)
        end
      end
    else
      os.execute("sleep 1")
    end
  end
end

start_long_poll()