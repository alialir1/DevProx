local URL     = dofile("./libs/url.lua")
local JSON    = dofile("./libs/dkjson.lua")
local Redis   = dofile("./libs/redis.lua").connect("127.0.0.1", 6379)

-- install/load luatele/tdlua libs (64-bit)
if URL.tdlua_CallBack then pcall(URL.tdlua_CallBack) end

local luatele = require 'luatele'

-- load config to get token and session
local Config = dofile("./config.lua")
local TokenBot = Config.TokenBot or Config.Token or Config.token or ''
local BotId = (TokenBot:match("(%d+)") or '')

-- configure luatele
LuaTele = luatele.set_config{
  api_id = 2692371,
  api_hash = 'fe85fff033dfe0f328aeb02b4f784930',
  session_name = BotId,
  token = TokenBot
}

-- load original bot code (defines tdcli_update_callback)
dofile("./DevProx.lua")

local function map_message(msg)
  local content = {}
  if msg.content and msg.content.text and msg.content.text.text then
    content.text_ = msg.content.text.text
  end
  if msg.content and msg.content.luatele == 'messageChatAddMembers' and msg.content.members and #msg.content.members > 0 then
    content.members_ = {}
    for i, u in ipairs(msg.content.members) do
      content.members_[i - 1] = {id_ = u.id}
    end
  end
  local reply_to = 0
  if msg.reply_to_message_id then reply_to = msg.reply_to_message_id end
  return {
    chat_id_ = msg.chat_id,
    id_ = msg.id,
    sender_user_id_ = msg.sender and msg.sender.user_id or nil,
    reply_to_message_id_ = reply_to,
    content_ = content
  }
end

local function CallBackLua(data)
  if not tdcli_update_callback then return end
  if data and data.luatele == 'updateNewMessage' and data.message then
    local mapped = { ID = 'UpdateNewMessage', message_ = map_message(data.message) }
    pcall(tdcli_update_callback, mapped)
  elseif data and data.luatele == 'updateMessageEdited' then
    local mapped = { ID = 'UpdateMessageEdited', chat_id_ = data.chat_id, message_id_ = data.message_id }
    pcall(tdcli_update_callback, mapped)
  elseif data and data.luatele == 'updateNewCallbackQuery' then
    local Text = data.payload and data.payload.data and LuaTele.base64_decode and LuaTele.base64_decode(data.payload.data) or (data.payload and data.payload.data) or ''
    local mapped = {
      ID = 'UpdateNewCallbackQuery',
      chat_id_ = data.chat_id,
      message_id_ = data.message_id,
      payload_ = { data_ = Text },
      sender_user_id_ = data.sender_user_id,
      id_ = data.id
    }
    pcall(tdcli_update_callback, mapped)
  elseif data and data.luatele == 'updateSupergroup' then
    -- optional: map to bot left events if needed
  end
end

luatele.run(CallBackLua)