function OutputFile = bst_scout_from_channel(ChannelFile, SurfaceFile, Modality, Radius)
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
%          Raymundo Cassani, 2024

% ===== PARSE INPUTS ======
if (nargin < 4)
    Radius = [];
    if (nargin < 3)
        Modality = [];
        if (nargin < 2)
            SurfaceFile = [];
        end
    end
end
errMsg     = [];
OutputFile = SurfaceFile;

% Get Subject info
sStudy = bst_get('ChannelFile', file_short(ChannelFile));
[sSubject, iSubject] = bst_get('Subject', sStudy.BrainStormSubject);
% Subjects must be either the default anatomy, or must have individual anatomy
if (sSubject.UseDefaultChannel && (iSubject ~= 0))
    errMsg = 'Subject is using the default anatomy.';
    return
end

% Modality options (options with Location)
[~, modalityOptions] = bst_get('ChannelModalities', ChannelFile);
% Surface options
surfaceOptions = {};
if ~isempty(sSubject.iScalp)
    surfaceOptions{end+1} = 'Scalp';
end
if ~isempty(sSubject.iOuterSkull)
    surfaceOptions{end+1} = 'OuterSkull';
end
if ~isempty(sSubject.iInnerSkull)
    surfaceOptions{end+1} = 'InnerSkull';
end
if ~isempty(sSubject.iCortex)
    surfaceOptions{end+1} = 'Cortex';
end

% Get and validate Modality, SurfaceFile and Radius
surfaceTarget  = [];
modalityTarget = [];
radiusTarget   = [];

% Modality
if isempty(errMsg) && ~isempty(Modality)
    if ~iscell(Modality)
        Modality = {Modality};
    end
    if all(ismember(Modality, modalityOptions))
        modalityTarget = Modality;
    else
        modalityMiss = setdiff(Modality, modalityOptions);
        errMsg = ['Requested modality: "', strjoin(modalityMiss, ', '), '" not found in Channel file.'];

    end
elseif isempty(errMsg) && isempty(Modality)
    [modalityTarget, isCancel] = java_dialog('checkbox', 'Which sensor modality or modalities will be used to create surface scouts?', ...
                                             'Scouts from sensors', [], modalityOptions);
    if isempty(modalityTarget) || isCancel
        return
    end
end

% Surface
if isempty(errMsg) && ~isempty(SurfaceFile)
    % Surface is a filename
    if ~strcmpi(file_gettype(SurfaceFile), 'unknown') && file_exist(file_fullpath(SurfaceFile))
        [~, iSubjectSurf] = bst_get('SurfaceFile', SurfaceFile);
        if iSubject == iSubjectSurf
            surfaceTarget = SurfaceFile;
            surfaceType = file_gettype(SurfaceFile);
        else
            errMsg = 'Subjects for channel File and for Surface files are not the same.';
        end
    % Surface is Type
    else
        if ismember(SurfaceFile, surfaceOptions)
            surfaceType = SurfaceFile;
            surfaceTarget = sSubject.Surface(sSubject.(['i' surfaceType])).FileName;
        else
            errMsg = ['Subject does not have default surface of type ' SurfaceFile  '.'];
        end
    end
elseif isempty(errMsg) && isempty(SurfaceFile)
    [surfaceType, isCancel] = java_dialog('question', sprintf('Surface to create scouts from [%s] sensors:', strjoin(modalityTarget, ', ')), ...
                                          'Scouts from sensors', [], surfaceOptions);
    if isempty(surfaceType) || isCancel
        return
    end
    surfaceTarget = sSubject.Surface(sSubject.(['i' surfaceType])).FileName;
end

% Radius
if isempty(errMsg) && ~isempty(Radius)
    radiusTarget = Radius;
elseif isempty(errMsg) && isempty(Radius)
    [res, isCancel] = java_dialog('input', sprintf('Radius (in mm) for scouts on [%s] surface for sensors [%s]:', ...
                                                    surfaceType, strjoin(modalityTarget, ', ')), ...
                                  'Scouts from sensors', [], '5');
    if isempty(res) || isCancel
        return
    end
    radiusTarget = str2double(res);
end
if radiusTarget < 0
    errMsg = 'Radius must be larger than 0 mm.';
end

% Error handling
if ~isempty(errMsg)
    bst_report('Error', 'bst_scout_from_channel', [], errMsg);
    return;
end

% ===== GET INPUT DATA =====
% Progress bar
isProgress = bst_progress('isVisible');
bst_progress('start', 'Scouts from sensors', 'Loading surface file...');

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
