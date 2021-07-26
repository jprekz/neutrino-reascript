debug = true

if debug then
  reaper.ClearConsole()
end

function print(...)
  if not debug then
    return
  end
  local t = {...}
  for k, v in pairs(t) do
    t[k] = tostring(v)
  end
  reaper.ShowConsoleMsg(table.concat(t, "\t") .. "\n")
end

function instance(proto)
  local obj = {}
  setmetatable(obj, {__index = proto})
  return obj
end

----- MusicXmlBuilder

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

-----

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

function createOutputDirectories(outputPath)
  reaper.RecursiveCreateDirectory(outputPath .. [[score\musicxml]], 0)
  reaper.RecursiveCreateDirectory(outputPath .. [[score\label\full]], 0)
  reaper.RecursiveCreateDirectory(outputPath .. [[score\label\mono]], 0)
  reaper.RecursiveCreateDirectory(outputPath .. [[score\label\timing]], 0)
  reaper.RecursiveCreateDirectory(outputPath .. [[output]], 0)
end

function writeMusicXml(outputPath, name, musicxml)
  local musicxmlPath = outputPath .. [[score\musicxml\]] .. name .. [[.musicxml]]
  print(musicxmlPath)
  local file = io.open(musicxmlPath, "w")
  file:write(musicxml)
  file:close()
end

function runNEUTRINO(neutrinoPath, outputPath, name)
  local musicxmlPath = [["]] .. outputPath .. [[score\musicxml\]] .. name .. [[.musicxml"]]
  local musicXMLtoLabelPath = neutrinoPath .. [[bin\musicXMLtoLabel.exe]]
  local labelFullPath = [["]] .. outputPath .. [[score\label\full\]] .. name .. [[.lab"]]
  local labelMonoPath = [["]] .. outputPath .. [[score\label\mono\]] .. name .. [[.lab"]]
  local musicXMLtoLabelOption = [[-x ]] .. neutrinoPath .. [[settings\dic]]

  local command =
    musicXMLtoLabelPath ..
    " " .. musicxmlPath .. " " .. labelFullPath .. " " .. labelMonoPath .. " " .. musicXMLtoLabelOption
  print(command)
  if reaper.ExecProcess(command, 0) == nil then
    return nil, "Failed to execute musicXMLtoLabel"
  end

  local neutrinoBinPath = neutrinoPath .. [[bin\NEUTRINO.exe]]
  local labelTimingPath = [["]] .. outputPath .. [[score\label\timing\]] .. name .. [[.lab"]]
  local f0OutputPath = [["]] .. outputPath .. [[output\]] .. name .. [[.f0"]]
  local mgcOutputPath = [["]] .. outputPath .. [[output\]] .. name .. [[.mgc"]]
  local bapOutputPath = [["]] .. outputPath .. [[output\]] .. name .. [[.bap"]]
  local tempOutputPathes = f0OutputPath .. " " .. mgcOutputPath .. " " .. bapOutputPath
  local modelPath = neutrinoPath .. [[model\KIRITAN\]]
  local neutrinoBinOption = [[-n 3 -k 0 -m -t]]

  local command =
    neutrinoBinPath ..
    " " ..
      labelFullPath .. " " .. labelTimingPath .. " " .. tempOutputPathes .. " " .. modelPath .. " " .. neutrinoBinOption
  print(command)
  if reaper.ExecProcess(command, 0) == nil then
    return nil, "Failed to execute NEUTRINO"
  end

  local worldPath = neutrinoPath .. [[bin\WORLD.exe]]
  local outputFilePath = outputPath .. [[output\]] .. name .. [[_syn.wav]]
  local worldOption = [[-f 1.0 -m 1.0 -o "]] .. outputFilePath .. [[" -n 3 -t]]

  local command = worldPath .. " " .. tempOutputPathes .. " " .. worldOption
  print(command)
  if reaper.ExecProcess(command, 0) == nil then
    return nil, "Failed to execute WORLD"
  end

  return outputFilePath
end

function getFileName(item)
  local take = reaper.GetActiveTake(item)
  local ret, name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
  if name == "" then
    name = "untitled"
  end
  print("ファイル名:", name)
  return name
end

function main()
  local neutrinoPath = reaper.GetExtState("neutrino", "neutrinoPath")
  local outputPath = reaper.GetProjectPath("") .. [[\NEUTRINO\]]
  print(outputPath)

  local item = reaper.GetSelectedMediaItem(0, 0)
  if item == nil then
    return nil, "No media item selected"
  end

  local musicxml, err = buildMusicXml(item)
  if musicxml == nil then
    return nil, err
  end

  local name = getFileName(item)
  createOutputDirectories(outputPath)
  writeMusicXml(outputPath, name, musicxml)

  local outputFilePath, err = runNEUTRINO(neutrinoPath, outputPath, name)
  if outputFilePath == nil then
    return nil, err
  end
  print(outputFilePath)

  local ret = reaper.InsertMedia(outputFilePath, 1)
  if ret == nil then
    return nil, "Failed to load " .. outputFilePath
  end

  return 1
end

ret, err = main()
if ret == nil then
  reaper.ShowMessageBox(tostring(err), "Error: neutrino.lua", 0)
end
