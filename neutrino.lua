debug = true

if debug then
  reaper.ShowConsoleMsg("")
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

function error(s)
  reaper.ShowMessageBox(s, "Error: neutrino.lua", 0)
end

MusicXmlBuilder = {
  divisions = 1,
  measure = 1,
  xml = [[<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE score-partwise PUBLIC
    "-//Recordare//DTD MusicXML 4.0 Partwise//EN"
    "http://www.musicxml.org/dtds/partwise.dtd">
<score-partwise version="4.0">
  <part-list> <score-part id="P1"> <part-name>Music</part-name> </score-part> </part-list>
  <part id="P1">
    <measure number="1">
]],
  putAttributes = function(self, divisions, key, beats, beatType)
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
  end,
  putDirection = function(self, tempo)
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
  end,
  putNote = function(self, duration, pitch, lyric)
    local stepTable = {"C", "C", "D", "D", "E", "F", "F", "G", "G", "A", "A", "B"}
    local alterTable = {0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0}
    local step = stepTable[(pitch - 12) % 12 + 1]
    local alter = alterTable[(pitch - 12) % 12 + 1]
    local octave = math.floor((pitch - 12) / 12)
    local alterXml = ""
    if alter == 1 then
      alterXml = "<alter>1</alter>"
    end
    duration = math.floor(duration * self.divisions + 0.5)
    self.xml =
      self.xml ..
      string.format(
        [[
      <note>
        <pitch><step>%s</step>%s<octave>%d</octave></pitch>
        <duration>%d</duration>
        <lyric> <syllabic>single</syllabic> <text>%s</text> </lyric>
      </note>
      ]],
        step,
        alterXml,
        octave,
        duration,
        lyric
      )
  end,
  putRestNote = function(self, duration)
    duration = math.floor(duration * self.divisions + 0.5)
    self.xml =
      self.xml ..
      string.format([[
      <note>
        <rest/>
        <duration>%d</duration>
      </note>
      ]], duration)
  end,
  putMeasure = function(self)
    self.measure = self.measure + 1
    self.xml = self.xml .. string.format([[
    </measure>
    <measure number="%d">
]], self.measure)
  end,
  build = function(self)
    return self.xml .. [[
    </measure>
  </part>
</score-partwise>
]]
  end
}

function buildMusicXml()
  item = reaper.GetSelectedMediaItem(0, 0)
  if (item == nil) then
    error("No media item selected")
    return
  end

  take = reaper.GetActiveTake(item)

  evtcnt, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)

  -- get lyric
  lyric = {}
  for tc = 0, textsyxevtcnt - 1 do
    local ret, _, _, ppqpos, type, msg = reaper.MIDI_GetTextSysexEvt(take, tc)
    if type == 5 then -- lyric
      lyric[ppqpos] = msg
      print(ppqpos, msg)
    end
  end

  item_st = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  timesig_num, timesig_denom, tempo = reaper.TimeMap_GetTimeSigAtTime(proj, item_st)
  MusicXmlBuilder:putAttributes(2, 0, timesig_num, timesig_denom)
  MusicXmlBuilder:putDirection(tempo)

  -- iter notes and build music xml
  measure = 1
  last_ed_qn = 0.0
  for nc = 0, notecnt - 1 do
    local _, _, _, st_ppq, ed_ppq, _, pitch, _ = reaper.MIDI_GetNote(take, nc)
    local st_qn = reaper.MIDI_GetProjQNFromPPQPos(take, st_ppq)
    local ed_qn = reaper.MIDI_GetProjQNFromPPQPos(take, ed_ppq)
    if st_qn > last_ed_qn then
      local st, ed, dur = last_ed_qn, st_qn, st_qn - last_ed_qn
      if st >= measure * 4 then
        measure = measure + 1
        MusicXmlBuilder:putMeasure()
      end
      print(measure, st, ed, dur, "pau")
      MusicXmlBuilder:putRestNote(dur)
    end
    local st, ed, dur = st_qn, ed_qn, ed_qn - st_qn
    if st >= measure * 4 then
      measure = measure + 1
      MusicXmlBuilder:putMeasure()
    end
    print(measure, st_ppq, ed_ppq, st, ed, dur, pitch, lyric[st_ppq])
    MusicXmlBuilder:putNote(dur, pitch, lyric[st_ppq])
    last_ed_qn = ed_qn
  end
  musicxml = MusicXmlBuilder:build()
  return musicxml
end

function writeMusicXml(musicXmlPath, musicxml)
  file = io.open(musicxmlPath, "w")
  io.output(file)
  io.write(musicxml)
  io.close(file)
end

function runNEUTRINO(neutrinoPath, name)
  local musicxmlPath = neutrinoPath .. [[\score\musicxml\]] .. name .. [[.musicxml]]
  local musicXMLtoLabelPath = neutrinoPath .. [[\bin\musicXMLtoLabel.exe]]
  local labelFullPath = neutrinoPath .. [[\score\label\full\]] .. name .. [[.lab]]
  local labelMonoPath = neutrinoPath .. [[\score\label\mono\]] .. name .. [[.lab]]
  local musicXMLtoLabelOption = [[-x ]] .. neutrinoPath .. [[\settings\dic]]

  local command =
    musicXMLtoLabelPath ..
    " " .. musicxmlPath .. " " .. labelFullPath .. " " .. labelMonoPath .. " " .. musicXMLtoLabelOption
  print(command)
  if os.execute(command) == nil then
    error("Failed to execute musicXMLtoLabel")
    return
  end

  local neutrinoBinPath = neutrinoPath .. [[\bin\NEUTRINO.exe]]
  local labelTimingPath = neutrinoPath .. [[\score\label\timing\]] .. name .. [[.lab]]
  local f0OutputPath = neutrinoPath .. [[\output\]] .. name .. [[.f0]]
  local mgcOutputPath = neutrinoPath .. [[\output\]] .. name .. [[.mgc]]
  local bapOutputPath = neutrinoPath .. [[\output\]] .. name .. [[.bap]]
  local tempOutputPathes = f0OutputPath .. " " .. mgcOutputPath .. " " .. bapOutputPath
  local modelPath = neutrinoPath .. [[\model\KIRITAN\]]
  local neutrinoBinOption = [[-n 3 -k 0 -m -t]]

  local command =
    neutrinoBinPath ..
    " " ..
      labelFullPath .. " " .. labelTimingPath .. " " .. tempOutputPathes .. " " .. modelPath .. " " .. neutrinoBinOption
  print(command)
  if os.execute(command) == nil then
    error("Failed to execute NEUTRINO")
    return
  end

  local worldPath = neutrinoPath .. [[\bin\WORLD.exe]]
  local outputPath = neutrinoPath .. [[\output\]] .. name .. [[_syn.wav]]
  local worldOption = [[-f 1.0 -m 1.0 -o ]] .. outputPath .. [[ -n 3 -t]]

  local command = worldPath .. " " .. tempOutputPathes .. " " .. worldOption
  print(command)
  if os.execute(command) == nil then
    error("Failed to execute WORLD")
    return
  end

  return outputPath
end

function main()
  neutrinoPath = [[C:\path\to\NEUTRINO]]
  name = reaper.GetProjectName(0, "")
  if name == "" then
    name = "untitled"
  end

  musicxmlPath = neutrinoPath .. [[\score\musicxml\]] .. name .. [[.musicxml]]
  print(musicxmlPath)

  musicxml = buildMusicXml()
  writeMusicXml(musicxmlPath, musicxml)

  outputPath = runNEUTRINO(neutrinoPath, name)
  if outputPath == nil then
    return
  end
  print(outputPath)

  ret = reaper.InsertMedia(outputPath, 1)
  if ret == nil then
    error("Failed to load " .. outputPath)
    return
  end
end

main()
