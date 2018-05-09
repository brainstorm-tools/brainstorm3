function bz_MakeXMLFromProbeMaps(probemaplist, basepath,basename,plugorder,defaults)
%MakeXMLFromProbeMaps - Generate a .xml file to accompany .dat files for a
%recording in the neuroscope/klusters/ndmanager system.  Uses a library of
%probe map layouts.
%
%  USAGE
%
%    MakeXMLFromProbeMaps(basepath,basename,ProbeFileName1,ProbeFileName2...)
%       Example:
%    MakeXMLFromProbeMaps(cd,'','NRX_Buzsaki64_8X8','NRX_Buzsaki64_6X10');
%
%    Writes a standardized .xml file based on a user-selection of probe
%    maps and in a sequence specified by the user (ie 64site probe first
%    then 32site probe second).  Probe maps can be found at:
%    /buzcode/tree/master/generalComputation/geometries
%
%  INPUT
%
%    probemaplist   CharacterCell of names of .xlsx files specifying probe 
%                   geometries, must be on the path, ie from
%                   buzcode/GeneralComputation/Geometries).  See
%                   bz_ReadProbeGeometryFiles.m for more details
%    basepath       Path to directory to which to write output xml file and
%                   where to potentially find .rhd file. Default is path to
%                   the current directory.
%
%    basename       Shared name for this file and all others for this
%                   recording.  Default will the name of the basepath.
%
%
%    plugorder      Index/ordering of probemaplists to build into the
%                   xml... so if plugorder = [2 1] then the second listed 
%                   probe is put first, and the first named is added to the
%                   xml later
%
%  OUTPUT
%
%    (.xml file written to disk at basepath)
%
%  SEE
%
%    See also 
% Copyright (C) 2017 Brendon Watson
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 3 of the License, or
% (at your option) any later version.

%% Variable parsing
if ~exist('probemaplist','var') %make gui
    % mapfolder = fileparts(which 'NRX_Buzsaki64_8X8.xlsx');
    probemaplist = [];
end

% Just for output
if ~exist('basepath','var')
    basepath = cd;
elseif isempty(basepath)
    basepath = cd;
end
if ~exist('basename','var')
    [~,basename] = fileparts(basepath);
elseif isempty(basename)
    [~,basename] = fileparts(basepath);
end



if ~exist('plugorder','var') %make gui
    % mapfolder = fileparts(which 'NRX_Buzsaki64_8X8.xlsx');
    plugorder = 1:length(probemaplist);
end

if ~exist('defaults','var')%for use if no metadata exists prior
    defaults.NumberOfChannels = 1;
    defaults.SampleRate = 20000;
    defaults.BitsPerSample = 16;
    defaults.VoltageRange = 20;
    defaults.Amplification = 1000;
    defaults.LfpSampleRate = 1250;
    defaults.PointsPerWaveform = 32;
    defaults.PeakPointInWaveform = 16;
    defaults.FeaturesPerWave = 4;
end

probemaplist = probemaplist(plugorder);%re-sequence map list based on plugging


%% Define text components to assemble later
chunk1 = {'<?xml version=''1.0''?>';...
'<parameters version="1.0" creator="neuroscope-2.0.0">';...
' <acquisitionSystem>';...
['  <nBits>' num2str(defaults.BitsPerSample) '</nBits>']};

channelcountlinestart = '  <nChannels>';
channelcountlineend = '</nChannels>';

chunk2 = {['  <samplingRate>' num2str(defaults.SampleRate) '</samplingRate>'];...
['  <voltageRange>' num2str(defaults.VoltageRange) '</voltageRange>'];...
['  <amplification>' num2str(defaults.Amplification) '</amplification>'];...
'  <offset>0</offset>';...
' </acquisitionSystem>';...
' <fieldPotentials>';...
['  <lfpSamplingRate>' num2str(defaults.LfpSampleRate) '</lfpSamplingRate>'];...
' </fieldPotentials>';...
' <files>';...
'  <file>';...
'   <extension>lfp</extension>';...
['   <samplingRate>' num2str(defaults.LfpSampleRate) '</samplingRate>'];...
'  </file>';...
'  <file>';...
'   <extension>whl</extension>';...
'   <samplingRate>39.0625</samplingRate>';...
'  </file>';...
' </files>';...
' <anatomicalDescription>';...
'  <channelGroups>'};

anatomygroupstart = '   <group>';%repeats w every new anatomical group
anatomychannelnumberline_start = ['    <channel skip="0">'];%for each channel in an anatomical group - first part of entry
anatomychannelnumberline_end = ['</channel>'];%for each channel in an anatomical group - last part of entry
anatomygroupend = '   </group>';%comes at end of each anatomical group

chunk3 = {' </channelGroups>';...
  '</anatomicalDescription>';...
 '<spikeDetection>';...
  ' <channelGroups>'};%comes after anatomical groups and before spike groups

spikegroupstart = {'  <group>';...
        '   <channels>'};%repeats w every new spike group
spikechannelnumberline_start = ['    <channel>'];%for each channel in a spike group - first part of entry
spikechannelnumberline_end = ['</channel>'];%for each channel in a spike group - last part of entry
spikegroupend = {'   </channels>';...
   ['    <nSamples>' num2str(defaults.PointsPerWaveform) '</nSamples>'];...
   ['    <peakSampleIndex>' num2str(defaults.PeakPointInWaveform) '</peakSampleIndex>'];...
   ['    <nFeatures>' num2str(defaults.FeaturesPerWave) '</nFeatures>'];...
    '  </group>'};%comes at end of each spike group

chunk4 = {' </channelGroups>';...
 '</spikeDetection>';...
 '<neuroscope version="2.0.0">';...
  '<miscellaneous>';...
   '<screenGain>0.2</screenGain>';...
   '<traceBackgroundImage></traceBackgroundImage>';...
  '</miscellaneous>';...
  '<video>';...
   '<rotate>0</rotate>';...
   '<flip>0</flip>';...
   '<videoImage></videoImage>';...
   '<positionsBackground>0</positionsBackground>';...
  '</video>';...
  '<spikes>';...
  '</spikes>';...
  '<channels>'};

channelcolorstart = ' <channelColors>';...
channelcolorlinestart = '  <channel>';
channelcolorlineend = '</channel>';
channelcolorend = {'  <color>#0080ff</color>';...
    '  <anatomyColor>#0080ff</anatomyColor>';...
    '  <spikeColor>#0080ff</spikeColor>';...
   ' </channelColors>'};

channeloffsetstart = ' <channelOffset>';
channeloffsetlinestart = '  <channel>';
channeloffsetlineend = '</channel>';
channeloffsetend = {'  <defaultOffset>0</defaultOffset>';...
   ' </channelOffset>'};

chunk5 = {   '</channels>';...
 '</neuroscope>';...
'</parameters>'};

% % basic scaffolding examample for 1 channel probe
% thischan = 0;
% s = chunk1;
%     s = cat(1,s,anatomygroupstart);
%         s = cat(1,s,[anatomychannelnumberline_start, num2str(thischan) anatomychannelnumberline_end]);
%     s = cat(1,s,anatomygroupend);
% s = cat(1,s,chunk2);
%     s = cat(1,s,spikegroupstart);
%         s = cat(1,s,[spikechannelnumberline_start, num2str(thischan) spikechannelnumberline_end]);
%     s = cat(1,s,spikegroupend);
% s = cat(1,s, chunk3);

%% Gather probe maps
if ischar(probemaplist)
    probemaplist = {probemaplist};
end
[groupchans_byprobe,~,NumChansPerProbe] = bz_ReadProbeGeometryFiles(probemaplist);
TotalNumChannels = sum(NumChansPerProbe);
offsets = cat(2,0,cumsum(NumChansPerProbe));
for pidx = 2:size(groupchans_byprobe,1);%add to channel numbers to acount for previous probes
    for gidx = 1:size(groupchans_byprobe,2)
        groupchans_byprobe{pidx,gidx} = groupchans_byprobe{pidx,gidx}+offsets(pidx);
    end
end
% grouplist_all = [];
% groupchans_all = [];
% channelcountoffset = 0;
% for pmidx = 1:size(probemaplist,2)
%     tpf = probemaplist{pmidx};
%     if ~strcmp(probemaplist{pmidx}(end-4:end),'.xlsx')
%         tpf = strcat(tpf,'.xlsx');
%     end
%     tpp = which(tpf);
%     [tpnum,tptxt,tpraw] = xlsread(tpp);
%     
%     %find groups
%     groupcolumn = strmatch('BY VERTI',tptxt(1,:));
%     groupdenoterows = strmatch('SHANK ',tptxt(:,groupcolumn));
%     groupperchannel = [];
%     for ridx = 1:length(groupdenoterows);
%        groupperchannel = cat(1,groupperchannel,str2num(tptxt{groupdenoterows(ridx),groupcolumn}(7:end))); 
%     end
%     grouplist_byprobe{pmidx} = unique(groupperchannel);
%     grouplist_all = cat(1,grouplist_all,unique(groupperchannel));
%     
%     %find channels
%     channelcolumn = groupcolumn+2;%may definitely to change this
% %     groupcolumn = strmatch('Neuroscope channel',tptxt(1,:));
%     tc = tpraw(groupdenoterows,channelcolumn);
%     for cidx = 1:length(tc)
%         channelnums(cidx,1) = tc{cidx};
%     end
%     
%     %for each group, find the channels in it, save in sequence
%     for gidx = 1:length(grouplist_byprobe{pmidx})
%        tgidx = groupperchannel==grouplist_byprobe{pmidx}(gidx);%find rows whith this group/shank denotation 
%        groupchans_byprobe{pmidx,gidx} = channelnums(tgidx)+channelcountoffset;
%        groupchans_all = cat(1,groupchans_all,channelnums(tgidx))+channelcountoffset; 
%     end
%     numchansthisprobe = length(channelnums);
%     channelcountoffset = numchansthisprobe;
%     numchans = length(groupchans_all);
% end

%% Check and set up numbers of channels
if TotalNumChannels ~= defaults.NumberOfChannels
    defaults.NumberOfChannels = TotalNumChannels;
    warning('Number of channels found in the probe maps does not match the number input as default.  Will use total number specified in probe maps');
end

if isempty(probemaplist)
    groupchans_byprobe{1,1} = [0:defaults.NumberOfChannels-1];
end

%% Make basic text 
s = chunk1;

s = cat(1,s,[channelcountlinestart, num2str(sum(NumChansPerProbe)) channelcountlineend]);

s = cat(1,s,chunk2);

%add channel count here

for pidx = 1:size(groupchans_byprobe,1)%for each probe
    for gidx = 1:size(groupchans_byprobe,2)%for each spike group
        if ~isempty(groupchans_byprobe{pidx,gidx})
            s = cat(1,s,anatomygroupstart);
            tchanlist = groupchans_byprobe{pidx,gidx};
            for chidx = 1:length(tchanlist)
                thischan = tchanlist(chidx);
                s = cat(1,s,[anatomychannelnumberline_start, num2str(thischan) anatomychannelnumberline_end]);
            end
            s = cat(1,s,anatomygroupend);
        end
    end
end

s = cat(1,s,chunk3);

for pidx = 1:size(groupchans_byprobe,1)%for each probe
    for gidx = 1:size(groupchans_byprobe,2)%for each spike group
        if ~isempty(groupchans_byprobe{pidx,gidx})
            s = cat(1,s,spikegroupstart);
            tchanlist = groupchans_byprobe{pidx,gidx};
            for chidx = 1:length(tchanlist)
                thischan = tchanlist(chidx);
                s = cat(1,s,[spikechannelnumberline_start, num2str(thischan) spikechannelnumberline_end]);
            end
            s = cat(1,s,spikegroupend);
        end
    end
end

s = cat(1,s, chunk4);

for pidx = 1:size(groupchans_byprobe,1)%for each probe
    for gidx = 1:size(groupchans_byprobe,2)%for each spike group
        if ~isempty(groupchans_byprobe{pidx,gidx})
            tchanlist = groupchans_byprobe{pidx,gidx};
            for chidx = 1:length(tchanlist)
                thischan = tchanlist(chidx);
                s = cat(1,s,channelcolorstart);
                s = cat(1,s,[channelcolorlinestart, num2str(thischan) channelcolorlineend]);
                s = cat(1,s,channelcolorend);
                s = cat(1,s,channeloffsetstart);
                s = cat(1,s,[channeloffsetlinestart, num2str(thischan) channeloffsetlineend]);
                s = cat(1,s,channeloffsetend);
            end
        end
    end
end

s = cat(1,s, chunk5);


%% Output
charcelltotext(s,fullfile(basepath,[basename '.xml']));


function charcelltotext(charcell,filename)
%based on matlab help.  Writes each row of the character cell (charcell) to a line of
%text in the filename specified by "filename".  Char should be a cell array 
%with format of a 1 column with many rows, each row with a single string of
%text.

[nrows,ncols]= size(charcell);

fid = fopen(filename, 'w');

for row=1:nrows
    fprintf(fid, '%s \n', charcell{row,:});
end

fclose(fid);