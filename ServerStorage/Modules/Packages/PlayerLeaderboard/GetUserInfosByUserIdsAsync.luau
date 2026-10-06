local UserService = game:GetService("UserService")

type UserInfo = {
	Id: number,
	Username: string,
	DisplayName: string,
	HasVerifiedBadge: boolean,
}

local function makeSerialized<A..., R...>(fn: (A...) -> R...): (A...) -> R...
	local busy = false
	local waiters = {}

	local function acquire()
		if not busy then
			busy = true
			return
		end

		local thread = coroutine.running()
		table.insert(waiters, thread)
		coroutine.yield()
	end

	local function release()
		if #waiters > 0 then
			local nextThread = table.remove(waiters, 1)
			task.spawn(nextThread)
		else
			busy = false
		end
	end

	return function(...: A...): R...
		acquire()

		local results = table.pack(pcall(fn, ...))
		release()

		local ok = results[1]
		if not ok then
			error(results[2], 0)
		end

		return table.unpack(results, 2, results.n)
	end
end

local userInfosCache = {}

local function getUserInfosByUserIdsAsync(userIds: {number}): {[number]: UserInfo}
	local userInfos = {}
	local remainingUserIds = {}

	-- Separate cached vs uncached
	for _, userId in userIds do
		if userInfosCache[userId] then
			userInfos[userId] = userInfosCache[userId]
		else
			table.insert(remainingUserIds, userId)
		end
	end

	-- Process in chunks of 10
	for i = 1, #remainingUserIds, 10 do
		local chunk = {}

		for j = i, math.min(i + 10 - 1, #remainingUserIds) do
			table.insert(chunk, remainingUserIds[j])
		end
		local success, result = pcall(function()
			return UserService:GetUserInfosByUserIdsAsync(chunk)
		end)

		if success and result then
			for _, userInfo in result do
				userInfosCache[userInfo.Id] = userInfo
				userInfos[userInfo.Id] = userInfo
			end
		else
			warn("Failed GetUserInfosByUserIdsAsync chunk:", result)
		end
	end

	return userInfos
end

return makeSerialized(getUserInfosByUserIdsAsync)