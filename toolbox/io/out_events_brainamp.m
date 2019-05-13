function out_events_brainamp( sFile, VmrkFile )
% OUT_EVENTS_BRAINAMP: Export events to a BrainVision/BrainAmp .vmrk file.
%
% USAGE:  out_events_brainamp( sFile, VmrkFile )

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2018-2019

% Open file
fid = fopen(VmrkFile, 'w');
if (fid == -1)
    error(['Could not open marker file: ' VmrkFile]);
end
% Get filename
[fPath, fBase, fExt] = bst_fileparts(sFile.filename);
% Print header
fprintf(fid, [...
    'Brain Vision Data Exchange Marker File, Version 1.0', 10, ...
    '', 10, ...
    '[Common Infos]', 10, ...
    'Codepage=UTF-8', 10, ...
    'DataFile=', [fBase, fExt], 10, ...
    '', 10, ...
    '[Marker Infos]', 10, ...
    '; Each entry: Mk<Marker number>=<Type>,<Description>,<Position in data points>,', 10, ...
    '; <Size in data points>, <Channel number (0 = marker is related to all channels)>', 10, ...
    '; Fields are delimited by commas, some fields might be omitted (empty).', 10, ...
    '; Commas in type or description text are coded as "\\1".', 10]);

% Reorganize markers in chronological order
mrkNames = {};
mrkSamples = [];
mrkDuration = [];
for i = 1:length(sFile.events)
    evtSamples = round((sFile.events(i).times - sFile.prop.times(1)) .* sFile.prop.sfreq);
    mrkNames = cat(2, mrkNames, repmat({sFile.events(i).label}, 1, size(sFile.events(i).times, 2)));
    mrkSamples = cat(2, mrkSamples, evtSamples(1,:));
    if (size(sFile.events(i).times, 1) == 2)
        mrkDuration = cat(2, mrkDuration, evtSamples(2,:) - evtSamples(1,:) + 1);
    else
        mrkDuration = cat(2, mrkDuration, ones(1, size(sFile.events(i).times, 2)));
    end
end
[mrkSamples, I] = sort(mrkSamples);
mrkNames = mrkNames(I);
mrkDuration = mrkDuration(I);
% Print markers
for i = 1:length(mrkSamples)
    if (mrkSamples(i) == 1) && isequal(mrkNames{i}, 'Mk')
        fprintf(fid, 'Mk%d=New Segment,,1,1,0,0\n', i);
    else
        fprintf(fid, 'Mk%d=Stimulus,%s,%d,%d,0\n', i, mrkNames{i}, mrkSamples(i), mrkDuration(i));
    end
end
% Close file
fclose(fid);

    