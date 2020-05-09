--[[
@description Lua GUI for REAPER
@about
	#### Lua GUI for Cockos Reaper
@noindex
@version 1.1
@author EUGEN27771

	Additional Code: RobU, Lokasenna, Stephane
	Extensions: None
	Licenced under the GPL v3.  
--]]

--------------------------------------------------------------------------------
-- Element Class
--------------------------------------------------------------------------------
--removed local Element
Element = {}
function Element:new(x,y,w,h, r,g,b,a, label,font,font_sz, font_rgba, norm_val,norm_val2)
	local elm = {}
	elm.def_xywh = {x,y,w,h,font_sz} -- its default coord,used for Zoom etc
	elm.x, elm.y, elm.w, elm.h = x, y, w, h
	elm.r, elm.g, elm.b, elm.a = r, g, b, a
	elm.label, elm.font, elm.font_sz  = label, font, font_sz
	elm.font_rgba = font_rgba
	elm.norm_val = norm_val
	elm.norm_val2 = norm_val2
	setmetatable(elm, self)
	self.__index = self 
	return elm
end

--------------------------------------------------------------------------------
-- Metatable Function for Child Classes(args = Child,Parent Class)
--------------------------------------------------------------------------------
function extended(Child, Parent)
	setmetatable(Child,{__index = Parent}) 
end

--------------------------------------------------------------------------------
-- Element Class Methods
--------------------------------------------------------------------------------
function Element:update_xywh()
	if not Z_w or not Z_h then return end -- return if zoom not defined
	self.x, self.w = math.ceil(self.def_xywh[1]* Z_w) , math.ceil(self.def_xywh[3]* Z_w) -- upd x,w
	self.y, self.h = math.ceil(self.def_xywh[2]* Z_h) , math.ceil(self.def_xywh[4]* Z_h) -- upd y,h
	if self.font_sz then --fix it!--
		self.font_sz = math.max(9,self.def_xywh[5]* (Z_w+Z_h)/2)
		self.font_sz = math.min(22,self.font_sz)
	end       
end

--------------------------------------------------------------------------------
function Element:pointIN(p_x, p_y)
	return p_x >= self.x and p_x <= self.x + self.w and p_y >= self.y and p_y <= self.y + self.h
end

--------------------------------------------------------------------------------
function Element:mouseIN()
	return gfx.mouse_cap&1==0 and self:pointIN(gfx.mouse_x,gfx.mouse_y)
end

--------------------------------------------------------------------------------
function Element:mouseDown()
	return gfx.mouse_cap&1==1 and self:pointIN(mouse_ox,mouse_oy)
end

--------------------------------------------------------------------------------
function Element:mouseUp() -- for sliders and knobs only!
	return gfx.mouse_cap&1==0 and self:pointIN(mouse_ox,mouse_oy)
end

--------------------------------------------------------------------------------
function Element:mouseClick()
	return gfx.mouse_cap&1==0 and last_mouse_cap&1==1 and
	self:pointIN(gfx.mouse_x,gfx.mouse_y) and self:pointIN(mouse_ox,mouse_oy)         
end

--------------------------------------------------------------------------------
function Element:mouseRightClick()
	return gfx.mouse_cap&2==0 and last_mouse_cap&2==2 and
	self:pointIN(gfx.mouse_x,gfx.mouse_y) and self:pointIN(mouse_ox,mouse_oy)         
end

--------------------------------------------------------------------------------
function Element:mouseR_Down()
	return gfx.mouse_cap&2==2 and self:pointIN(mouse_ox,mouse_oy)
end

--------------------------------------------------------------------------------
function Element:mouseM_Down()
	return gfx.mouse_cap&64==64 and self:pointIN(mouse_ox,mouse_oy)
end

--------------------------------------------------------------------------------
function Element:draw_frame()
	local x,y,w,h  = self.x,self.y,self.w,self.h
	gfx.rect(x, y, w, h, false)            -- frame1
	gfx.roundrect(x, y, w-1, h-1, 3, true) -- frame2         
end

--------------------------------------------------------------------------------
-- Create Element Child Classes(Button,Checklist,Droplist,Frame,Knob,Sliders,Textbox)
--------------------------------------------------------------------------------
--removed local <elm>
Button = {};	extended(Button, Element)
Checklist = {};	extended(Checklist, Element)
Droplist = {};	extended(Droplist, Element)
Frame = {};	extended(Frame, Element)
Knob = {};	extended(Knob, Element)
Rad_Button = {};	extended(Rad_Button, Element)
Rng_Slider = {};	extended(Rng_Slider, Element)
Slider = {};	extended(Slider, Element)
Textbox = {};	extended(Textbox, Element)
Horz_Slider = {};	extended(Horz_Slider, Slider)
Vert_Slider = {};	extended(Vert_Slider, Slider)

--------------------------------------------------------------------------------
--  Button Class Methods
--------------------------------------------------------------------------------
function Button:draw_body()
	gfx.rect(self.x,self.y,self.w,self.h, true) -- draw btn body
end

--------------------------------------------------------------------------------
function Button:draw_label()
	local x,y,w,h  = self.x,self.y,self.w,self.h
	local label_w, label_h = gfx.measurestr(self.label)
	gfx.x = x+(w-label_w)/2; gfx.y = y+(h-label_h)/2
	gfx.drawstr(self.label)
end

---------------------------------------------------------------------------------
function Button:draw()
	self:update_xywh() -- Update xywh(if wind changed)
	local r,g,b,a  = self.r,self.g,self.b,self.a
	local font,font_sz = self.font, self.font_sz
	-- Get mouse state ---------
	-- in element --------
	if self:mouseIN() then a=a+0.1 end
	-- in elm L_down -----
	if self:mouseDown() then a=a+0.2 end
	-- in elm L_up(released and was previously pressed) --
	if self:mouseClick() and self.onClick then self.onClick() end
	-- right click support
	if self:mouseRightClick() and self.onRightClick then self.onRightClick() end
	-- Draw btn body, frame ----
	gfx.set(r,g,b,a)    -- set body color
	self:draw_body()    -- body
	self:draw_frame()   -- frame
	-- Draw label --------------
	gfx.set(table.unpack(self.font_rgba))   -- set label color
	gfx.setfont(1, font, font_sz) -- set label font
	self:draw_label()             -- draw label
end

--------------------------------------------------------------------------------
-- Checklist Class Methods
--------------------------------------------------------------------------------
function Checklist:set_norm_val()
	local y,h = self.y,self.h
	-- pad the options in from the frame a bit
	y,h = y + 2, h - 4
	local opt_tb = self.norm_val2
	local VAL = math.floor(( (gfx.mouse_y-y)/h ) * #opt_tb) + 1
	if VAL<1 then VAL=1 elseif VAL> #opt_tb then VAL= #opt_tb end
	if self.norm_val[VAL] == 0 then self.norm_val[VAL] = 1
	elseif self.norm_val[VAL] == 1 then self.norm_val[VAL] = 0 end
end

--------------------------------------------------------------------------------
function Checklist:draw_body()
	local x,y,w,h = self.x,self.y,self.w,self.h
	-- pad the options in from the frame a bit
	x,y,w,h = x + 2, y + 2, w - 4, h - 4
	local val = self.norm_val
	local opt_tb = self.norm_val2
	local num_opts = #opt_tb
	local opt_spacing = self.opt_spacing
	local square = 2 * opt_spacing / 3
	local center_offset = ((opt_spacing - square) / 2)
	-- adjust the options to be centered in their spaces
	x, y = x + center_offset, y + center_offset
	--necessary to keep the GUI's resizing code from making the square wobble	
	square = math.floor((square / 4) + 0.5)*4
	for i = 1, num_opts do
		local opt_y = y + ((i - 1) * opt_spacing)
		gfx.roundrect(x, opt_y, square, square, true)
		if val[i] == 1 then
			--fill in the whole square
			gfx.rect(x, opt_y, square + 1, square + 1, true)	
			--draw a smaller dot
			gfx.rect(x + (square / 4), opt_y + (square / 4), square / 2, square / 2, true)
			--give the dot a frame
			gfx.roundrect(x + (square / 4), opt_y + (square / 4), square / 2 - 1, square / 2 - 1, true)
		end
	end
end

--------------------------------------------------------------------------------
function Checklist:draw_vals()
	local x,y,w,h = self.x,self.y,self.w,self.h
	-- pad the options in from the frame a bit
	x,y,w,h = x + 2, y + 2, w - 4, h - 4
	local opt_tb = self.norm_val2
	local num_opts = #opt_tb
	local opt_spacing = self.opt_spacing
	-- to match up with the options
	local square = 2 * opt_spacing / 3
	local center_offset = ((opt_spacing - square) / 2)
	x, y = x + opt_spacing + center_offset, y + center_offset
	for i = 1, num_opts do
		local opt_y = y + ((i - 1) * opt_spacing)
		gfx.x, gfx.y = x, opt_y
		gfx.drawstr(opt_tb[i])
	end
end

--------------------------------------------------------------------------------
function Checklist:draw_label()
	local x,y,h  = self.x, self.y + 2, self.h - 4
	local num_opts = #self.norm_val2
	local opt_spacing = self.opt_spacing
	-- to match up with the first option
	local square = 2 * opt_spacing / 3
	local center_offset = ((opt_spacing - square) / 2)
	y = y + center_offset
	local label_w, label_h = gfx.measurestr(self.label)
	gfx.x = x-label_w-5; gfx.y = y
	gfx.drawstr(self.label) 
end

--------------------------------------------------------------------------------
function Checklist:draw()
	self:update_xywh()
	local r,g,b,a = self.r,self.g,self.b,self.a
	local font,font_sz = self.font, self.font_sz
	self.opt_spacing = (self.h / (#self.norm_val2 or 1))
	-- Get mouse state ---------
	-- in element --------
	if self:mouseIN() then a=a+0.1 end
	-- in elm L_down -----
	if self:mouseDown() then a=a+0.2 end
	-- in elm L_up(released and was previously pressed) --
	if self:mouseClick() then 
		self:set_norm_val()
		if self.onClick then self.onClick() end
	end
	-- right click support
	if self:mouseRightClick() and self.onRightClick then self.onRightClick() end
	gfx.set(r,g,b,a)
	-- allow for a simple toggle with no frame
	if #self.norm_val2 > 1 then self:draw_frame() end
	self:draw_body()
	gfx.set(0.7, 0.9, 0.4, 1)   -- set label,val color
	gfx.setfont(1, font, font_sz) 
	self:draw_vals()
	self:draw_label()
end

--------------------------------------------------------------------------------
-- Droplist Class Methods
--------------------------------------------------------------------------------
function Droplist:set_norm_val_m_wheel()
	if gfx.mouse_wheel == 0 then return false end  -- return if m_wheel = 0
	if gfx.mouse_wheel < 0 then self.norm_val = math.min(self.norm_val+1, #self.norm_val2) end
	if gfx.mouse_wheel > 0 then self.norm_val = math.max(self.norm_val-1, 1) end
	return true
end

--------------------------------------------------------------------------------
function Droplist:set_norm_val()
	local x,y,w,h  = self.x,self.y,self.w,self.h
	local val = self.norm_val
	local menu_tb = self.norm_val2
	local menu_str = ""
	for i=1, #menu_tb, 1 do
		if i~=val then menu_str = menu_str..menu_tb[i].."|"
		else menu_str = menu_str.."!"..menu_tb[i].."|" -- add check
		end
	end
	gfx.x = self.x; gfx.y = self.y + self.h
	local new_val = gfx.showmenu(menu_str)        -- show Droplist menu
	if new_val> 0 then self.norm_val = new_val end -- change check(!)
end

--------------------------------------------------------------------------------
function Droplist:draw_body()
	gfx.rect(self.x,self.y,self.w,self.h, true) -- draw Droplist body
end

--------------------------------------------------------------------------------
function Droplist:draw_label()
	local x,y,w,h  = self.x,self.y,self.w,self.h
	local label_w, label_h = gfx.measurestr(self.label)
	--gfx.x = x-label_w-5
	--gfx.y = y +(h-label_h)/2
	gfx.x = x + ((w/2) - (label_w/2))
	gfx.y = y - ((label_h) + (label_h/3))
	gfx.drawstr(self.label) -- draw Droplist label
end

--------------------------------------------------------------------------------
function Droplist:draw_val()
	local x,y,w,h  = self.x,self.y,self.w,self.h
	local val = self.norm_val2[self.norm_val]
	local val_w, val_h = gfx.measurestr(val)
	--gfx.x = x+5
	gfx.x = x + ((w/2) - (val_w/2))
	gfx.y = y+(h-val_h)/2
	gfx.drawstr(val) -- draw Droplist val
end

--------------------------------------------------------------------------------
function Droplist:draw()
	self:update_xywh() -- Update xywh(if wind changed)
	local r,g,b,a  = self.r,self.g,self.b,self.a
	local font,font_sz = self.font, self.font_sz
	-- Get mouse state ---------
	-- in element --------
	if self:mouseIN() then a=a+0.1 
		if self:set_norm_val_m_wheel() then 
			if self.onClick then self.onClick() end 
		end 
	end
	-- in elm L_down -----
	if self:mouseDown() then a=a+0.2 end
	-- in elm L_up(released and was previously pressed) --
	if self:mouseClick() then self:set_norm_val()
		if self:mouseClick() and self.onClick then self.onClick() end
	end
	-- right click support
	if self:mouseRightClick() and self.onRightClick then self.onRightClick() end
	-- Draw combo body, frame -
	gfx.set(r,g,b,a) -- set body color
	self:draw_body() -- body
	self:draw_frame() -- frame
	-- Draw label --------------
	gfx.set(table.unpack(self.font_rgba)) -- set label,val color
	gfx.setfont(1, font, font_sz) -- set label,val font
	self:draw_label() -- draw label
	self:draw_val() -- draw val
end

--------------------------------------------------------------------------------
-- Frame Class Methods
--------------------------------------------------------------------------------
function Frame:draw()
	self:update_xywh() -- Update xywh(if wind changed)
	local r,g,b,a  = self.r,self.g,self.b,self.a
	if self:mouseIN() then a=a+0.1 end
	gfx.set(r,g,b,a)   -- set frame color
	self:draw_frame()  -- draw frame
end

--------------------------------------------------------------------------------
-- Knob Class Methods
--------------------------------------------------------------------------------
function Knob:update_xywh() -- redefine method for Knob
	if not Z_w or not Z_h then return end -- return if zoom not defined
	local w_h = math.ceil( math.min(self.def_xywh[3]*Z_w, self.def_xywh[4]*Z_h) )
	self.x = math.ceil(self.def_xywh[1]* Z_w)
	self.y = math.ceil(self.def_xywh[2]* Z_h)
	self.w, self.h = w_h, w_h
	if self.font_sz then --fix it!--
		self.font_sz = math.max(7, self.def_xywh[5]* (Z_w+Z_h)/2)--fix it!
		self.font_sz = math.min(20,self.font_sz) 
	end 
end

--------------------------------------------------------------------------------
function Knob:set_norm_val()
	local y, h  = self.y, self.h
	local VAL,K = 0,10 -- VAL=temp value;K=coefficient(when Ctrl pressed)
	if Ctrl then VAL = self.norm_val + ((last_y-gfx.mouse_y)/(h*K))
	else VAL = (h-(gfx.mouse_y-y))/h end
	if VAL<0 then VAL=0 elseif VAL>1 then VAL=1 end
	self.norm_val=VAL
end

--------------------------------------------------------------------------------
function Knob:set_norm_val_m_wheel()
  local Step = 0.05 -- Set step
  if gfx.mouse_wheel == 0 then return end  -- return if m_wheel = 0
  if gfx.mouse_wheel > 0 then self.norm_val = math.min(self.norm_val+Step, 1) end
  if gfx.mouse_wheel < 0 then self.norm_val = math.max(self.norm_val-Step, 0) end
  return true
end

--------------------------------------------------------------------------------
function Knob:draw_body()
  local x,y,w,h  = self.x,self.y,self.w,self.h
  local k_x, k_y, r = x+w/2, y+h/2, (w+h)/4
  local pi=math.pi
  local offs = pi+pi/4
  local val = 1.5*pi * self.norm_val
  local ang1, ang2 = offs-0.01, offs + val
  gfx.circle(k_x,k_y,r-1, false)  -- external
  for i=1,10 do
    gfx.arc(k_x, k_y, r-2,  ang1, ang2, true)
    r=r-1; -- gfx.a=gfx.a+0.005 -- variant
  end
  gfx.circle(k_x, k_y, r-1, true) -- internal
end

--------------------------------------------------------------------------------
function Knob:draw_label()
  local x,y,w,h  = self.x,self.y,self.w,self.h
  local label_w, label_h = gfx.measurestr(self.label)
  gfx.x = x+(w-label_w)/2; gfx.y = y+h/2
  gfx.drawstr(self.label) -- draw knob label
end

--------------------------------------------------------------------------------
function Knob:draw_val()
  local x,y,w,h  = self.x,self.y,self.w,self.h
  local val = string.format("%.2f", self.norm_val)
  local val_w, val_h = gfx.measurestr(val)
  gfx.x = x+(w-val_w)/2; gfx.y = (y+h/2)-val_h-3
  gfx.drawstr(val) -- draw knob Value
end

--------------------------------------------------------------------------------
function Knob:draw()
  self:update_xywh() -- Update xywh(if wind changed)
  local r,g,b,a  = self.r,self.g,self.b,self.a
  local font,font_sz = self.font, self.font_sz
  -- Get mouse state ---------
  -- in element(and get mouswheel) --
  if self:mouseIN() then a=a+0.1
    if self:set_norm_val_m_wheel() then 
      if self.onMove then self.onMove() end 
    end  
  end
  -- in elm L_down -----
  if self:mouseDown() then a=a+0.2 
    self:set_norm_val()
    if self.onMove then self.onMove() end 
  end
  -- right click support
  if self:mouseRightClick() and self.onRightClick then self.onRightClick() end
  -- in elm L_up(released and was previously pressed) --
  -- if self:mouseClick() and self.onClick then self.onClick() end
  -- Draw knob body, frame ---
  gfx.set(r,g,b,a)    -- set body,frame color
  self:draw_body()    -- body
  --self:draw_frame() -- frame(if need)
  -- Draw label,value --------
  gfx.set(table.unpack(self.font_rgba))   -- set label,val color
  gfx.setfont(1, font, font_sz) -- set label,val font
  --self:draw_label()   -- draw label(if need)
  self:draw_val()     -- draw value
end

--------------------------------------------------------------------------------
--  Radio_Button Class Methods
--------------------------------------------------------------------------------
function Rad_Button:set_norm_val_m_wheel()
  if gfx.mouse_wheel == 0 then return false end  -- return if m_wheel = 0
  if gfx.mouse_wheel < 0 then self.norm_val = math.min(self.norm_val+1, #self.norm_val2) end
  if gfx.mouse_wheel > 0 then self.norm_val = math.max(self.norm_val-1, 1) end
  return true
end

--------------------------------------------------------------------------------
function Rad_Button:set_norm_val()
  local y,h = self.y,self.h
  -- pad the options in from the frame a bit
  y,h = y + 2, h - 4
  local opt_tb = self.norm_val2
  local VAL = math.floor(( (gfx.mouse_y-y)/h ) * #opt_tb) + 1
  if VAL<1 then VAL=1 elseif VAL> #opt_tb then VAL= #opt_tb end
  self.norm_val=VAL
end

--------------------------------------------------------------------------------
function Rad_Button:draw_body()
  local x,y,w,h = self.x,self.y,self.w,self.h
  -- pad the options in from the frame a bit
  x,y,w,h = x + 2, y + 2, w - 4, h - 4
  local val = self.norm_val
  local opt_tb = self.norm_val2
  local num_opts = #opt_tb
  local opt_spacing = self.opt_spacing
  local r = opt_spacing / 3
  local center_offset = ((opt_spacing - (2 * r)) / 2)
  -- adjust the options to be centered in their spaces
  x, y = x + center_offset, y + center_offset

  for i = 1, num_opts do
    local opt_y = y + ((i - 1) * opt_spacing)
    gfx.circle(x + r, opt_y + r, r, false)
    if i == val then
      --fill in the whole circle
      gfx.circle(x + r, opt_y + r, r, true)	
      --draw a smaller dot
      gfx.circle(x + r, opt_y + r, r * 0.5, true)
      --give the dot a frame
      gfx.circle(x + r, opt_y + r, r * 0.5, false)
    end
  end
end

--------------------------------------------------------------------------------
function Rad_Button:draw_vals()
  local x,y,w,h = self.x,self.y,self.w,self.h
  -- pad the options in from the frame a bit
  x,y,w,h = x + 2, y + 2, w - 4, h - 4
  local opt_tb = self.norm_val2
  local num_opts = #opt_tb
  local opt_spacing = self.opt_spacing
  -- to match up with the options
  local r = opt_spacing / 3
  local center_offset = ((opt_spacing - (2 * r)) / 2)
  x, y = x + opt_spacing + center_offset, y + center_offset
  for i = 1, num_opts do
    local opt_y = y + ((i - 1) * opt_spacing)
    gfx.x, gfx.y = x, opt_y
    gfx.drawstr(opt_tb[i])
  end
end

--------------------------------------------------------------------------------
function Rad_Button:draw_label()
  local x,y,h  = self.x, self.y + 2, self.h - 4
  local num_opts = #self.norm_val2
  local opt_spacing = self.opt_spacing
  -- to match up with the first option
  local r = opt_spacing / 3
  local center_offset = ((opt_spacing - (2 * r)) / 2)
  y = y + center_offset
  local label_w, label_h = gfx.measurestr(self.label)
  gfx.x = x-label_w-5; gfx.y = y
  gfx.drawstr(self.label) 
end

--------------------------------------------------------------------------------
function Rad_Button:draw()
  self:update_xywh()
  local r,g,b,a = self.r,self.g,self.b,self.a
  local font,font_sz = self.font, self.font_sz
  self.opt_spacing = (self.h / (#self.norm_val2 or 1))
  -- Get mouse state ---------
  -- in element --------
  if self:mouseIN() then a=a+0.1 
    if self:set_norm_val_m_wheel() then 
      if self.onClick then self.onClick() end 
    end 
  end
  -- in elm L_down -----
  if self:mouseDown() then a=a+0.2 end
  -- in elm L_up(released and was previously pressed) --
  if self:mouseClick() then 
    self:set_norm_val()
    if self.onClick then self.onClick() end
  end
  -- right click support
  if self:mouseRightClick() and self.onRightClick then self.onRightClick() end
  gfx.set(r,g,b,a)
  self:draw_frame()	
  self:draw_body()
  gfx.set(0.7, 0.9, 0.4, 1)   -- set label,val color
  gfx.setfont(1, font, font_sz) 
  self:draw_vals()
  self:draw_label()
end

--------------------------------------------------------------------------------
-- Slider Class Methods
--------------------------------------------------------------------------------
function Slider:set_norm_val_m_wheel()
  local Step = 0.1 -- Set step
  if gfx.mouse_wheel == 0 then return false end  -- return if m_wheel = 0
  if gfx.mouse_wheel > 0 then self.norm_val = math.min(self.norm_val+Step, 1) end
  if gfx.mouse_wheel < 0 then self.norm_val = math.max(self.norm_val-Step, 0) end
  return true
end

--------------------------------------------------------------------------------
function Horz_Slider:set_norm_val()
  local x, w = self.x, self.w
  local VAL,K = 0,10 -- VAL=temp value;K=coefficient(when Ctrl pressed)
  if Ctrl then VAL = self.norm_val + ((gfx.mouse_x-last_x)/(w*K))
  else VAL = (gfx.mouse_x-x)/w end
  if VAL<0 then VAL=0 elseif VAL>1 then VAL=1 end
  self.norm_val=VAL
end

--------------------------------------------------------------------------------
function Horz_Slider:draw_body()
  local x,y,w,h  = self.x,self.y,self.w,self.h
  local val = w * self.norm_val
  gfx.rect(x,y, val, h, true) -- draw Horz_Slider body
end

--------------------------------------------------------------------------------
function Horz_Slider:draw_label()
  local x,y,w,h  = self.x,self.y,self.w,self.h
  local label_w, label_h = gfx.measurestr(self.label)
  gfx.x = x+5; gfx.y = y+(h-label_h)/2;
  gfx.drawstr(self.label) -- draw Horz_Slider label
end

--------------------------------------------------------------------------------
function Horz_Slider:draw_val()
  local x,y,w,h  = self.x,self.y,self.w,self.h
  local val = string.format("%.2f", self.norm_val)
  local val_w, val_h = gfx.measurestr(val)
  gfx.x = x+w-val_w-5; gfx.y = y+(h-val_h)/2;
  gfx.drawstr(val) -- draw Horz_Slider Value
end

--------------------------------------------------------------------------------
function Vert_Slider:set_norm_val()
  local y, h  = self.y, self.h
  local VAL,K = 0,10 -- VAL=temp value;K=coefficient(when Ctrl pressed)
  if Ctrl then VAL = self.norm_val + ((last_y-gfx.mouse_y)/(h*K))
  else VAL = (h-(gfx.mouse_y-y))/h end
  if VAL<0 then VAL=0 elseif VAL>1 then VAL=1 end
  self.norm_val=VAL
end

--------------------------------------------------------------------------------
function Vert_Slider:draw_body()
  local x,y,w,h  = self.x,self.y,self.w,self.h
  local val = h * self.norm_val
  gfx.rect(x,y+h-val, w, val, true) -- draw Vert_Slider body
end

--------------------------------------------------------------------------------
function Vert_Slider:draw_label()
  local x,y,w,h  = self.x,self.y,self.w,self.h
  local label_w, label_h = gfx.measurestr(self.label)
  gfx.x = x+(w-label_w)/2; gfx.y = y+h-label_h-5;
  gfx.drawstr(self.label) -- draw Vert_Slider label
end

--------------------------------------------------------------------------------
function Vert_Slider:draw_val()
  local x,y,w,h  = self.x,self.y,self.w,self.h
  local val = string.format("%.1f", self.norm_val)
  local val_w, val_h = gfx.measurestr(val)
  gfx.x = x+(w-val_w)/2; gfx.y = y+5;
  gfx.drawstr(val) -- draw Vert_Slider Value
end

--------------------------------------------------------------------------------
function Slider:draw()
  self:update_xywh() -- Update xywh(if wind changed)
  local r,g,b,a  = self.r,self.g,self.b,self.a
  local font,font_sz = self.font, self.font_sz
  -- Get mouse state ---------
  -- in element(and get mouswheel) --
  if self:mouseIN() then a=a+0.1
    if self:set_norm_val_m_wheel() then 
      if self.onMove then self.onMove() end 
    end  
  end
  -- in elm L_down -----
  if self:mouseDown() then a=a+0.2 
    self:set_norm_val()
    if self.onMove then self.onMove() end 
  end
  -- right click support
  if self:mouseRightClick() and self.onRightClick then self.onRightClick() end
  -- in elm L_up(released and was previously pressed) --
  -- if self:mouseClick() and self.onClick then self.onClick() end
  -- Draw sldr body, frame ---
  gfx.set(r,g,b,a)  -- set body,frame color
  self:draw_body()  -- body
  self:draw_frame() -- frame
  -- Draw label,value --------
  gfx.set(table.unpack(self.font_rgba))   -- set label,val color
  gfx.setfont(1, font, font_sz) -- set label,val font
  self:draw_label()   -- draw label
  self:draw_val()   -- draw value
end

--------------------------------------------------------------------------------
-- Rng_Slider Class Methods
--------------------------------------------------------------------------------
function Rng_Slider:pointIN_Ls(p_x, p_y)
  local x, w, sb_w = self.rng_x, self.rng_w, self.sb_w
  local val = w * self.norm_val
  x = x+val-sb_w -- left sbtn x; x-10 extend mouse zone to the left(more comfortable) 
  return p_x >= x-10 and p_x <= x + sb_w and p_y >= self.y and p_y <= self.y + self.h
end

--------------------------------------------------------------------------------
function Rng_Slider:pointIN_Rs(p_x, p_y)
  local x, w, sb_w = self.rng_x, self.rng_w, self.sb_w
  local val = w * self.norm_val2
  x = x+val -- right sbtn x; x+10 extend mouse zone to the right(more comfortable)
  return p_x >= x and p_x <= x+10 + sb_w and p_y >= self.y and p_y <= self.y + self.h
end

--------------------------------------------------------------------------------
function Rng_Slider:pointIN_rng(p_x, p_y)
  local x  = self.rng_x + self.rng_w * self.norm_val  -- start rng
  local x2 = self.rng_x + self.rng_w * self.norm_val2 -- end rng
  return p_x >= x+5 and p_x <= x2-5 and p_y >= self.y and p_y <= self.y + self.h
end

--------------------------------------------------------------------------------
function Rng_Slider:mouseIN_Ls()
  return gfx.mouse_cap&1==0 and self:pointIN_Ls(gfx.mouse_x,gfx.mouse_y)
end

--------------------------------------------------------------------------------
function Rng_Slider:mouseIN_Rs()
  return gfx.mouse_cap&1==0 and self:pointIN_Rs(gfx.mouse_x,gfx.mouse_y)
end

--------------------------------------------------------------------------------
function Rng_Slider:mouseIN_rng()
  return gfx.mouse_cap&1==0 and self:pointIN_rng(gfx.mouse_x,gfx.mouse_y)
end

--------------------------------------------------------------------------------
function Rng_Slider:mouseDown_Ls()
  return gfx.mouse_cap&1==1 and last_mouse_cap&1==0 and self:pointIN_Ls(mouse_ox,mouse_oy)
end

--------------------------------------------------------------------------------
function Rng_Slider:mouseDown_Rs()
  return gfx.mouse_cap&1==1 and last_mouse_cap&1==0 and self:pointIN_Rs(mouse_ox,mouse_oy)
end

--------------------------------------------------------------------------------
function Rng_Slider:mouseDown_rng()
  return gfx.mouse_cap&1==1 and last_mouse_cap&1==0 and self:pointIN_rng(mouse_ox,mouse_oy)
end

--------------------------------------------------------------------------------
function Rng_Slider:set_norm_val()
  local x, w = self.rng_x, self.rng_w
  local VAL,K = 0,10 -- VAL=temp value;K=coefficient(when Ctrl pressed)
  if Ctrl then VAL = self.norm_val + ((gfx.mouse_x-last_x)/(w*K))
  else VAL = (gfx.mouse_x-x)/w end
  -- valid val --
  if VAL<0 then VAL=0 elseif VAL>self.norm_val2 then VAL=self.norm_val2 end
  self.norm_val=VAL
end

--------------------------------------------------------------------------------
function Rng_Slider:set_norm_val2()
  local x, w = self.rng_x, self.rng_w
  local VAL,K = 0,10 -- VAL=temp value;K=coefficient(when Ctrl pressed)
  if Ctrl then VAL = self.norm_val2 + ((gfx.mouse_x-last_x)/(w*K))
  else VAL = (gfx.mouse_x-x)/w end
  -- valid val2 --
  if VAL<self.norm_val then VAL=self.norm_val elseif VAL>1 then VAL=1 end
  self.norm_val2=VAL
end

--------------------------------------------------------------------------------
function Rng_Slider:set_norm_val_both()
  local x, w = self.x, self.w
  local diff = self.norm_val2 - self.norm_val -- values difference
  local K = 1           -- K = coefficient
  if Ctrl then K=10 end -- when Ctrl pressed
  local VAL  = self.norm_val  + (gfx.mouse_x-last_x)/(w*K)
  -- valid values --
  if VAL<0 then VAL = 0 elseif VAL>1-diff then VAL = 1-diff end
  self.norm_val  = VAL
  self.norm_val2 = VAL + diff
end

--------------------------------------------------------------------------------
function Rng_Slider:draw_body()
  local x,y,w,h  = self.rng_x,self.y,self.rng_w,self.h
  local val  = w * self.norm_val
  local val2 = w * self.norm_val2
  gfx.rect(x+val, y, val2-val, h, true) -- draw body
end

--------------------------------------------------------------------------------
function Rng_Slider:draw_sbtns()
  local r,g,b,a  = self.r,self.g,self.b,self.a
  local x,y,w,h  = self.rng_x,self.y,self.rng_w,self.h
  local sb_w = self.sb_w
  local val  = w * self.norm_val
  local val2 = w * self.norm_val2
  gfx.set(r,g,b,1)  -- sbtns body color
  gfx.rect(x+val-sb_w, y, sb_w, h, true) -- sbtn1 body
  gfx.rect(x+val2,     y, sb_w, h, true) -- sbtn2 body
  gfx.set(0,0,0,1)  -- sbtns frame color
  gfx.rect(x+val-sb_w-1, y-1, sb_w+2, h+2, false) -- sbtn1 frame
  gfx.rect(x+val2-1,     y-1, sb_w+2, h+2, false) -- sbtn2 frame
end

--------------------------------------------------------------------------------
function Rng_Slider:draw_val() -- variant 2
  local x,y,w,h  = self.x,self.y,self.w,self.h
  local val  = string.format("%.2f", self.norm_val)
  local val2 = string.format("%.2f", self.norm_val2)
  local val_w,  val_h  = gfx.measurestr(val)
  local val2_w, val2_h = gfx.measurestr(val2)
  local T = 0 -- set T = 0 or T = h (var1, var2 text position) 
  gfx.x = x+5
  gfx.y = y+(h-val_h)/2 + T
  gfx.drawstr(val)  -- draw value 1
  gfx.x = x+w-val2_w-5
  gfx.y = y+(h-val2_h)/2 + T
  gfx.drawstr(val2) -- draw value 2
end

--------------------------------------------------------------------------------
function Rng_Slider:draw_label()
  local x,y,w,h  = self.x,self.y,self.w,self.h
  local label_w, label_h = gfx.measurestr(self.label)
  local T = 0 -- set T = 0 or T = h (var1, var2 text position)
  gfx.x = x+(w-label_w)/2
  gfx.y = y+(h-label_h)/2 + T
  gfx.drawstr(self.label)
end

--------------------------------------------------------------------------------
function Rng_Slider:draw()
  self:update_xywh() -- Update xywh(if wind changed)
  local x,y,w,h  = self.x,self.y,self.w,self.h
  local r,g,b,a  = self.r,self.g,self.b,self.a
  local font,font_sz = self.font, self.font_sz
  -- set additional coordinates --
  self.sb_w  = math.floor(self.w/30) -- sidebuttons width(change it if need)
  self.rng_x = self.x + self.sb_w    -- range streak min x
  self.rng_w = self.w - self.sb_w*2  -- range streak max w
  -- Get mouse state -------------
  -- Reset Ls,Rs states --
  if gfx.mouse_cap&1==0 then self.Ls_state, self.Rs_state, self.rng_state = false,false,false end
  -- in element --
  if self:mouseIN_Ls() or self:mouseIN_Rs() then a=a+0.1 end
  -- in elm L_down --
  if self:mouseDown_Ls()  then self.Ls_state = true end
  if self:mouseDown_Rs()  then self.Rs_state = true end
  if self:mouseDown_rng() then self.rng_state = true end
  ----------------
  if self.Ls_state  == true then a=a+0.2; self:set_norm_val()      end
  if self.Rs_state  == true then a=a+0.2; self:set_norm_val2()     end
  if self.rng_state == true then a=a+0.2; self:set_norm_val_both() end
  if (self.Ls_state or self.Rs_state or self.rng_state) and self.onMove then self.onMove() end
  -- right click support
  if self:mouseRightClick() and self.onRightClick then self.onRightClick() end
  -- in elm L_up(released and was previously pressed) --
  -- if self:mouseClick() and self.onClick then self.onClick() end
  -- Draw sldr body, frame, sidebuttons --
  gfx.set(r,g,b,a)  -- set color
  self:draw_body()  -- body
  self:draw_frame() -- frame
  self:draw_sbtns() -- draw L,R sidebuttons
  -- Draw label,values --
  gfx.set(0.7, 0.9, 0.4, 1)   -- set label color
  gfx.setfont(1, font, font_sz) -- set label,val font
  self:draw_label() -- draw label
  self:draw_val() -- draw value
end

--------------------------------------------------------------------------------
--  Textbox Class Methods
--------------------------------------------------------------------------------
function Textbox:draw_body()
  gfx.rect(self.x,self.y,self.w,self.h, true) -- draw Textbox body
end

--------------------------------------------------------------------------------
function Textbox:draw_label()
  local x,y,w,h  = self.x,self.y,self.w,self.h
  local label_w, label_h = gfx.measurestr(self.label)
  gfx.x = x+(w-label_w)/2; gfx.y = y+(h-label_h)/2
  gfx.drawstr(self.label)
end

---------------------------------------------------------------------------------
function Textbox:draw()
  self:update_xywh() -- Update xywh(if wind changed)
  local r,g,b,a  = self.r,self.g,self.b,self.a
  local font,font_sz = self.font, self.font_sz
  -- Get mouse state ---------
  -- in element --------
  --if self:mouseIN() then a=a+0.1 end
  -- in elm L_down -----
  --if self:mouseDown() then a=a+0.2 end
  -- in elm L_up(released and was previously pressed) --
  --if self:mouseClick() and self.onClick then self.onClick() end
  -- right click support
  --if self:mouseRightClick() and self.onRightClick then self.onRightClick() end
  -- Draw btn body, frame ----
  gfx.set(r,g,b,a)    -- set body color
  self:draw_body()    -- body
  self:draw_frame()   -- frame
  -- Draw label --------------
  gfx.set(table.unpack(self.font_rgba))   -- set label color
  gfx.setfont(1, font, font_sz) -- set label font
  self:draw_label()             -- draw label
end

---------------------------------------------------------------------------------

