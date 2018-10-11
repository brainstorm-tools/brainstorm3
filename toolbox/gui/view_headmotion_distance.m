function hFig = view_headmotion_distance(DataFile, Modality)
% VIEW_HAEDMOTION_DISTANCE: Display head motion distance over time
%
% USAGE:  view_headmotion_distance(DataFile)

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Martin Cousineau, 2018

if ~strcmpi(Modality, 'HLU')
    error('Unsupported modality.');
end

% Load necessary data from data file
DataMat = in_bst_data(DataFile);
sFile = DataMat.F;
isContinuous = strcmpi(sFile.format, 'CTF-CONTINUOUS');
iDS = bst_memory('LoadDataFile', DataFile);
[TimeVector, iTime] = bst_memory('GetTimeVector', iDS, [], 'UserTimeWindow');
TimeVector = TimeVector(iTime);
SamplesBounds = [iTime(1), iTime(end)];

if ~strcmpi(sFile.device, 'CTF')
    error('Unsupported file format.');
end

% Prepare inputs
sInput = struct();
sInput.FileType = DataMat.DataType;
sInput.FileName = DataFile;
sInput.ChannelFile = bst_get('ChannelFileForStudy', DataFile);
ChannelMat = in_bst_channel(sInput.ChannelFile);
InitLoc = [ChannelMat.SCS.NAS, ChannelMat.SCS.LPA, ChannelMat.SCS.RPA]';

% Call head motion process
[Locations, HeadSamplePeriod, FitErrors] = ...
    process_evt_head_motion('LoadHLU', sInput, SamplesBounds, ~isContinuous);
DistDowns = process_evt_head_motion('RigidDistances', Locations, InitLoc);

% Resample
nS = size(Locations, 2);
nT = size(Locations, 3);
Dist = zeros(nT, nS * HeadSamplePeriod);
for t = 1:nT
    Dist(t, :) = interp1(DistDowns(:, t), (1:nS * HeadSamplePeriod) / HeadSamplePeriod);
    % Replace initial NaNs with first value.
    Dist(t, isnan(Dist(t, :))) = Dist(t, find(~isnan(Dist(t, :)), 1));
end

% Open figure
hFig = view_timeseries_matrix(DataFile, Dist, TimeVector, Modality, {}, {'Distance'});

end


 
 
