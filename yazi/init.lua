require("sshfs"):setup()

-- Status bar: mtime, owner:group, and a size/dir marker for the hovered entry
Status:children_add(function()
	local h = cx.active.current.hovered
	if not h then
		return ""
	end

	local cha = h.cha
	local spans = {}

	if cha.is_dir then
		spans[#spans + 1] = ui.Span("<DIR> "):fg("blue")
	end

	if ya.target_family() == "unix" and cha.uid and cha.gid then
		spans[#spans + 1] = ui.Span(ya.user_name(cha.uid) or tostring(cha.uid)):fg("magenta")
		spans[#spans + 1] = ui.Span(":")
		spans[#spans + 1] = ui.Span(ya.group_name(cha.gid) or tostring(cha.gid)):fg("magenta")
		spans[#spans + 1] = ui.Span(" ")
	end

	if cha.mtime then
		spans[#spans + 1] = ui.Span(os.date("%Y-%m-%d %H:%M", math.floor(cha.mtime))):fg("green")
		spans[#spans + 1] = ui.Span(" ")
	end

	return ui.Line(spans)
end, 500, Status.RIGHT)

-- Size linemode without the child-count fallback: dirs stay blank until the
-- `dirsize` fetcher reports their recursive size.
function Linemode:size()
	local size = self._file:size()
	return size and ya.readable_size(size) or ""
end
