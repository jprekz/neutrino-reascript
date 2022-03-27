_scriptName = "NEUTRINO ReaScript"
_version = "0.0.1"
_author = "rekz"

----- common

_debug = true

if _debug then
  reaper.ClearConsole()
end

function print(...)
  if not _debug then
    return
  end
  local t = {...}
  for k, v in pairs(t) do
    t[k] = tostring(v)
  end
  reaper.ShowConsoleMsg(table.concat(t, "\t") .. "\n")
end

function instance(proto, obj)
  local obj = obj or {}
  setmetatable(obj, {__index = proto})
  return obj
end

----- GUI common

function setColor(c, a) -- RGB order
  local r = (c & 0xff0000) >> 16
  local g = (c & 0x00ff00) >> 8
  local b = c & 0x0000ff
  gfx.set(r / 255, g / 255, b / 255, a or 1)
end

function setPos(x, y)
  gfx.x, gfx.y = x, y
end

_objects = {}
Element = {}
function Element:spawn(obj)
  local obj = instance(self, obj)
  _objects[#_objects + 1] = obj
  return obj
end
function Element:hitTest()
  return self.x <= gfx.mouse_x and gfx.mouse_x <= self.x + self.w and self.y <= gfx.mouse_y and
    gfx.mouse_y <= self.y + self.h
end

Label = instance(Element)
function Label:draw()
  if self.hidden then
    return
  end
  if self.color then
    setColor(self.color)
    gfx.rect(self.x, self.y, self.w, self.h)
  end
  if self.text then
    setColor(self.color_text or 0xcccccc)
    setPos(self.x, self.y)
    gfx.setfont(1)
    gfx.drawstr(tostring(self.text), self.flag or 5, self.x + self.w, self.y + self.h)
  end
end

Button = instance(Element)
function Button:draw()
  if self.hidden then
    return
  end
  if self.mouse_hold then
    setColor(self.color_active or 0x151515)
  elseif self:hitTest() then
    setColor(self.color_hover or 0x3e3e3e)
  else
    setColor(self.color or 0x333333)
  end
  gfx.rect(self.x, self.y, self.w, self.h)
  if self.text then
    setColor(self.color_text or 0xeeeeee)
    setPos(self.x, self.y)
    gfx.setfont(2)
    gfx.drawstr(tostring(self.text), self.flag or 5, self.x + self.w, self.y + self.h)
  end
end
function Button:mouseDown()
  if self.hidden then
    return
  end
  if self:hitTest() then
    self.mouse_hold = true
  end
end
function Button:mouseUp()
  if self:hitTest() and self.mouse_hold and self.click then
    setPos(self.x, self.y + self.h)
    self:click()
  end
  self.mouse_hold = false
end

Slider = instance(Element)
function Slider:spawn(obj)
  obj = Element.spawn(self, obj)
  SliderKnob:spawn({parent = obj, x = obj.x, y = obj.y, w = 10, h = obj.h})
  return obj
end
function Slider:changeValue(value)
  self.value = value
  if self.valueChanged then
    self:valueChanged()
  end
end
function Slider:draw()
  if self.hidden then
    return
  end
  setColor(self.color or 0x333333)
  gfx.rect(self.x, self.y + (self.h - 6) / 2, self.w, 6)
  if self.default_value then
    setColor(0x222222)
    gfx.rect(self.default_value * self.w + self.x, self.y + (self.h - 6) / 2, 1, 6)
  end
end
function Slider:mouseDown()
  if self.hidden then
    return
  end
  if self:hitTest() then
    if self._mouse_x == gfx.mouse_x and self._mouse_y == gfx.mouse_y then
      self:changeValue(self.default_value or 0.5)
      return
    end
    self.mouse_hold = true
  end
end
function Slider:update()
  if self.hidden then
    return
  end
  if self.mouse_hold then
    local value = (gfx.mouse_x - self.x) / self.w
    self:changeValue(math.max(0, math.min(1, value)))
  elseif self:hitTest() then
    if gfx.mouse_wheel > 0 then
      self:changeValue(math.min(1, self.value + (self.unit_value or 0.01)))
    elseif gfx.mouse_wheel < 0 then
      self:changeValue(math.max(0, self.value - (self.unit_value or 0.01)))
    end
    gfx.mouse_wheel = 0
  end
end
function Slider:mouseUp()
  self.mouse_hold = false
  if self:hitTest() then
    self._mouse_x = gfx.mouse_x
    self._mouse_y = gfx.mouse_y
  else
    self._mouse_x = nil
    self._mouse_y = nil
  end
end

SliderKnob = instance(Element)
function SliderKnob:draw()
  if self.parent.hidden then
    return
  end
  if self.parent.mouse_hold then
    setColor(self.color_active or 0x999999)
  elseif self:hitTest() then
    setColor(self.color_hover or 0xffffff)
  else
    setColor(self.color or 0xcccccc)
  end
  self.x = self.parent.value * self.parent.w + self.parent.x - self.w / 2
  gfx.rect(self.x, self.y, self.w, self.h)
end

gfx.clear = 0x1e1e1e -- GBR order
gfx.setfont(1, "Verdana", 13)
gfx.setfont(2, "Verdana", 16)
gfx.init(
  _scriptName,
  380,
  340,
  tonumber(reaper.GetExtState("neutrino", "dock")) or 0,
  tonumber(reaper.GetExtState("neutrino", "wndx")) or 100,
  tonumber(reaper.GetExtState("neutrino", "wndy")) or 100
)

function quit()
  local d, x, y, w, h = gfx.dock(-1, 0, 0, 0, 0)
  reaper.SetExtState("neutrino", "dock", d, true)
  reaper.SetExtState("neutrino", "wndx", x, true)
  reaper.SetExtState("neutrino", "wndy", y, true)
  gfx.quit()
end
reaper.atexit(quit)

function runloop()
  local function call(event)
    for _, obj in pairs(_objects) do
      if obj[event] ~= nil then
        obj[event](obj)
      end
    end
  end

  local mousedown = gfx.mouse_cap & 1
  if mousedown ~= _mousedown then
    if mousedown ~= 0 then
      call("mouseDown")
    else
      call("mouseUp")
    end
  end
  _mousedown = mousedown

  call("update")
  gfx.setfont(1)
  call("draw")

  gfx.update()
  local c = gfx.getchar()
  if c == 27 then -- esc
    gfx.quit()
  elseif c >= 0 then
    reaper.runloop(runloop)
  end -- c == -1 if the graphics window is not open
end

----- MusicXml

MusicXmlBuilder = {}
function MusicXmlBuilder.new()
  local obj = instance(MusicXmlBuilder)
  obj.divisions = 1
  obj.xml =
    [[<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE score-partwise PUBLIC
    "-//Recordare//DTD MusicXML 4.0 Partwise//EN"
    "http://www.musicxml.org/dtds/partwise.dtd">
<score-partwise version="4.0">
  <part-list> <score-part id="P1"> <part-name>Music</part-name> </score-part> </part-list>
  <part id="P1">
    <measure number="1">
      ]]
  return obj
end
function MusicXmlBuilder:putAttributes(divisions, key, beats, beatType)
  print("Attributes", divisions, key, beats, beatType)
  self.divisions = divisions
  self.xml =
    self.xml ..
    string.format(
      [[<attributes>
        <divisions>%d</divisions>
        <key> <fifths>%d</fifths> </key>
        <time> <beats>%d</beats> <beat-type>%d</beat-type> </time>
        <clef> <sign>G</sign> <line>2</line> </clef>
      </attributes>
      ]],
      divisions,
      key,
      beats,
      beatType
    )
end
function MusicXmlBuilder:putDirection(tempo)
  print("Direction", tempo)
  self.xml =
    self.xml ..
    string.format(
      [[<direction>
        <direction-type>
          <metronome>
            <beat-unit>quarter</beat-unit>
            <per-minute>%d</per-minute>
          </metronome>
        </direction-type>
        <sound tempo="%d"/>
      </direction>
      ]],
      tempo,
      tempo
    )
end
function MusicXmlBuilder:putNote(duration, pitch, lyric, tie)
  local stepTable = {"C", "C", "D", "D", "E", "F", "F", "G", "G", "A", "A", "B"}
  local alterTable = {0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0}
  local step = stepTable[(pitch - 12) % 12 + 1]
  local alter = alterTable[(pitch - 12) % 12 + 1]
  local octave = math.floor((pitch - 12) / 12)
  local alterXml = ""
  local alterText = ""
  if alter == 1 then
    alterXml = "<alter>1</alter>"
    alterText = "#"
  end
  local tieXml = ""
  if tie == "start" then
    tieXml = [[<tie type="start"/>]]
  elseif tie == "stop" then
    tieXml = [[<tie type="stop"/>]]
  elseif tie == "stop_start" then
    tieXml = [[<tie type="stop"/><tie type="start"/>]]
  end
  local pitchText = step .. alterText .. octave
  print(duration, pitchText, lyric, tie)
  self.xml =
    self.xml ..
    string.format(
      [[<note>
        <pitch><step>%s</step>%s<octave>%d</octave></pitch>
        <duration>%d</duration>%s
        <lyric> <syllabic>single</syllabic> <text>%s</text> </lyric>
      </note>
      ]],
      step,
      alterXml,
      octave,
      duration,
      tieXml,
      lyric
    )
end
function MusicXmlBuilder:putRestNote(duration)
  print(duration, "", "pau")
  self.xml =
    self.xml .. string.format([[<note>
        <rest/>
        <duration>%d</duration>
      </note>
      ]], duration)
end
function MusicXmlBuilder:putMeasure(measure)
  print("measure", measure)
  self.xml = self.xml .. string.format([[</measure>
    <measure number="%d">
      ]], measure)
end
function MusicXmlBuilder:build()
  return self.xml .. [[</measure>
  </part>
</score-partwise>
]]
end

function buildMusicXml(item)
  local take = reaper.GetActiveTake(item)

  local evtcnt, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)

  -- get lyric
  local lyric = {}
  for tc = 0, textsyxevtcnt - 1 do
    local ret, _, _, ppqpos, type, msg = reaper.MIDI_GetTextSysexEvt(take, tc)
    if type == 5 then -- lyric
      lyric[ppqpos] = msg
    end
  end

  local builder = MusicXmlBuilder.new()

  local item_st = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local timesig_num, timesig_denom, tempo = reaper.TimeMap_GetTimeSigAtTime(0, item_st)
  local divisions = 960
  local measureTicks = divisions * timesig_num
  builder:putAttributes(divisions, 0, timesig_num, timesig_denom)
  builder:putDirection(tempo)

  -- iter notes and build music xml
  local measure = 1
  local last_ed = 0
  for nc = 0, notecnt - 1 do
    local _, _, _, st_ppq, ed_ppq, _, pitch, _ = reaper.MIDI_GetNote(take, nc)
    local st, ed = math.floor(st_ppq + 0.5), math.floor(ed_ppq + 0.5)

    if st > last_ed then
      -- put rest note
      local st, ed = last_ed, st
      local dur = ed - st
      ::rest_note_continue::
      local next_measure = measure * measureTicks
      if ed < next_measure then
        builder:putRestNote(dur)
      elseif ed == next_measure then
        builder:putRestNote(dur)
        measure = measure + 1
        builder:putMeasure(measure)
      elseif ed > next_measure then
        dur = next_measure - st
        builder:putRestNote(dur)
        measure = measure + 1
        builder:putMeasure(measure)
        st = next_measure
        dur = ed - st
        goto rest_note_continue
      end
    end

    -- put note
    local dur = ed - st
    local tie = nil
    ::note_continue::
    local next_measure = measure * measureTicks
    if ed < next_measure then
      builder:putNote(dur, pitch, lyric[st_ppq], tie)
    elseif ed == next_measure then
      builder:putNote(dur, pitch, lyric[st_ppq], tie)
      measure = measure + 1
      builder:putMeasure(measure)
    elseif ed > next_measure then
      dur = next_measure - st
      if tie == "stop" then
        tie = "stop_start"
      else
        tie = "start"
      end
      builder:putNote(dur, pitch, lyric[st_ppq], tie)
      measure = measure + 1
      builder:putMeasure(measure)
      st = next_measure
      dur = ed - st
      tie = "stop"
      goto note_continue
    end

    last_ed = ed
  end

  local next_measure = measure * measureTicks
  local st, ed = last_ed, next_measure
  local dur = ed - st
  builder:putRestNote(dur)

  return builder:build()
end

----- NEUTRINO

function createOutputDirectories(outputPath)
  reaper.RecursiveCreateDirectory(outputPath .. [[score\musicxml]], 0)
  reaper.RecursiveCreateDirectory(outputPath .. [[score\label\full]], 0)
  reaper.RecursiveCreateDirectory(outputPath .. [[score\label\mono]], 0)
  reaper.RecursiveCreateDirectory(outputPath .. [[score\label\timing]], 0)
  reaper.RecursiveCreateDirectory(outputPath .. [[output]], 0)
end

function writeMusicXml(outputPath, name, musicxml)
  local musicxmlPath = outputPath .. [[score\musicxml\]] .. name .. [[.musicxml]]
  print("musicxml path: " .. musicxmlPath)
  local file = io.open(musicxmlPath, "w")
  file:write(musicxml)
  file:close()
end

function runMusicXMLtoLabel(neutrinoPath, outputPath, name)
  local musicxmlPath = [["]] .. outputPath .. [[score\musicxml\]] .. name .. [[.musicxml"]]
  local musicXMLtoLabelPath = neutrinoPath .. [[bin\musicXMLtoLabel.exe]]
  local labelFullPath = [["]] .. outputPath .. [[score\label\full\]] .. name .. [[.lab"]]
  local labelMonoPath = [["]] .. outputPath .. [[score\label\mono\]] .. name .. [[.lab"]]
  local musicXMLtoLabelOption = [[-x ]] .. neutrinoPath .. [[settings\dic]]
  local command =
    musicXMLtoLabelPath ..
    " " .. musicxmlPath .. " " .. labelFullPath .. " " .. labelMonoPath .. " " .. musicXMLtoLabelOption
  print("> " .. command)
  local ret = reaper.ExecProcess(command, 0)
  if ret == nil then
    return nil, "Failed to execute musicXMLtoLabel"
  end
  print(ret)
  return 1
end

function runNEUTRINO(neutrinoPath, outputPath, name, modelDir, styleShift)
  local neutrinoBinPath = neutrinoPath .. [[bin\NEUTRINO.exe]]
  local labelFullPath = [["]] .. outputPath .. [[score\label\full\]] .. name .. [[.lab"]]
  local labelTimingPath = [["]] .. outputPath .. [[score\label\timing\]] .. name .. [[.lab"]]
  local f0OutputPath = [["]] .. outputPath .. [[output\]] .. name .. [[.f0"]]
  local mgcOutputPath = [["]] .. outputPath .. [[output\]] .. name .. [[.mgc"]]
  local bapOutputPath = [["]] .. outputPath .. [[output\]] .. name .. [[.bap"]]
  local tempOutputPathes = f0OutputPath .. " " .. mgcOutputPath .. " " .. bapOutputPath
  local modelPath = neutrinoPath .. [[model\]] .. modelDir .. [[\]]
  local neutrinoBinOption = string.format([[-n 3 -k %d -m -t]], styleShift)
  local command =
    neutrinoBinPath ..
    " " ..
      labelFullPath .. " " .. labelTimingPath .. " " .. tempOutputPathes .. " " .. modelPath .. " " .. neutrinoBinOption
  print("> " .. command)
  local ret = reaper.ExecProcess(command, 0)
  if ret == nil then
    return nil, "Failed to execute NEUTRINO"
  end
  print(ret)
  if ret:sub(1, 2) == "-1" then
    return nil, "An error occurred while running NEUTRINO"
  end
  return 1
end

function runWORLD(neutrinoPath, outputPath, name, pitchShift, formantShift)
  local worldPath = neutrinoPath .. [[bin\WORLD.exe]]
  local f0OutputPath = [["]] .. outputPath .. [[output\]] .. name .. [[.f0"]]
  local mgcOutputPath = [["]] .. outputPath .. [[output\]] .. name .. [[.mgc"]]
  local bapOutputPath = [["]] .. outputPath .. [[output\]] .. name .. [[.bap"]]
  local tempOutputPathes = f0OutputPath .. " " .. mgcOutputPath .. " " .. bapOutputPath
  local outputFilePath = outputPath .. [[output\]] .. name .. [[_syn.wav]]
  local worldOption = string.format([[-f %.2f -m %.2f -o "%s" -n 3 -t]], pitchShift, formantShift, outputFilePath)
  local command = worldPath .. " " .. tempOutputPathes .. " " .. worldOption
  print("> " .. command)
  local ret = reaper.ExecProcess(command, 0)
  if ret == nil then
    return nil, "Failed to execute WORLD"
  end
  print(ret)
  return outputFilePath
end

function getFileName(item)
  local take = reaper.GetActiveTake(item)
  local ret, name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
  if name == "" then
    name = "untitled"
  end
  print("file name: " .. name)
  return name
end

function synthesis(item, neutrinoPath, modelDir, outputPath)
  local musicxml, err = buildMusicXml(item)
  if musicxml == nil then
    return nil, err
  end

  local name = getFileName(item)
  createOutputDirectories(outputPath)
  writeMusicXml(outputPath, name, musicxml)

  local ret, err = runMusicXMLtoLabel(neutrinoPath, outputPath, name)
  if ret == nil then
    return nil, err
  end

  local styleShift = extState:get("styleShift")
  local ret, err = runNEUTRINO(neutrinoPath, outputPath, name, modelDir, styleShift)
  if ret == nil then
    return nil, err
  end

  local pitchShift = extState:get("pitchShift")
  local formantShift = extState:get("formantShift")
  local ret, err = runWORLD(neutrinoPath, outputPath, name, pitchShift, formantShift)
  if ret == nil then
    return nil, err
  end
  outputFilePath = ret

  return outputFilePath
end

function synthesisAll(neutrinoPath, modelDir, outputPath)
  local items_count = reaper.CountSelectedMediaItems(0)
  for i = 0, items_count - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local outputFilePath, err = synthesis(item, neutrinoPath, modelDir, outputPath)
    if outputFilePath == nil then
      return nil, err
    end
    print("output file path: " .. outputFilePath)

    local new_take = reaper.AddTakeToMediaItem(item)
    local pcm_source = reaper.PCM_Source_CreateFromFile(outputFilePath)
    reaper.PCM_Source_BuildPeaks(pcm_source, 0)
    reaper.SetMediaItemTake_Source(new_take, pcm_source)
    reaper.SetActiveTake(new_take)
  end

  return 1
end

function checkNeutrinoAvailable()
  local neutrinoPath = extState:get("neutrinoPath")
  local musicXMLtoLabelPath = neutrinoPath .. [[bin\musicXMLtoLabel.exe]]
  local neutrinoBinPath = neutrinoPath .. [[bin\NEUTRINO.exe]]
  local worldPath = neutrinoPath .. [[bin\WORLD.exe]]
  return reaper.file_exists(musicXMLtoLabelPath) and reaper.file_exists(neutrinoBinPath) and
    reaper.file_exists(worldPath)
end

function listModels()
  local neutrinoPath = extState:get("neutrinoPath")
  local list = {}
  for i = 0, math.huge do
    local s = reaper.EnumerateSubdirectories(neutrinoPath .. [[model\]], i)
    if s then
      list[i + 1] = s
    else
      break
    end
  end
  return list
end

----- main

GetSetHook = {}
function GetSetHook:new(init_dict)
  local obj = instance(GetSetHook)
  for key, default_value in pairs(init_dict) do
    local get = reaper.GetExtState("neutrino", key)
    if get ~= "" then
      obj[key] = get
    else
      obj[key] = default_value
      reaper.SetExtState("neutrino", key, default_value, true)
    end
  end
  return obj
end
function GetSetHook:get(key)
  return self[key]
end
function GetSetHook:set(key, value)
  if not self[key] then
    error("Attempted to set a value to an uninitialized key")
  end
  self[key] = value
  reaper.SetExtState("neutrino", key, value, true)
end

extState =
  GetSetHook:new(
  {
    neutrinoPath = [[C:\path\to\NEUTRINO\]],
    modelDir = "MERROW",
    styleShift = "0",
    selectedVocoder = "WORLD",
    pitchShift = "1.00",
    formantShift = "1.00"
  }
)

modelLabel = Label:spawn({x = 20, y = 15, w = 140, h = 20, text = "Model", flag = 4})
selectModelButton =
  Button:spawn(
  {
    x = 20,
    y = 35,
    w = 140,
    h = 30,
    color = 0x193028,
    color_hover = 0x2e4a40,
    text = extState:get("modelDir"),
    click = function(self)
      local list = listModels()
      local t = gfx.showmenu(table.concat(list, "|"))
      if t ~= 0 then
        local modelDir = tostring(list[t])
        extState:set("modelDir", modelDir)
        self.text = modelDir
      end
    end
  }
)
selectModelMark = Label:spawn({x = 130, y = 35, w = 30, h = 30, text = "⏷"})

startSynthesisButton =
  Button:spawn(
  {
    x = 180,
    y = 25,
    w = 180,
    h = 40,
    color = 0x094e36,
    color_hover = 0x0d724f,
    update = function(self)
      local items_count = reaper.CountSelectedMediaItems(0)
      self.text = string.format("START(%d items selected)", items_count)
    end,
    click = function(self)
      reaper.Undo_BeginBlock()
      local outputPath = reaper.GetProjectPath("") .. [[\NEUTRINO\]]
      ret, err = synthesisAll(extState:get("neutrinoPath"), extState:get("modelDir"), outputPath)
      if ret == nil then
        reaper.ShowMessageBox(tostring(err), "Error: " .. _scriptName, 0)
      end
      print("Synthesis done")
      reaper.Undo_EndBlock("Run NEUTRINO Synthesis", -1)
      reaper.UpdateArrange()
    end
  }
)

styleShiftLabel = Label:spawn({x = 30, y = 75, w = 90, h = 20, text = "StyleShift", flag = 4})
styleShiftSlider =
  Slider:spawn(
  {
    x = 120,
    y = 75,
    w = 200,
    h = 20,
    value = (tonumber(extState:get("styleShift")) + 6) / 12,
    default_value = 0.5,
    unit_value = 1.0 / 12,
    valueChanged = function(self)
      local styleShift = string.format("%1.0f", math.floor(self.value * 12 + 0.5) - 6)
      extState:set("styleShift", styleShift)
      styleShiftValueLabel.text = styleShift
    end
  }
)
styleShiftValueLabel = Label:spawn({x = 320, y = 75, w = 40, h = 20, text = extState:get("styleShift")})

vocoderLabel = Label:spawn({x = 20, y = 100, w = 90, h = 20, text = "Vocoder", flag = 4})
worldButton =
  Button:spawn(
  {
    x = 20,
    y = 120,
    w = 140,
    h = 30,
    color_hover = 0x2e4a40,
    text = "WORLD",
    click = function(self)
      extState:set("selectedVocoder", "WORLD")
      tabUpdate()
    end
  }
)
worldButtonMark = Label:spawn({x = 130, y = 120, w = 30, h = 30, text = "✓"})
nsfButton =
  Button:spawn(
  {
    x = 160,
    y = 120,
    w = 140,
    h = 30,
    color_hover = 0x2e4a40,
    text = "NSF",
    click = function(self)
      extState:set("selectedVocoder", "NSF")
      tabUpdate()
    end
  }
)
nsfButtonMark = Label:spawn({x = 270, y = 120, w = 30, h = 30, text = "✓"})
tabPageBackground = Label:spawn({x = 20, y = 150, w = 340, h = 70, color = 0x193028})

worldTabPage = {}
worldTabPage.pitchShiftLabel = Label:spawn({x = 30, y = 160, w = 90, h = 20, text = "PitchShift", flag = 4})
worldTabPage.pitchShiftSlider =
  Slider:spawn(
  {
    x = 120,
    y = 160,
    w = 200,
    h = 20,
    color = 0x424D49,
    value = tonumber(extState:get("pitchShift")) / 2,
    default_value = 0.5,
    valueChanged = function(self)
      local pitchShift = string.format("%1.2f", self.value * 2)
      extState:set("pitchShift", pitchShift)
      worldTabPage.pitchShiftValueLabel.text = pitchShift
    end
  }
)
worldTabPage.pitchShiftValueLabel = Label:spawn({x = 320, y = 160, w = 40, h = 20, text = extState:get("pitchShift")})
worldTabPage.formantShiftLabel = Label:spawn({x = 30, y = 190, w = 90, h = 20, text = "FormantShift", flag = 4})
worldTabPage.formantShiftSlider =
  Slider:spawn(
  {
    x = 120,
    y = 190,
    w = 200,
    h = 20,
    color = 0x424D49,
    value = tonumber(extState:get("formantShift")) / 2,
    default_value = 0.5,
    valueChanged = function(self)
      local formantShift = string.format("%1.2f", self.value * 2)
      extState:set("formantShift", formantShift)
      worldTabPage.formantShiftValueLabel.text = formantShift
    end
  }
)
worldTabPage.formantShiftValueLabel =
  Label:spawn({x = 320, y = 190, w = 40, h = 20, text = extState:get("formantShift")})

nsfTabPage = {}
nsfTabPage.noSettingsLabel = Label:spawn({x = 30, y = 160, w = 90, h = 20, text = "No settings", flag = 4})

function tabUpdate()
  if extState:get("selectedVocoder") == "WORLD" then
    worldButton.color = 0x193028
    worldButtonMark.hidden = false
    nsfButton.color = 0x151515
    nsfButtonMark.hidden = true
    for _, v in pairs(worldTabPage) do
      v.hidden = false
    end
    for _, v in pairs(nsfTabPage) do
      v.hidden = true
    end
  elseif extState:get("selectedVocoder") == "NSF" then
    worldButton.color = 0x151515
    worldButtonMark.hidden = true
    nsfButton.color = 0x193028
    nsfButtonMark.hidden = false
    for _, v in pairs(worldTabPage) do
      v.hidden = true
    end
    for _, v in pairs(nsfTabPage) do
      v.hidden = false
    end
  end
end
tabUpdate()

settingsLabel = Label:spawn({x = 20, y = 230, w = 140, h = 20, text = "Settings", flag = 4})
settingsBackground = Label:spawn({x = 20, y = 250, w = 340, h = 65, color = 0x151515})
neutrinoPathLabel = Label:spawn({x = 30, y = 260, w = 320, h = 20, text = "NEUTRINO directory:", flag = 4})
neutrinoAvailableLabel = Label:spawn({x = 150, y = 260, w = 20, h = 20, color_text = 0x00aa00, text = "✓"})
function updateNeutrinoAvailableLabel()
  if checkNeutrinoAvailable() then
    neutrinoAvailableLabel.color_text = 0x00aa00
    neutrinoAvailableLabel.text = "✓"
  else
    neutrinoAvailableLabel.color_text = 0xff0000
    neutrinoAvailableLabel.text = "×"
  end
end
updateNeutrinoAvailableLabel()
neutrinoPathButton =
  Button:spawn(
  {
    x = 30,
    y = 280,
    w = 320,
    h = 20,
    color = 0x111111,
    color_text = 0xcccccc,
    text = extState:get("neutrinoPath"),
    flag = 4,
    click = function(self)
      local retval, folder = reaper.JS_Dialog_BrowseForFolder("Select NEUTRINO directory", "")
      if retval == 1 then
        local neutrinoPath = folder .. "\\"
        extState:set("neutrinoPath", neutrinoPath)
        self.text = neutrinoPath
        updateNeutrinoAvailableLabel()
      end
    end
  }
)

runloop()
