-- defs
export type purchase_prompt = { job_id: string, attempted_to_process: boolean, params: params, accepted: boolean }
export type params = {
	target_id: number?,
	[string]: any,
}

-- steps
--  - FAILABLE ensure pending purchase recorded
--  - FAILABLE prompt for purchase
--      - fail: FAILABLE unrecord
--  - FAILABLE record purchase, and unrecord pending
--  - FAILABLE queue purchase
--	- FAILABLE handle purchase

-- functions
local function is_free(pending: purchase_prompt?)
	return pending == nil
end

-- case where
-- JOB 1 - player1 purchase for player2
-- 		 - pending purchase recorded
--       - WAITING FOR prompt state
local function is_pending(pending: purchase_prompt)
	return pending.job_id == game.JobId and not pending.attempted_to_process
end

-- case where
-- JOB 1 - player1 purchase for player2
-- 		 - pending purchase recorded
--       - player reject prompt
--		 - server closes without unrecord rejected pending purchase
-- JOB 2 - player1 still have a pending purchase (that should be cancelled)
--		 - purchase
local function is_dead_prompt(pending: purchase_prompt)
	return pending.job_id ~= game.JobId and not pending.attempted_to_process
end

-- case where
-- JOB 1 - player1 purchase for player2
-- 		 - pending purchase recorded
--       - player accept prompt
--		 - server closes without process purchase
-- JOB 2 - player1 still have a pending purchase
local function is_cross_pending(pending: purchase_prompt): boolean
	return pending.job_id ~= game.JobId and pending.attempted_to_process
end

-- module
return table.freeze({
	is_free = is_free,
	is_local_pending = is_pending,
	is_dead_prompt = is_dead_prompt,
	is_cross_pending = is_cross_pending,
})
