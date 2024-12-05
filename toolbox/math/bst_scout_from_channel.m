function OutputFile = bst_scout_from_channel(ChannelFile, radius, isInteractive)
% bst_scout_from_channel: Convert a channel file to scout on the scalp (all the vertex within a specified radius is included to the scout).
% If the radius is 0, then return the closed point on the head for each sensor
%
% USAGE:  OutputFile = bst_project_channel(ChannelFile, radius = 5 mm, isInteractive=1)
%        OutputFiles = bst_project_channel(ChannelFiles, ...)
% 
% INPUT:
%    - ChannelFile   : Relative path to channel file to project
%    - radius : Radius used to create the scout on the scalp (in mm)
%    - isInteractive : If 1, display interactive messages

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c) University of Southern California & McGill University
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
% Authors: Edouard Delaire, 2024

% ===== PARSE INPUTS ======
if (nargin < 3) || isempty(isInteractive)
    isInteractive = 1;
end

if (nargin < 2) || isempty(radius)

    if isInteractive
        radius = str2double(java_dialog('input', 'Enter the redius to consider around each electrodes (in mm):', '', [] , '5'));
    else
        radius = 5;
    end
end

% Calling recursively on multiple channel files
if iscell(ChannelFile)
    OutputFile = cell(size(ChannelFile));
    for i = 1:length(ChannelFile)
        OutputFile{i} = bst_scout_from_channel(ChannelFile{i}, radius, isInteractive);
    end
    return;
end
OutputFile = [];

% ===== GET INPUT DATA =====

% Progress bar
isProgress = bst_progress('isVisible');
bst_progress('start', 'Project channel file', 'Loading MRI files...');

% Get subject
[sStudy, iStudy]     = bst_get('ChannelFile', ChannelFile);
[sSubject, iSubject] = bst_get('Subject', sStudy.BrainStormSubject);

% Check subjects
errMsg = [];
if (sSubject.UseDefaultChannel && (iSubject ~= 0))
    errMsg = 'Subject is using the default anatomy.';
elseif isempty(sSubject.Anatomy)
    errMsg = 'Subject do not have any anatomical MRI.';
end

% Error handling
if ~isempty(errMsg)
    if isInteractive
        bst_error(errMsg, 'Project channel file', 0);
    else
        bst_report('Error', 'bst_project_channel', [], errMsg);
    end
    return;
end


% Load Scalp
sScalp = in_tess_bst( sSubject.Surface(sSubject.iScalp).FileName);

% Head vertices location (in SCS)
head_vertices   = sScalp.Vertices; 

% Load surface
sSurf = in_tess_bst(surfaceTarget);
surfVertices = sSurf.Vertices;

% ===== SCOUTS FROM CHANNEL FILE =====
bst_progress('start', 'Scouts from sensors', 'Loading surface file...');
ChannelMat = in_bst_channel(ChannelFile);
iChannels = channel_find(ChannelMat.Channel, modalityTarget);

%TODO check that sensors are on the selected surface, if not, return error

% Project sensors
scoutVertices = [];
for ix = 1 : length(iChannels)
    if isempty(ChannelMat.Channel(iChannels(ix)).Loc)
        continue
    end
    for iLoc = 1 : size(ChannelMat.Channel(iChannels(ix)).Loc, 2)
        distances = sqrt(sum((surfVertices - ChannelMat.Channel(iChannels(ix)).Loc(:, iLoc)').^2, 2));
        scoutVertices = [scoutVertices, find(distances < radiusTarget./1000)'];
    end
end

% Create scout
scout_channel = db_template('Scout'); 
scout_channel.Label    = sprintf('%s | %s (%d mm)', sStudy.Condition{1}, strjoin(modalityTarget, ' '), radiusTarget);
scout_channel.Vertices = scoutVertices;
scout_channel.Seed     = scoutVertices(1);
scout_channel.Handles  = [];
scout_channel.Color    = [1 0 0];

% ===== SAVE SCOUT =====
bst_progress('text', 'Saving scouts...');
atlasName = 'Scout from sensors';
s.Atlas = sSurf.Atlas;
if ~isempty(s.Atlas) && ismember(atlasName, {s.Atlas.Name})
    [~, iAtlas] = ismember(atlasName, {s.Atlas.Name});
else
    s.Atlas(end+1).Name = 'Scout from sensors';
    iAtlas = length(s.Atlas);
end
if ~isempty(s.Atlas(iAtlas).Scouts) && ismember(scout_channel.Label, {s.Atlas(iAtlas).Scouts.Label})
    [~, iScout] = ismember(scout_channel.Label, {s.Atlas(iAtlas).Scouts.Label});
else
    s.Atlas(iAtlas).Scouts(end+1) = scout_channel;
    iScout = length(s.Atlas(iAtlas).Scouts);
end
s.Atlas(iAtlas).Scouts(iScout) = scout_channel;
bst_save(file_fullpath(surfaceTarget), s, [], 1);
OutputFile = surfaceTarget;
% Close progress bar
if ~isProgress
    bst_progress('stop');
end

end
