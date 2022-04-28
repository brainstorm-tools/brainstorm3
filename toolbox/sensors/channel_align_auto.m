function [ChannelMat, R, T, isSkip, isUserCancel, strReport, tolerance] = channel_align_auto(ChannelFile, ChannelMat, isWarning, isConfirm, tolerance)
% CHANNEL_ALIGN_AUTO: Aligns the channels to the scalp using Polhemus points.
%
% USAGE:  [ChannelMat, R, T, isSkip, isUserCancel, strReport] = channel_align_auto(ChannelFile, ChannelMat=[], isWarning=1, isConfirm=1, tolerance=0)
%
% DESCRIPTION: 
%     Aligns the channels to the scalp using Polhemus points stored in channel structure.
%     We assume rough registration via the nasion (NAS), left preauricular (LPA) and right
%     preauricular (RPA) has already aligned the channels to the scalp. 
%     We then use the a Gauss-Newton algorithm to fine-tune that registration 
%     based on the "extra head points" representing the Polhemus data
%     The result will be that (new) ChannelMat.Loc = R * (old) ChannelMat.Loc + T and
%     similarly for the head points.
%
% INPUTS:
%     - ChannelFile : Channel file to align on its anatomy
%     - ChannelMat  : If specified, do not read or write any information from/to ChannelFile
%     - isWarning   : If 1, display warning in case of errors (default = 1)
%     - isConfirm   : If 1, ask the user for confirmation before proceeding
%     - tolerance   : Percentage of outliers head points, ignored in the final fit
%
% OUTPUTS:
%     - ChannelMat   : The same ChannelMat structure input in, with the head points and sensors rotated and translated to match the head points to the scalp.
%                      Returned value is [] if the registration was cancelled
%     - R            : 3x3 rotation matrix from original ChannelMat to new ChannelMat.
%     - T            : 3x1 translate vector to go with R.
%     - isSkip       : If 1, processing was skipped because there was not enough information in the file
%     - isUserCancel : If 1, user cancelled the alignment
%     - strReport    : Text description of the quality of the alignment (distance between headpoint and scalp surface)
%     - tolerance    : The same tolerance input if alignment was performed, otherwise empty


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
% Authors: Syed Ashrafulla, 2009
%          Francois Tadel, 2009-2021

%% ===== PARSE INPUTS =====
if (nargin < 5) || isempty(tolerance)
    tolerance = 0;
end
if (nargin < 4) || isempty(isConfirm)
    isConfirm = 1;
end
if (nargin < 3) || isempty(isWarning)
    isWarning = 1;
end
if (nargin < 2) || isempty(ChannelMat)
    ChannelMat = in_bst_channel(ChannelFile);
    isSave = 1;
else
    isSave = 0;
end
R = [];
T = [];
isSkip = 0;
isUserCancel = 0;
strReport = '';

%% ===== LOAD CHANNELS =====
% Progress bar
bst_progress('start', 'Automatic EEG-MEG/MRI registration', 'Initialization...');
% Get head points
HeadPoints = channel_get_headpoints(ChannelMat, 1, 1);
% Check number of surface points
MIN_NPOINTS = 15;
if isempty(HeadPoints) || (length(HeadPoints.Label) < MIN_NPOINTS)
    % Warning
    if isWarning
        bst_error('Not enough digitized head points to perform automatic registration.', 'Automatic EEG-MEG/MRI registration', 0);
    else
        disp('BST> Not enough digitized head points to perform automatic registration.');
    end
    bst_progress('stop');
    isSkip = 1;
    return;
end
% M x 3 matrix of head points
HP = double(HeadPoints.Loc');

%% ===== LOAD SCALP SURFACE =====
% Get study
sStudy = bst_get('ChannelFile', ChannelFile);
% Get subject
sSubject = bst_get('Subject', sStudy.BrainStormSubject);
if isempty(sSubject) || isempty(sSubject.iScalp)
    if isWarning
        bst_error('No scalp surface available for this subject', 'Align EEG sensors', 0);
    else
        disp('BST> No scalp surface available for this subject.');
    end
    bst_progress('stop');
    return
end
% Load scalp surface
SurfaceMat = in_tess_bst(sSubject.Surface(sSubject.iScalp).FileName);


%% ===== ASK FOR CONFIRMATION =====
if isConfirm
    % Ask for user confirmation
    Align = java_dialog('confirm', ['The current registration sensors/anatomy is based only on' 10 ...
                                    'the three fiducial points NAS/LPA/RPA, and might be inaccurate.' 10 ...
                                    'Digitized head points can be used to refine this registration.' 10 10 ...
                                    'Refine registration now?' 10], 'Sensors/anatomy registration');
    % If user denied: exit
    if ~Align
        isUserCancel = 1;
        bst_progress('stop');
        return
    end
end
% Ask for tolerance value
if (isConfirm || isWarning)
    res = java_dialog('input', ['You can choose to ignore the digitized head points that are far ' 10 ...
                                'away from the scalp in the surface fit.' 10 10 ...
                                'Percentage of head points to ignore [0-100]:'], ...
                                'Refine registration', [], num2str(round(tolerance*100)));
    if isempty(res) || isnan(str2double(res))
        isUserCancel = 1;
        tolerance = [];
        bst_progress('stop');
        return
    end
    tolerance = str2double(res) / 100;
end
% Check feasibility
if ~isempty(tolerance)
    % Number of points to remove
    nRemove = ceil(tolerance * size(HP,1));
    % Invalid tolerance value
    if (tolerance > 0.99) || (size(HP,1) - nRemove < MIN_NPOINTS)
        if isWarning
            bst_error('Invalid tolerance value or not enough head points left.', 'Automatic EEG-MEG/MRI registration', 0);
        else
            disp('BST> Invalid tolerance value or not enough head points left.');
        end
        % Cancel processing as a user error
        isUserCancel = 1;
        tolerance = [];
        bst_progress('stop');
        return
    end
end


%% ===== FIND OPTIMAL FIT =====
% Find best possible rigid transformation (rotation+translation)
[R,T,tmp,dist] = bst_meshfit(SurfaceMat.Vertices, SurfaceMat.Faces, HP);
% Remove outliers and fit again
if ~isempty(dist) && ~isempty(tolerance) && (tolerance > 0)
    % Sort points by distance to scalp
    [tmp__, iSort] = sort(dist, 1, 'descend');
    iRemove = iSort(1:nRemove);
    % Remove from list of destination points
    HP(iRemove,:) = [];
    % Fit again
    [R,T,tmp,dist] = bst_meshfit(SurfaceMat.Vertices, SurfaceMat.Faces, HP);
else
    nRemove = 0;
end
% Current position cannot be optimized
if isempty(R)
    bst_progress('stop');
    isSkip = 1;
    tolerance = [];
    return;
end
% Distance between fitted points and reference surface
strReport = ['Distance between ' num2str(length(dist)) ' head points and head surface:' 10 ...
    ' |  Mean : ' sprintf('%4.1f', mean(dist) * 1000) ' mm  |  Distance >  3mm: ' sprintf('%3d points (%2d%%)\n', nnz(dist > 0.003), round(100*nnz(dist > 0.003)/length(dist))), ...
    ' |  Max  : ' sprintf('%4.1f', max(dist) * 1000)  ' mm  |  Distance >  5mm: ' sprintf('%3d points (%2d%%)\n', nnz(dist > 0.005), round(100*nnz(dist > 0.005)/length(dist))), ...
    ' |  Std  : ' sprintf('%4.1f', std(dist) * 1000)  ' mm  |  Distance > 10mm: ' sprintf('%3d points (%2d%%)\n', nnz(dist > 0.010), round(100*nnz(dist > 0.010)/length(dist))), ...
    ' |  Number of outlier points removed: ' sprintf('%d (%d%%)', nRemove, round(tolerance*100)), 10 ...
    ' |  Initial number of head points: ' num2str(size(HeadPoints.Loc,2))];

%% ===== ROTATE SENSORS AND HEADPOINTS =====
for i = 1:length(ChannelMat.Channel) 
    % Rotate and translate location of channel
    if ~isempty(ChannelMat.Channel(i).Loc) && ~all(ChannelMat.Channel(i).Loc(:) == 0)
        ChannelMat.Channel(i).Loc = R * ChannelMat.Channel(i).Loc + T * ones(1,size(ChannelMat.Channel(i).Loc, 2));
    end
    % Only rotate normal vector to channel
    if ~isempty(ChannelMat.Channel(i).Orient) && ~all(ChannelMat.Channel(i).Orient(:) == 0)
        ChannelMat.Channel(i).Orient = R * ChannelMat.Channel(i).Orient;
    end
end
% Rotate and translate head points
if isfield(ChannelMat, 'HeadPoints') && ~isempty(ChannelMat.HeadPoints) && ~isempty(ChannelMat.HeadPoints.Loc)
    ChannelMat.HeadPoints.Loc = R * ChannelMat.HeadPoints.Loc + ...
                                T * ones(1, size(ChannelMat.HeadPoints.Loc, 2));
end

%% ===== SAVE TRANSFORMATION =====
% Initialize fields
if ~isfield(ChannelMat, 'TransfEeg') || ~iscell(ChannelMat.TransfEeg)
    ChannelMat.TransfEeg = {};
end
if ~isfield(ChannelMat, 'TransfMeg') || ~iscell(ChannelMat.TransfMeg)
    ChannelMat.TransfMeg = {};
end
if ~isfield(ChannelMat, 'TransfMegLabels') || ~iscell(ChannelMat.TransfMegLabels) || (length(ChannelMat.TransfMeg) ~= length(ChannelMat.TransfMegLabels))
    ChannelMat.TransfMegLabels = cell(size(ChannelMat.TransfMeg));
end
if ~isfield(ChannelMat, 'TransfEegLabels') || ~iscell(ChannelMat.TransfEegLabels) || (length(ChannelMat.TransfEeg) ~= length(ChannelMat.TransfEegLabels))
    ChannelMat.TransfEegLabels = cell(size(ChannelMat.TransfEeg));
end
% Create [4,4] transform matrix
newtransf = eye(4);
newtransf(1:3,1:3) = R;
newtransf(1:3,4)   = T;
% Add a rotation/translation to the lists
ChannelMat.TransfMeg{end+1} = newtransf;
ChannelMat.TransfEeg{end+1} = newtransf;
% Add the comments
ChannelMat.TransfMegLabels{end+1} = 'refine registration: head points';
ChannelMat.TransfEegLabels{end+1} = 'refine registration: head points';

% History: Auto-registration
ChannelMat = bst_history('add', ChannelMat, 'align', 'Refining the registration using the head points:');
% History: Rotation + translation
ChannelMat = bst_history('add', ChannelMat, 'transform', sprintf('Rotation: [%1.3f,%1.3f,%1.3f; %1.3f,%1.3f,%1.3f; %1.3f,%1.3f,%1.3f]', R'));
ChannelMat = bst_history('add', ChannelMat, 'transform', sprintf('Translation: [%1.3f,%1.3f,%1.3f]', T));
% Save file
if isSave
    bst_save(file_fullpath(ChannelFile), ChannelMat, 'v7');
end


%% ===== VIEW RESULTS =====
% If there was some interaction requested from the user
if isSave && (isWarning || isConfirm)
    % Close all the other windows
    bst_memory('UnloadAll', 'Forced');
    % Get leading modality
    iMeg = good_channel(ChannelMat.Channel, [], 'MEG');
    if ~isempty(iMeg)
        modality = 'MEG';
    else
        % Get the EEG modalities in this file
        [tmp, AllMod] = channel_get_modalities(ChannelMat.Channel);
        AllMod = intersect(AllMod, {'EEG','SEEG','ECOG','NIRS'});
        if ~isempty(AllMod)
            modality = AllMod{1};
        else
            modality = [];
        end
    end
    % Show the final registration
    if ~isempty(modality)
        channel_align_manual(ChannelFile, modality, 0);
    end
end
% Distance between fitted points and reference surface
if (isWarning || isConfirm)
    view_text(strReport, 'Sensors/anatomy registration');
end
disp(['BST> ' strReport]);
% Close progress bar
bst_progress('stop');


end



