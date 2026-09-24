--!strict
-- Chat name tags: [VIP] (VIP pass) and [♻️N] (rebirth count), read from replicated attributes.

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local ChatTags = {}

function ChatTags.prefixFor(player: Player?): string
	if not player then
		return ""
	end
	local tags = ""
	if player:GetAttribute("VIP") == true then
		tags ..= '<font color="#FFD23F">[VIP]</font> '
	end
	local rebirths = player:GetAttribute("Rebirths")
	if type(rebirths) == "number" and rebirths > 0 then
		tags ..= string.format('<font color="#B794F6">[♻️%d]</font> ', rebirths)
	end
	return tags
end

function ChatTags:Init()
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local properties = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		if source then
			local tags = ChatTags.prefixFor(Players:GetPlayerByUserId(source.UserId))
			if tags ~= "" then
				properties.PrefixText = tags .. message.PrefixText
			end
		end
		return properties
	end
end

return ChatTags
