--[[
@description MIDI Note Randomizer
@about
	#### MIDI Note Randomizer
	Scale based note randomisation

	Move sliders, press buttons
@donation https://www.paypal.me/RobUrquhart
@link Forum Thread http://forum.cockos.com/showthread.php?t=188774
@version 1.1
@author RobU
@changelog
	v1.1
	bugfixes
@provides
	[main=midi_editor] .
	[nomain] eugen27771 GUI.lua

Reaper 5.x
Extensions: None
Licenced under the GPL v3
--]]

--------------------------------------------------------------------------------
-- REQUIRES
--------------------------------------------------------------------------------
package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path
require 'eugen27771 GUI'
--------------------------------------------------------------------------------
-- GLOBAL VARIABLES START
--------------------------------------------------------------------------------
m = {}
m.win_x = 700; m.win_y = 280
m.winCol = {0, 0, 0}; m.h1FontCol = {.7, .7, .7, .9}; m.stdFontCol = {.7, .7, .7, .9}

-- default octave, key, and root (root = octave + key)
m.oct = 4; m.key = 1; m.root = 0 -- due to some quirk, m.oct=4 is really octave 3...
-- note tables - b & c for note mangling, a for restoring the original take
m.allNotesF = false

m.notebuf = {a = {}, b = {}, c = {}}
m.dupes = {}

m.notes = {'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B', 'C'}

m.scales = {
	{0,1,2,3,4,5,6,7,8,9,10,11,12,name="Chromatic"},
	{0,2,4,5,7,9,11,12,name="Ionian / Major"},
	{0,2,3,5,6,9,10,12,name="Dorian"},
	{0,1,3,5,7,8,10,12,name="Phrygian"},
	{0,2,4,6,7,9,11,12,name="Lyndian"},
	{0,2,4,5,7,9,10,12,name="Mixolydian"},
	{0,2,3,5,7,8,10,12,name="Aeolian / Minor"},
	{0,1,3,5,6,8,10,12,name="Locrian"},
	{0,3,5,6,7,10,12,name="Blues"},
	{0,2,4,7,9,12,name="Pentatonic Major"},
	{0,3,5,7,10,12,name="Pentatonic Minor"}
-- scales available to the randomization engine, more can be added if required
-- each value is the interval step from the root note of the scale (0) including the octave (12)
-- ToDo: Load / Save to disk (persistence)
-- ToDo: Allow creation of custom user scales within GUI
-- ToDo: Possibly, import and convert from Zmod ReaScale files 
}

-- textual list of the available scale's names for the GUI scale list selector
m.scalelist = {}
m.curScaleName = "Chromatic"
-- ToDo get the position of the default scale in the table for the GUI, currently hard-coded elsewhere... :\
m.preNoteProbTable = {}; m.noteProbTable = {}
--------------------------------------------------------------------------------
-- GLOBAL VARIABLES END
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS START
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- ConMsg(str) - outputs 'str' to the Reaper console
--------------------------------------------------------------------------------
local function ConMsg(str)
  reaper.ShowConsoleMsg(str .."\n")
end
--------------------------------------------------------------------------------
-- Wrap(n, max) wrap an integer 'n' to 'max'
--------------------------------------------------------------------------------
local function Wrap (n, max)
  n = n % max
  if (n < 1) then n = n + max end
  return n
end
--------------------------------------------------------------------------------
-- RGB2Packed(r, g, b) - returns a packed rgb
--------------------------------------------------------------------------------
local function RGB2Packed(r, g, b)
		g = (g << 8)
		b = (b << 16)
	return math.floor(r + g + b)
end
--------------------------------------------------------------------------------
-- Packed2RGB(p) - returns r, g, b from a packed rgb value
--------------------------------------------------------------------------------
local function Packed2RGB(p)
	local b, lsb, g, lsg, r = 0, 0, 0, 0, 0
	b = (p >> 16);	lsb = (b << 16);  p = p - lsb
	g = (p >> 8);   lsg = (g << 8);   p = p - lsg
	return math.floor(p), math.floor(g), math.floor(b)
end
--------------------------------------------------------------------------------
-- RGB2Dec(r, g, b) - returns 8 bit r, g, b as decimal values (0 to 1)
--------------------------------------------------------------------------------
local function RGB2Dec(r, g, b)
	if r < 0 or r > 255 then r = wrap(r,255) end
	if g < 0 or g > 255 then g = wrap(g,255) end
	if b < 0 or b > 255 then b = wrap(b,255) end
	return r/255, g/255, b/255
end
--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS END
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- FUNCTIONS START
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- ClearTable(t) - for 2d tables
--------------------------------------------------------------------------------
function ClearTable(t)
	for k, v in pairs(t) do
		t[k] = nil
	end
end
--------------------------------------------------------------------------------
-- GetNotesFromTake(t) - fill note buffer 't' from the active take
--------------------------------------------------------------------------------
function GetNotesFromTake(t)
	local i
	local activeEditor = reaper.MIDIEditor_GetActive()
	local activeTake = reaper.MIDIEditor_GetTake(activeEditor)
	local _retval, selected, muted, startppq, endppq, channel, pitch, velocity
	if activeTake then
		local _retval, num_notes, num_cc, num_sysex = reaper.MIDI_CountEvts(activeTake)
		if num_notes > 0 then
		ClearTable(t)
			for i = 1, num_notes do
				_retval, selected, muted, startppq, endppq, channel, pitch, velocity = reaper.MIDI_GetNote(activeTake, i-1)
				t[i] = {}
				t[i][1] = selected
				t[i][2] = muted
				t[i][3] = startppq
				t[i][4] = endppq
				t[i][5] = endppq-startppq
				t[i][6] = channel
				t[i][7] = pitch
				t[i][8] = velocity
			end -- for i				
		end -- num_notes
	else -- active take
		ConMsg("No Active Take")	
	end --if activeTake	
end
--------------------------------------------------------------------------------
-- CopyNotes(t1, t2) - copies note data from t1 to t2
--------------------------------------------------------------------------------
function CopyNotes(t1, t2)
	ClearTable(t2)
	local i = 1
	while t1[i] do
		local j = 1
		t2[i] = {}		
		while (t1[i][j] ~= nil)   do
			t2[i][j] = t1[i][j]
			j = j + 1
		end	-- while (t1[i][j]
		i = i + 1
	end -- while t1[i]
end
--------------------------------------------------------------------------------
-- DeleteNotes() - delete all notes from the active take
--------------------------------------------------------------------------------
function DeleteNotes()
	local activeEditor = reaper.MIDIEditor_GetActive()
	local activeTake = reaper.MIDIEditor_GetTake(activeEditor)
	local i = 0
	if activeTake then
		__, num_notes, __, __ = reaper.MIDI_CountEvts(activeTake)
		for i = 0, num_notes do
			reaper.MIDI_DeleteNote(activeTake, 0)
		end --for
	else
		ConMsg("Midi Mangler - No Active Take")
	end -- activeTake	
end
--------------------------------------------------------------------------------
-- SetRootNote(octave, key) - returns new root midi note
--------------------------------------------------------------------------------
function SetRootNote(octave, key)
	local o  = octave * 12
	local k = key - 1
	return o + k
end
--------------------------------------------------------------------------------
-- GenProbTable(preProbTable, slidersTable, probTable)
--------------------------------------------------------------------------------
function GenProbTable(preProbTable, sliderTable, probTable)
	local i, j, k, l = 1, 1, 1, 1
	local floor = math.floor
	ClearTable(probTable)
	for i, v in ipairs(preProbTable) do
		if sliderTable[j].norm_val > 0 then
			for l = 1, (sliderTable[j].norm_val * 10) do
				probTable[k] = preProbTable[i]
				k = k + 1
			end -- l
		end -- sliderTable[j]
		j = j + 1
	end
end
--------------------------------------------------------------------------------
-- SetScale() 
--------------------------------------------------------------------------------
function SetScale(scaleName, allScales, scale)
-- triggered by scale choice in GUI (Dropbox03)
	ClearTable(scale)
	for i = 1, #allScales, 1 do
		if scaleName == allScales[i].name then
			for k, v in pairs(allScales[i]) do
				scale[k] = v
			end
			break
		end
	end
end
--------------------------------------------------------------------------------
-- UpdateSliderLabels() - Set the note probability slider labels to match the scale
--------------------------------------------------------------------------------
function UpdateSliderLabels(sliderTable, preProbTable)
	for k, v in pairs(sliderTable) do
		if preProbTable[k] then
			sliderTable[k].label = m.notes[Wrap((preProbTable[k] + 1) + m.root, 12)]
			if sliderTable[k].norm_val == 0 then sliderTable[k].norm_val = 0.1 end
		else
			sliderTable[k].label = ""
			sliderTable[k].norm_val = 0
		end
	end
end
--------------------------------------------------------------------------------
-- GetUniqueNote()
--------------------------------------------------------------------------------
function GetUniqueNote(tNotes, noteIdx, noteProbTable)
	newNote = m.root + noteProbTable[math.random(1,#noteProbTable)]	
	if #m.dupes == 0 then
		m.dupes.i = 1;  m.dupes[m.dupes.i] = {}
		m.dupes[m.dupes.i].srtpos	= tNotes[noteIdx][3]
		m.dupes[m.dupes.i].endpos	= tNotes[noteIdx][4]
		m.dupes[m.dupes.i].midi		= newNote
		return newNote
	elseif tNotes[noteIdx][3] >= m.dupes[m.dupes.i].srtpos
	and tNotes[noteIdx][3] < m.dupes[m.dupes.i].endpos then
		m.dupes.i = m.dupes.i + 1; m.dupes[m.dupes.i] = {}
		m.dupes[m.dupes.i].srtpos = tNotes[noteIdx][3]
		m.dupes[m.dupes.i].endpos = tNotes[noteIdx][4]
		unique = false
		while not unique do		
			newNote = m.root + noteProbTable[math.random(1,#noteProbTable)]	
			unique = true
			for i = 1, m.dupes.i - 1 do
				if m.dupes[i].midi == newNote then unique = false end
			end -- m.dupes.i
		end -- not unique
		m.dupes[m.dupes.i].midi = newNote
		return newNote			
	else
		m.dupes = {}; m.dupes.i = 1;  m.dupes[m.dupes.i] = {}
		m.dupes[m.dupes.i].srtpos	= tNotes[noteIdx][3]
		m.dupes[m.dupes.i].endpos	= tNotes[noteIdx][4]
		m.dupes[m.dupes.i].midi		= newNote
		return newNote			
	end
end
--------------------------------------------------------------------------------
-- RandomiizeNotes(notebufs t1,t2, noteProbTable)
--------------------------------------------------------------------------------
function RandomiizeNotes(t1, noteProbTable)
	m.dupes.i = 1
	local  i = 1
	while t1[i] do
		if t1[i][1] == true or m.allNotesF == true then -- if selected, or all notes flag is true
			t1[i][7] = GetUniqueNote(t1, i, noteProbTable)
		end
		i = i + 1
	end -- while t1[i]
	InsertNotes(t1)
end
--------------------------------------------------------------------------------
-- InsertNotes(note_buffer) - insert notes in the active take
--------------------------------------------------------------------------------
function InsertNotes(t1)
	reaper.MIDIEditor_OnCommand(activeEditor, 40435)
	DeleteNotes()
	local i = 1
	local activeEditor = reaper.MIDIEditor_GetActive()
	local active_take = reaper.MIDIEditor_GetTake(activeEditor)
	while t1[i] do
		reaper.MIDI_InsertNote(active_take, t1[i][1], t1[i][2], t1[i][3], t1[i][4], t1[i][6], t1[i][7], t1[i][8], true)
		--1=selected, 2=muted, 3=startppq, 4=endppq, 5=len, 6=chan, 7=pitch, 8=vel, noSort)		
		i = i + 1
	end -- while t1[i]
	reaper.MIDI_Sort(active_take)
	reaper.MIDIEditor_OnCommand(activeEditor, 40435)
end	--function SetNotes
--------------------------------------------------------------------------------
-- FUNCTIONS END
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- GUI - LAYOUT START
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Create GUI Elements
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Main Window
--------------------------------------------------------------------------------
-- Frame
local frameWnd = Frame:new(10, 10, m.win_x - 20, m.win_y - 20,  0.7, 0.7, 0.7, 0.5)
-- Textbox
local txtHeader = Textbox:new(20, 20, m.win_x-40, 30, 0.5, 0.5, 0.5, 0.4, "MIDI Note Randomizer", "Arial", 18, m.h1FontCol)
--------------------------------------------------------------------------------
-- Notes Section
--------------------------------------------------------------------------------
-- Note section Frame
local frameNotes = Frame:new(10, 10, m.win_x - 20, m.win_y - 20,  0.7, 0.7, 0.7, 0.5)
-- root/MIDI note, octave, & scale droplists
dx, dy, dw, dh = 25, 90, 110, 20
local dropKey 		= Droplist:new(dx, dy,		dw, dh, 0.3, 0.5, 0.7, 0.5, "Root Note", "Arial", 15, m.stdFontCol, m.key,m.notes)
local dropOctave	= Droplist:new(dx, dy+45, dw,	dh, 0.3, 0.5, 0.7, 0.5, "Octave " ,"Arial", 15, m.stdFontCol, m.oct,{0, 1, 2, 3, 4, 5, 6, 7})
local dropScale		= Droplist:new(dx, dy+90, dw, dh, 0.3, 0.5, 0.7, 0.5, "Scale", "Arial", 15, m.stdFontCol, 1, m.scalelist)
-- Droplist table
local t_Droplists = {dropKey, dropOctave, dropScale} 
-- Buttons
local bx, by, bw, bh = 0, 300, 200, 30
local btnMangle = Button:new(25, 225, 110, 25, 0.3, 0.5, 0.3, 0.5, "Randomize", "Arial", 15, m.stdFontCol)
-- Note weight sliders
local nx, ny, nw, nh, np = 160, 70, 30, 150, 40
local noteSldr01 = Vert_Slider:new(nx,          ny, nw, nh, 0.3, 0.5, 0.7, 0.5, "", "Arial", 15, m.stdFontCol, 0.1)
local noteSldr02 = Vert_Slider:new(nx+(np*1),   ny, nw, nh, 0.3, 0.5, 0.7, 0.5, "", "Arial", 15, m.stdFontCol, 0.1)
local noteSldr03 = Vert_Slider:new(nx+(np*2),   ny, nw, nh, 0.3, 0.5, 0.7, 0.5, "", "Arial", 15, m.stdFontCol, 0.1)
local noteSldr04 = Vert_Slider:new(nx+(np*3),   ny, nw, nh, 0.3, 0.5, 0.7, 0.5, "", "Arial", 15, m.stdFontCol, 0.1)
local noteSldr05 = Vert_Slider:new(nx+(np*4),   ny, nw, nh, 0.3, 0.5, 0.7, 0.5, "", "Arial", 15, m.stdFontCol, 0.1)
local noteSldr06 = Vert_Slider:new(nx+(np*5),   ny, nw, nh, 0.3, 0.5, 0.7, 0.5, "", "Arial", 15, m.stdFontCol, 0.1)
local noteSldr07 = Vert_Slider:new(nx+(np*6),   ny, nw, nh, 0.3, 0.5, 0.7, 0.5, "", "Arial", 15, m.stdFontCol, 0.1)
local noteSldr08 = Vert_Slider:new(nx+(np*7),   ny, nw, nh, 0.3, 0.5, 0.7, 0.5, "", "Arial", 15, m.stdFontCol, 0.1)
local noteSldr09 = Vert_Slider:new(nx+(np*8),   ny, nw, nh, 0.3, 0.5, 0.7, 0.5, "", "Arial", 15, m.stdFontCol, 0.1)
local noteSldr10 = Vert_Slider:new(nx+(np*9),   ny, nw, nh, 0.3, 0.5, 0.7, 0.5, "", "Arial", 15, m.stdFontCol, 0.1)
local noteSldr11 = Vert_Slider:new(nx+(np*10),  ny, nw, nh, 0.3, 0.5, 0.7, 0.5, "", "Arial", 15, m.stdFontCol, 0.1)
local noteSldr12 = Vert_Slider:new(nx+(np*11),  ny, nw, nh, 0.3, 0.5, 0.7, 0.5, "", "Arial", 15, m.stdFontCol, 0.1)
local noteSldr13 = Vert_Slider:new(nx+(np*12),  ny, nw, nh, 0.3, 0.5, 0.7, 0.5, "", "Arial", 15, m.stdFontCol, 0.1)
-- Note weight slider table
local t_noteSliders = {noteSldr01, noteSldr02, noteSldr03, noteSldr04, noteSldr05, noteSldr06, noteSldr07,
	noteSldr08, noteSldr09, noteSldr10, noteSldr11, noteSldr12, noteSldr13}
-- Note weight slider label (Textbox)
local txtProbSliderLabel = Textbox:new(nx, 230, 510, 20, 0.5, 0.5, 0.5, 0.4, "Note Weight Sliders", "Arial",15, m.stdFontCol)

--------------------------------------------------------------------------------
-- Shared Element Tables
--------------------------------------------------------------------------------
local t_Buttons = {btnMangle}
local t_Frames = {frameWnd}
local t_Textboxes = {txtHeader, txtProbSliderLabel}
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- GUI Element Functions START
-------------------------------------------------------------------------------- 
-- Buttons
--------------------------------------------------------------------------------
-- Notes
btnMangle.onClick = function()
	GetNotesFromTake(m.notebuf.a)
	GenProbTable(m.preNoteProbTable, t_noteSliders, m.noteProbTable)
	RandomiizeNotes(m.notebuf.a, m.noteProbTable)
end 
--------------------------------------------------------------------------------
-- Droplists
--------------------------------------------------------------------------------
-- Root Key
dropKey.onClick = function() 
	m.key = dropKey.norm_val
	m.root = SetRootNote(m.oct, m.key)	
	UpdateSliderLabels(t_noteSliders, m.preNoteProbTable)
end
-- Octave
dropOctave.onClick = function() 
	m.oct = dropOctave.norm_val
	m.root = SetRootNote(m.oct, m.key)	
end
-- Scale
dropScale.onClick = function() 
	SetScale(dropScale.norm_val2[dropScale.norm_val], m.scales, m.preNoteProbTable)
	UpdateSliderLabels(t_noteSliders, m.preNoteProbTable)
end	
--------------------------------------------------------------------------------
-- GUI Element Functions END
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- GUI LAYOUT END
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- GUI - Main DRAW function
--------------------------------------------------------------------------------
function DrawGUI()
	for key, frame		in pairs(t_Frames)				do frame:draw()		end 
	for key, btn			in pairs(t_Buttons)				do btn:draw()			end
	for key, dlist		in pairs(t_Droplists)			do dlist:draw()		end 
	for key, nsldrs		in pairs(t_noteSliders)		do nsldrs:draw()	end
	for key, textb		in pairs(t_Textboxes)			do textb:draw()		end
end
--------------------------------------------------------------------------------
-- INIT
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- InitRandomizer
--------------------------------------------------------------------------------
function InitRandomizer()
	math.randomseed(os.time())
	for i = 1, 10 do math.random() end -- lua quirk, but the first random call always returns the same value...
	reaper.ClearConsole()
	m.root = SetRootNote(m.oct, m.key) -- set the root note (should match the gui..)
	for k, v in pairs(m.scales) do  --create a scale list for the gui
		m.scalelist[k] = m.scales[k]["name"]
	end
	ClearTable(m.preNoteProbTable)
	SetScale(m.curScaleName, m.scales, m.preNoteProbTable)
	UpdateSliderLabels(t_noteSliders, m.preNoteProbTable)
	GenProbTable(m.preNoteProbTable, t_noteSliders, m.noteProbTable)
	GetNotesFromTake(m.notebuf.a)	--fill note buffer
end
--------------------------------------------------------------------------------
-- InitGFX
--------------------------------------------------------------------------------
function InitGFX()
	-- Some gfx Wnd Default Values --
	local R, G, B = 0, 0, 0               -- 0..255 form
	local Win_Bgd = R + G*256 + B*65536  -- red+green*256+blue*65536  
	local Win_Title = "RobU - MIDI Note Randomizer (v1.1)"
	local Win_Dock, Wnd_X, Wnd_Y = 0, 25, 25
	Win_Width, Win_Height = m.win_x, m.win_y -- global values(used for define zoom level)
	-- Init window ------
	gfx.clear = Win_Bgd         
	gfx.init( Win_Title, Win_Width,Win_Height, Win_Dock, Wnd_X,Wnd_Y )
	-- Init mouse last --
	last_mouse_cap = 0
	last_x, last_y = 0, 0
	mouse_ox, mouse_oy = -1, -1
end
--------------------------------------------------------------------------------
-- Mainloop
--------------------------------------------------------------------------------
function mainloop()
	-- zoom level
	Z_w, Z_h = gfx.w/Win_Width, gfx.h/Win_Height
	if Z_w<0.6 then Z_w = 0.6 elseif Z_w>2 then Z_w = 2 end
	if Z_h<0.6 then Z_h = 0.6 elseif Z_h>2 then Z_h = 2 end 
	-- mouse and modkeys --
	if gfx.mouse_cap & 1 == 1   and last_mouse_cap & 1 == 0  or	-- L mouse
		gfx.mouse_cap & 2 == 2   and last_mouse_cap & 2 == 0  or	-- R mouse
		gfx.mouse_cap & 64 == 64 and last_mouse_cap & 64 == 0 then	-- M mouse
		mouse_ox, mouse_oy = gfx.mouse_x, gfx.mouse_y 
	end
	Ctrl  = gfx.mouse_cap & 4 == 4
	Shift = gfx.mouse_cap & 8 == 8
	Alt   = gfx.mouse_cap & 16 == 16 -- Shift state
	DrawGUI()
	-- update mouse
	last_mouse_cap = gfx.mouse_cap
	last_x, last_y = gfx.mouse_x, gfx.mouse_y
	gfx.mouse_wheel = 0 -- reset gfx.mouse_wheel
	-- play/stop
	char = gfx.getchar()
	if char == 32 then reaper.Main_OnCommand(40044, 0) end
	-- defer
	if char ~= -1 and char ~= 27 then reaper.defer(mainloop) end
	gfx.update()
end
--------------------------------------------------------------------------------
-- RUN
--------------------------------------------------------------------------------
InitGFX()
InitRandomizer()
mainloop()
--------------------------------------------------------------------------------