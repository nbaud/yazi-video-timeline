-- video-timeline.yazi

local M = {}

local SCRIPT = os.getenv("HOME") .. "/.config/yazi/plugins/video-timeline.yazi/preview.sh"

-- Tuning knobs
local SLICE = 10            -- offsets: 0..9
local TICK_SECONDS = 2.0    -- slideshow speed
local READ_TIMEOUT_MS = 500 -- child read timeout
local META_LINES = 16       -- bottom pane height in terminal rows

-- --- helpers ---------------------------------------------------------------

local function clamp_int(n, lo, hi)
	n = tonumber(n) or 0
	if n < lo then return lo end
	if n > hi then return hi end
	return n
end

local function normalize_offset(skip)
	-- convert any numeric skip into 0..SLICE-1
	local o = tonumber(skip) or 0
	if o < 0 then o = 0 end
	return o % SLICE
end

local function strip_ansi(s)
	s = s:gsub("\27%[[%;%d]*m", "")
	s = s:gsub("\27%[[%;%d]*K", "")
	s = s:gsub("\27%[[%;%d]*%G", "")
	return s
end

local function split_top_bottom(area, bottom_rows)
	-- Keep a fixed-height metadata area at the bottom so layout is stable.
	local x, y, w, h = area.x, area.y, area.w, area.h
	bottom_rows = clamp_int(bottom_rows or META_LINES, 6, math.max(6, h - 2))

	local top = ui.Rect({ x = x, y = y, w = w, h = h - bottom_rows })
	local bottom = ui.Rect({ x = x, y = y + (h - bottom_rows), w = w, h = bottom_rows })
	return top, bottom
end

local function centered_msg_rect(area, msg_len)
	return ui.Rect({
		x = area.x + math.floor(area.w / 2) - math.floor(msg_len / 2),
		y = area.y + math.floor(area.h / 2),
		w = area.w,
		h = 1,
	})
end

local function show_status(job, area, msg)
	local r = centered_msg_rect(area, #msg)
	ya.preview_widget(job, { ui.Text(msg):area(r) })
end

local function spawn_preview(path, offset, top_area)
	-- preview.sh supports extra args; it can ignore them.
	local args = {
		"--path", path,
		"--offset", tostring(offset),
		"--topw", tostring(top_area.w),
		"--toph", tostring(top_area.h),
	}

	return Command(SCRIPT)
		:arg(args)
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:spawn()
end

local function parse_image_marker(line)
	-- Expected: "__preview__image__path__ /some/path\n"
	if not line:match("^__preview__image__path__") then
		return nil
	end
	return line:match("^__preview__image__path__ (.+)\n")
end

local function should_keep_text(line)
	if line:len() <= 1 then return false end
	if line:match("^__") then return false end
	return true
end

local function read_child_output(job, child, top_area, bottom_area)
	-- Reads the entire child output, but caps stored metadata lines to bottom_area.h
	local meta, errs = {}, {}

	while true do
		local line, event = child:read_line_with({ timeout = READ_TIMEOUT_MS })

		if event == 3 then
			-- timeout
			show_status(job, bottom_area, "Loading...")
		elseif event == 2 then
			-- EOF
			break
		elseif event == 1 then
			-- stderr
			table.insert(errs, strip_ansi(line))
		elseif event == 0 then
			-- stdout
			local img = parse_image_marker(line)
			if img then
				ya.image_show(Url(img), top_area)
			else
				if should_keep_text(line) and #meta < bottom_area.h then
					table.insert(meta, strip_ansi(line))
				end
			end
		end
	end

	child:start_kill()
	return errs, meta
end

local function render_text(job, area, errs, meta)
	local out = table.concat(errs, "") .. table.concat(meta, "")
	ya.preview_widget(job, { ui.Text(out):area(area) })
end

local function schedule_next(file_url, offset)
	ya.sleep(TICK_SECONDS)
	ya.emit("peek", {
		tostring((offset + 1) % SLICE),
		only_if = file_url,
	})
end

-- --- yazi hooks ------------------------------------------------------------

function M:peek(job)
	local file = job.file
	local area = job.area

	local top, bottom = split_top_bottom(area, META_LINES)

	local offset = normalize_offset(job.skip)
	local file_url = tostring(file.url)

	local child = spawn_preview(file_url, offset, top)
	if not child then
		render_text(job, bottom, {}, { "Failed to start preview script\n" })
		return
	end

	local errs, meta = read_child_output(job, child, top, bottom)
	render_text(job, bottom, errs, meta)

	schedule_next(file_url, offset)
end

function M:seek(job)
	-- Scrub-like behavior: only re-peek if the same file is still hovered.
	local h = cx.active.current.hovered
	if not (h and h.url == job.file.url) then
		return
	end

	local next_skip = (tonumber(job.skip) or 0) + (tonumber(job.units) or 0)
	if next_skip < 0 then next_skip = 0 end

	ya.emit("peek", {
		tostring(next_skip),
		only_if = tostring(job.file.url),
	})
end

return M

