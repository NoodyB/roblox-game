--!strict
-- Daily quests + login streak. Resets at 00:00 UTC.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local GameConfig = require(Shared.Config.GameConfig)
local QuestLogic = require(Shared.Logic.QuestLogic)
local Economy = require(Shared.Logic.Economy)
local Format = require(Shared.Util.Format)
local C = require(script.Parent.Parent.Components)

local Colors = Theme.Colors

return function(request: (string, any?) -> (boolean, any))
	type QuestRow = { card: Frame, text: TextLabel, bar: C.ProgressBar, claim: C.Button, done: TextLabel }
	local questRows: { QuestRow } = {}
	local streakTitle: TextLabel
	local streakInfo: TextLabel
	local streakButton: C.Button
	local footer: TextLabel
	local dayDots: { Frame } = {}

	local function refresh(state: any)
		local now = Workspace:GetServerTimeNow()
		local today = QuestLogic.dayIndex(now)

		-- streak
		local streak = state.streak
		local claimedToday = streak.claimedDay == today
		streakTitle.Text = string.format("🔥 Daily Streak — Day %d of %d", math.max(streak.count, 1), GameConfig.StreakLength)
		local coins = QuestLogic.streakReward(state)
		streakInfo.Text = if claimedToday
			then "Claimed! Come back tomorrow to keep your streak."
			else string.format("Today's reward: %s coins%s", Format.abbreviate(coins), if streak.count == GameConfig.StreakLength then " + 15 min 2x Coins" else "")
		streakButton.setEnabled(not claimedToday)
		streakButton.setText(if claimedToday then "✓ Claimed" else "Claim!")
		for i, dot in dayDots do
			dot.BackgroundColor3 = if i < streak.count or (i == streak.count and claimedToday)
				then Colors.Gold
				elseif i == streak.count then Colors.Accent
				else Colors.BackgroundDark
		end

		-- quests
		for index, row in questRows do
			local quest = state.quests.list[index]
			row.card.Visible = quest ~= nil
			if quest then
				local template = QuestLogic.TemplateById[quest.id]
				local target = if template and template.stat == "coins" then Format.abbreviate(quest.target) else tostring(quest.target)
				row.text.Text = if template then string.format(template.text, target) else quest.id
				row.bar.set(quest.progress / math.max(quest.target, 1), string.format("%s / %s", Format.abbreviate(quest.progress), Format.abbreviate(quest.target)))
				local complete = quest.progress >= quest.target
				row.claim.root.Visible = complete and not quest.claimed
				row.done.Visible = quest.claimed
				if template then
					row.claim.setText("Claim 🪙 " .. Format.abbreviate(Economy.questReward(state, template.reward)))
				end
			end
		end
		footer.Text = string.format(
			"New quests in %s%s",
			Format.time(QuestLogic.secondsUntilReset(now)),
			if state.rebirths > 0 then " · Finish all 3 for a bonus ♻️ Rebirth Token!" else ""
		)
	end

	local function build(content: Frame)
		C.list(Enum.FillDirection.Vertical, 10).Parent = content

		local streakCard = C.card({ Size = UDim2.new(1, 0, 0, 120), BackgroundColor3 = Color3.fromRGB(255, 240, 214), LayoutOrder = 1, Parent = content })
		streakTitle = C.label({ Size = UDim2.new(0.7, 0, 0, 34), Position = UDim2.fromOffset(16, 8), TextXAlignment = Enum.TextXAlignment.Left, Parent = streakCard })
		streakInfo = C.label({ Font = Theme.Fonts.Bold, TextColor3 = Colors.TextLight, Size = UDim2.new(0.7, 0, 0, 24), Position = UDim2.fromOffset(16, 44), TextXAlignment = Enum.TextXAlignment.Left, Parent = streakCard })
		local dots = C.new("Frame", { Size = UDim2.new(0.7, 0, 0, 30), Position = UDim2.fromOffset(16, 78), BackgroundTransparency = 1, Parent = streakCard }, {
			C.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left),
		})
		for i = 1, GameConfig.StreakLength do
			local dot = C.card({ Size = UDim2.fromOffset(44, 28), CornerRadius = 14, LayoutOrder = i, Parent = dots })
			C.outlined({ Text = if i == GameConfig.StreakLength then "🎁" else tostring(i), Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), Parent = dot })
			table.insert(dayDots, dot)
		end
		streakButton = C.button({
			Text = "Claim!",
			Size = UDim2.fromOffset(180, 60),
			Position = UDim2.new(1, -16, 0.5, -3),
			AnchorPoint = Vector2.new(1, 0.5),
			Color = Colors.Gold,
			DarkColor = Colors.GoldDark,
			Parent = streakCard,
			OnClick = function()
				request("ClaimStreak")
			end,
		})

		for index = 1, GameConfig.DailyQuestCount do
			local card = C.card({ Size = UDim2.new(1, 0, 0, 84), LayoutOrder = 1 + index, Parent = content })
			local text = C.label({ Size = UDim2.new(0.62, 0, 0, 30), Position = UDim2.fromOffset(16, 8), TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
			local bar = C.progress({ Size = UDim2.new(0.6, 0, 0, 28), Position = UDim2.fromOffset(16, 46), Color = Colors.Blue, Parent = card })
			local claim = C.button({
				Text = "Claim",
				Size = UDim2.fromOffset(210, 56),
				Position = UDim2.new(1, -16, 0.5, -3),
				AnchorPoint = Vector2.new(1, 0.5),
				Parent = card,
				OnClick = function()
					request("ClaimQuest", index)
				end,
			})
			local done = C.label({ Text = "✅ Done!", Size = UDim2.fromOffset(160, 40), Position = UDim2.new(1, -24, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), TextColor3 = Colors.GreenDark, Visible = false, Parent = card })
			table.insert(questRows, { card = card, text = text, bar = bar, claim = claim, done = done })
		end

		footer = C.label({ Font = Theme.Fonts.Bold, TextColor3 = Colors.TextLight, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 10, Parent = content })
	end

	local ticking = false
	local latest: any = nil
	return {
		key = "Quests",
		title = "📜 Quest Board",
		color = Colors.Blue,
		darkColor = Colors.BlueDark,
		build = build,
		refresh = function(state)
			latest = state
			refresh(state)
		end,
		onOpen = function()
			-- keep countdowns live while open
			if ticking then
				return
			end
			ticking = true
			task.spawn(function()
				while ticking do
					if latest then
						refresh(latest)
					end
					task.wait(1)
				end
			end)
		end,
		onClose = function()
			ticking = false
		end,
	}
end
