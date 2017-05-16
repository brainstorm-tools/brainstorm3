function [sFile, ChannelMat] = in_fopen_nicolet(DataFile)
% IN_FOPEN_NICOLET: Open a Nicolet .e file

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Authors: Francois Tadel, 2017


%% ===== READ HEADER =====
% Read Nicolet file
hdr.obj = NicoletFile(DataFile);
% Check the number of segments
if (length(hdr.obj.segments) > 1)
    error(['Nicolet files with multiple segments are not supported yet.' 10 'Please contact us through the forum if you need this feature to be enabled.']);
end
% Read only the channels with the maximum sampling frequency
sfreq = max(hdr.obj.segments.samplingRate);
hdr.selchan = find(hdr.obj.segments.samplingRate == sfreq);
hdr.numchan = length(hdr.selchan);
% Display message to display ignored channels
iIgnored = setdiff(1:length(hdr.obj.segments.samplingRate), hdr.selchan);
if ~isempty(iIgnored)
    fprintf(1, 'NICOLET> Warning: The following channels were ignored because they have a lower sampling rate: ');
    for i = 1:length(iIgnored)
        fprintf(1, '%s ', str_clean(hdr.obj.segments.chName{iIgnored(i)}));
    end
    fprintf(1, '\n');
end


%% ===== FILL STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.byteorder    = 'n';
sFile.filename     = DataFile;
sFile.format       = 'EEG-NICOLET';
sFile.prop.sfreq   = sfreq;
sFile.prop.samples = [0, sfreq * hdr.obj.segments.duration - 1];
sFile.prop.times   = sFile.prop.samples ./ sFile.prop.sfreq;
sFile.prop.nAvg    = 1;
sFile.channelflag  = ones(hdr.numchan,1);
sFile.device       = 'Nicolet';
sFile.header       = hdr;
% Comment: short filename
[fPath, fBase, fExt] = bst_fileparts(DataFile);
sFile.comment = fBase;


%% ===== CREATE EMPTY CHANNEL FILE =====
ChannelMat.Comment = [sFile.device ' channels'];
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, hdr.numchan]);
% For each channel
for i = hdr.selchan
    ChannelMat.Channel(i).Type    = 'EEG';
    ChannelMat.Channel(i).Name    = strrep(str_clean(hdr.obj.segments.chName{hdr.selchan(i)}), ' ', '');
    ChannelMat.Channel(i).Name = strrep(ChannelMat.Channel(i).Name, '-Ref', '');
    ChannelMat.Channel(i).Name = strrep(ChannelMat.Channel(i).Name, '-ref', '');
    ChannelMat.Channel(i).Name = strrep(ChannelMat.Channel(i).Name, '-REF', '');
    strRef = str_clean(hdr.obj.segments.refName{hdr.selchan(i)});
    if ~isempty(strRef)
        ChannelMat.Channel(i).Comment = ['Reference: ', strRef];
    end
end


%% ===== FORMAT EVENTS =====
% Get user and event ID
allUser = {hdr.obj.eventMarkers.user};
allId   = {hdr.obj.eventMarkers.IDStr};
allEvt  = cell(size(allUser));
% Generate event names
for i = 1:length(allEvt)
    if isempty(allUser{i}) && (strcmpi(allId{i}, 'UNKNOWN') || isempty(allId{i}))
        allEvt{i} = 'UNKNOWN';
    elseif strcmpi(allId{i}, 'UNKNOWN')
        allEvt{i} = allUser{i};
    elseif isempty(allUser{i})
        allEvt{i} = allId{i};
    else
        allEvt{i} = [allUser{i} '-' allId{i}];
    end
end
% Create full list of event times
allTime = ([hdr.obj.eventMarkers.dateOLE] - hdr.obj.segments.dateOLE) * 3600 * 24 + [hdr.obj.eventMarkers.dateFraction];
% Get all the epochs names
uniqueEvt = unique(allEvt);
% Create one category for each event
for iEvt = 1:length(uniqueEvt)
    % Get all the occurrences
    iOcc = find(strcmpi(allEvt, uniqueEvt{iEvt}));
    % Create event structure
    sFile.events(iEvt).label   = uniqueEvt{iEvt};
    sFile.events(iEvt).times   = sort(allTime(iOcc));
    sFile.events(iEvt).samples = sFile.events(iEvt).times .* sFile.prop.sfreq;
    sFile.events(iEvt).epochs  = ones(size(sFile.events(iEvt).samples));
    sFile.events(iEvt).select  = 1;
end



end



%% ===== CLEAN STRINGS =====
function s = str_clean(s)
    % Stop string at first termination
    iNull = find(s == 0, 1);
    if ~isempty(iNull)
        s(iNull:end) = [];
    end
    % Remove weird characters
    s(~ismember(s, '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-.()[]/\_@ ')) = [];
    % Remove useless spaces
    s = strtrim(s);
end


