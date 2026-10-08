-- Manual Stop marker, independent of automatic reading tracker.
local ReaderView = require("apps/reader/modules/readerview")
local Blitbuffer = require("ffi/blitbuffer")
local logger = require("logger")
local old_paintTo = ReaderView.paintTo
ReaderView.paintTo = function(self, bb, x, y)
    old_paintTo(self, bb, x, y)
    local ui = self.ui
    local doc = ui and ui.document
    local settings = ui and ui.doc_settings
    if not (doc and settings and doc.getScreenBoxesFromPositions) then return end
    local start_xp = settings:readSetting("last_read_arrow_xpointer")
    local end_xp = settings:readSetting("last_read_arrow_end_xpointer")
    if not (start_xp and end_xp) then return end
    local ok, err = pcall(function()
        local boxes = doc:getScreenBoxesFromPositions(start_xp, end_xp, true)
        if not boxes or #boxes == 0 then return end
        local b = boxes[#boxes]
        local w = (self.dimen and self.dimen.w) or bb:getWidth()
        local h = (self.dimen and self.dimen.h) or bb:getHeight()
        if b.y < 0 or b.y >= h or b.x < 0 or b.x >= w then return end
        local cx = math.floor(b.x + b.w + 3)
        local cy = math.floor(b.y + b.h / 2)
        local size = math.max(4, math.min(7, math.floor(b.h / 3)))
        if cx + size + 1 >= w or cy - size < 0 or cy + size >= h then return end
        for dy = -size, size do
            local thickness = size - math.abs(dy) + 1
            bb:paintRect(x + cx, y + cy + dy, thickness, 1, Blitbuffer.COLOR_BLACK)
        end
    end)
    if not ok then logger.warn("LastReadArrow: paint failed:", err) end
end
