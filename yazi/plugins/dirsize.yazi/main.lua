--- @since 26.5.6
--- Fetcher that computes the recursive size of directories, so the `size`
--- linemode shows total bytes instead of falling back to a child count.
---
--- Walking a tree is filesystem-metadata bound and cannot be made meaningfully
--- faster: measured ~0.8s per 163k entries, and neither threads nor an external
--- `du` change that (`du` is ~1.5x quicker on huge trees but ~30x slower on
--- ordinary ones, where process spawn dominates). So this caps the work rather
--- than chasing the walk. A directory that blows the budget is left blank
--- instead of holding a fetch worker hostage -- there are only
--- `tasks.fetch_workers` of them and MIME detection shares the pool, so a few
--- multi-gigabyte directories can otherwise stall previews for the whole pane.
---
--- Exact sizes for those are still one keypress away: `,s` sorts by size, which
--- makes yazi compute them itself.

local BUDGET = 1.0 -- seconds allowed per directory

local M = {}

function M:fetch(job)
	for _, file in ipairs(job.files) do
		if file.cha.is_dir and not file.cha.is_dummy then
			local deadline, complete = ya.time() + BUDGET, false
			local it, size = fs.calc_size(file.url), 0

			while it do
				local chunk = it:recv()
				if not chunk then
					complete = true
					break
				end
				size = size + chunk
				if ya.time() > deadline then
					break
				end
			end

			-- A partial sum would render as a confidently wrong number, so only
			-- report a directory that was walked to completion.
			if complete then
				ya.emit("update_files", {
					op = fs.op("size", { url = file.url.parent, sizes = { [file.url.urn] = size } }),
				})
			end
		end
	end
	return true
end

return M
