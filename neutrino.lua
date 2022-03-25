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

gfx.init(
  _scriptName,
  tonumber(reaper.GetExtState("neutrino", "wndw")) or 800,
  tonumber(reaper.GetExtState("neutrino", "wndh")) or 600,
  tonumber(reaper.GetExtState("neutrino", "dock")) or 0,
  tonumber(reaper.GetExtState("neutrino", "wndx")) or 100,
  tonumber(reaper.GetExtState("neutrino", "wndy")) or 100
)

function quit()
  local d, x, y, w, h = gfx.dock(-1, 0, 0, 0, 0)
  reaper.SetExtState("neutrino", "wndw", w, true)
  reaper.SetExtState("neutrino", "wndh", h, true)
  reaper.SetExtState("neutrino", "dock", d, true)
  reaper.SetExtState("neutrino", "wndx", x, true)
  reaper.SetExtState("neutrino", "wndy", y, true)
  gfx.quit()
end
reaper.atexit(quit)

gfx.setfont(1, "Verdana", 16)
gfx.clear = 0x111111 -- GBR order

function setCol(col) -- RGB order
  local r = col & 0xff0000 >> 16
  local g = col & 0x00ff00 >> 8
  local b = col & 0x0000ff
  gfx.set(r / 255, g / 255, b / 255, 1)
end

function setPos(x, y)
  gfx.x, gfx.y = x, y
end

Element = {objects = {}}
function Element:new(obj)
  local obj = instance(self, obj)
  Element.objects[#Element.objects + 1] = obj
  return obj
end
function Element:hitTest()
  return self.x <= gfx.mouse_x and gfx.mouse_x <= self.x + self.w and self.y <= gfx.mouse_y and
    gfx.mouse_y <= self.y + self.h
end

Label = instance(Element)
function Label:draw()
  setCol(0xffffff)
  setPos(self.x, self.y)
  gfx.drawstr(tostring(self.str), 5, self.x + self.w, self.y + self.h)
end

Button = instance(Element)
function Button:draw()
  if self.mouse_hold then
    setCol(0x999999)
  else
    setCol(0xffffff)
  end
  gfx.rect(self.x, self.y, self.w, self.h, false)
  setPos(self.x, self.y)
  gfx.drawstr(tostring(self.str), 5, self.x + self.w, self.y + self.h)
end
function Button:mouseDown()
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
function Slider:new(obj)
  obj = Element.new(self, obj)
  SliderKnob:new({parent = obj, x = obj.x, y = obj.y, w = 10, h = obj.h})
  return obj
end
function Slider:draw()
  setCol(0xffffff)
  gfx.rect(self.x, self.y, self.w, self.h, false)
end

SliderKnob = instance(Element)
function SliderKnob:draw()
  if self.mouse_hold then
    setCol(0x999999)
  else
    setCol(0xffffff)
  end
  self.x = self.parent.value * self.parent.w + self.parent.x - self.w / 2
  gfx.rect(self.x, self.y, self.w, self.h, false)
end
function SliderKnob:mouseDown()
  if self:hitTest() then
    self.mouse_hold = true
  end
end
function SliderKnob:update()
  if self.mouse_hold then
    local value = (gfx.mouse_x - self.parent.x) / self.parent.w
    self.parent.value = math.max(0, math.min(1, value))
    if self.parent.valueChenged then
      self.parent:valueChenged()
    end
  end
end
function SliderKnob:mouseUp()
  self.mouse_hold = false
end

_redraw = true
function runloop()
  local function call(event)
    for _, obj in pairs(Element.objects) do
      if obj[event] ~= nil then
        obj[event](obj)
      end
    end
  end

  local mousedown = gfx.mouse_cap & 1
  if mousedown ~= _mousedown then
    _redraw = true
    if mousedown ~= 0 then
      call("mouseDown")
    else
      call("mouseUp")
    end
  end
  _mousedown = mousedown

  if _redraw then
    -- _redraw = false
    call("update")
    call("draw")
  end

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

function runNEUTRINO(neutrinoPath, outputPath, name, modelDir)
  local neutrinoBinPath = neutrinoPath .. [[bin\NEUTRINO.exe]]
  local labelFullPath = [["]] .. outputPath .. [[score\label\full\]] .. name .. [[.lab"]]
  local labelTimingPath = [["]] .. outputPath .. [[score\label\timing\]] .. name .. [[.lab"]]
  local f0OutputPath = [["]] .. outputPath .. [[output\]] .. name .. [[.f0"]]
  local mgcOutputPath = [["]] .. outputPath .. [[output\]] .. name .. [[.mgc"]]
  local bapOutputPath = [["]] .. outputPath .. [[output\]] .. name .. [[.bap"]]
  local tempOutputPathes = f0OutputPath .. " " .. mgcOutputPath .. " " .. bapOutputPath
  local modelPath = neutrinoPath .. [[model\]] .. modelDir .. [[\]]
  local neutrinoBinOption = [[-n 3 -k 0 -m -t]]
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

  local ret, err = runNEUTRINO(neutrinoPath, outputPath, name, modelDir)
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
    pitchShift = "1.00",
    formantShift = "1.00"
  }
)

NeutrinoAvailableLabel = Label:new({x = 10, y = 40, w = 40, h = 20, str = tostring(checkNeutrinoAvailable())})
SelectNeutrinoPathButton =
  Button:new(
  {
    x = 10,
    y = 10,
    w = 300,
    h = 20,
    str = extState:get("neutrinoPath"),
    click = function(self)
      local retval, folder = reaper.JS_Dialog_BrowseForFolder("test", "")
      if retval == 1 then
        local neutrinoPath = folder .. "\\"
        extState:set("neutrinoPath", neutrinoPath)
        self.str = neutrinoPath
      end
      NeutrinoAvailableLabel.str = tostring(checkNeutrinoAvailable())
    end
  }
)
SelectModelButton =
  Button:new(
  {
    x = 10,
    y = 70,
    w = 100,
    h = 20,
    str = extState:get("modelDir"),
    click = function(self)
      local list = listModels()
      local t = gfx.showmenu(table.concat(list, "|"))
      if t ~= 0 then
        local modelDir = tostring(list[t])
        extState:set("modelDir", modelDir)
        self.str = modelDir
      end
    end
  }
)
StartSynthesisButton =
  Button:new(
  {
    x = 10,
    y = 100,
    w = 150,
    h = 20,
    update = function(self)
      local items_count = reaper.CountSelectedMediaItems(0)
      self.str = string.format("合成 (%dアイテム選択中)", items_count)
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
PitchShiftSlider =
  Slider:new(
  {
    x = 10,
    y = 140,
    w = 300,
    h = 20,
    value = tonumber(extState:get("pitchShift")) / 2,
    valueChenged = function(self)
      local pitchShift = string.format("%1.2f", self.value * 2)
      extState:set("pitchShift", pitchShift)
      PitchShiftLabel.str = pitchShift
    end
  }
)
PitchShiftLabel =
  Label:new(
  {
    x = 10,
    y = 160,
    w = 40,
    h = 20,
    str = extState:get("pitchShift")
  }
)
FormantShiftSlider =
  Slider:new(
  {
    x = 10,
    y = 200,
    w = 300,
    h = 20,
    value = tonumber(extState:get("formantShift")) / 2,
    valueChenged = function(self)
      local formantShift = string.format("%1.2f", self.value * 2)
      extState:set("formantShift", formantShift)
      FormantShiftLabel.str = formantShift
    end
  }
)
FormantShiftLabel =
  Label:new(
  {
    x = 10,
    y = 220,
    w = 40,
    h = 20,
    str = extState:get("formantShift")
  }
)

runloop()
