function OutputFile = bst_scout_from_channel(ChannelFile, radius, isInteractive)
% bst_scout_from_channel: Convert a channel file to scout on the scalp (all the vertex within a specified radius is included to the scout).
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

% Find closest head vertices (for which we have fluence data)
% Put everything in mri referential
head_vertices_mri   = sScalp.Vertices; % cs_convert(sMri, 'scs', 'mri', sScalp.Vertices) * 1000;

% ===== PROJECT CHANNEL FILE =====

channel_locs_mri = [];

% Project sensors
ChannelMat = in_bst_channel(ChannelFile);
for i = 1:length(ChannelMat.Channel)
    if ~isempty(ChannelMat.Channel(i).Loc)
        if size(ChannelMat.Channel(i).Loc,2) == 2
            channel_locs_mri(end+1, :) = ChannelMat.Channel(i).Loc(:,1);  
            channel_locs_mri(end+1, :) = ChannelMat.Channel(i).Loc(:,2);

        else
            channel_locs_mri(end+1, :) = ChannelMat.Channel(i).Loc;
        end
    end
end

Vertices = [];
for i = 1:size(channel_locs_mri, 1)
    
    distances = zeros(1, size(head_vertices_mri, 1));

    for j = 1:size(head_vertices_mri, 1)
        x = channel_locs_mri(i,:);
        y = head_vertices_mri(j, :);

        distances(j) = 1000 * sum((x-y).^2).^0.5; % mm
    end
    if radius > 0
        idx = find(distances <= radius);
    else
        [~, idx] = min(distances);
    end
    
    Vertices = [Vertices  idx];
end

scout_channel = db_template('Scout'); 
scout_channel.Label = sprintf('Scout from %s ( %d mm)', ChannelMat.Comment, radius)  ;
scout_channel.Vertices = Vertices;
scout_channel.Seed = Vertices(1);
scout_channel.Handles = [];
scout_channel.Color = [1 0 0];

% ===== SAVE NEW FILE =====
bst_progress('text', 'Saving results...');

sScalp.Atlas(1).Scouts(end+1) = scout_channel;
bst_save( file_fullpath(sSubject.Surface(sSubject.iScalp).FileName), sScalp)
OutputFile = {sSubject.Surface(sSubject.iScalp).FileName};

% Close progress bar
if ~isProgress
    bst_progress('stop');
end

end
