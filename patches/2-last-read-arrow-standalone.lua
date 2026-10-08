-- Standalone manual reading marker for KOReader (EPUB/reflowable books).
-- Works with or without Floating Dictionary. Uses the same per-book keys
-- as the Read-Marker Floating Dictionary Stop button.
local ReaderView = require("apps/reader/modules/readerview")
local ReaderHighlight = require("apps/reader/modules/readerhighlight")
local Blitbuffer = require("ffi/blitbuffer")
local UIManager = require("ui/uimanager")
local Notification = require("ui/widget/notification")
local logger = require("logger")
local _ = require("gettext")

-- Add a button to KOReader's native text-selection menu.
local old_init = ReaderHighlight.init
ReaderHighlight.init = function(self, ...)
    old_init(self, ...)
    self:addToHighlightDialog("07_manual_last_read", function(this)
        return {
            text = _("Mark as Last Read"),
            show_in_highlight_dialog_func = function()
                return this.ui and this.ui.doc_settings and this.selected_text
                    and this.selected_text.pos0 and this.selected_text.pos1
                    and this.ui.document and not this.ui.document.info.has_pages
            end,
            callback = function()
                local selection = this.selected_text
                local settings = this.ui and this.ui.doc_settings
                if not (selection and selection.pos0 and selection.pos1 and settings) then
                    UIManager:show(Notification:new{text = _("Could not determine text position")})
                    return
                end
                settings:saveSetting("last_read_arrow_xpointer", selection.pos0)
                settings:saveSetting("last_read_arrow_end_xpointer", selection.pos1)
                this:onClose()
                UIManager:show(Notification:new{text = _("Reading position marked")})
                if this.ui and this.ui.dialog then
                    UIManager:setDirty(this.ui.dialog, "ui")
                end
            end,
        }
    end)
end

-- Draw a visible arrow immediately to the right of the marked word.
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
        local size = math.max(10, math.min(16, math.floor(b.h / 2)))
        if cx + size + 1 >= w or cy - size < 0 or cy + size >= h then return end
        for dy = -size, size do
            local thickness = size - math.abs(dy) + 1
            bb:paintRect(x + cx, y + cy + dy, thickness, 1, Blitbuffer.COLOR_BLACK)
        end
    end)
    if not ok then logger.warn("LastReadArrow: paint failed:", err) end
end
