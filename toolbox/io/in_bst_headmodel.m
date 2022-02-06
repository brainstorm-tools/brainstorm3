function HeadModel = in_bst_headmodel(HeadModelFile, ApplyOrient, varargin)
% IN_BST_HEADMODEL: Read a headmodel file in Brainstorm format.
% 
% USAGE:  HeadModel = in_bst_headmodel(HeadModelFile, ApplyOrient, FieldsList) : Read the specified fields
%         HeadModel = in_bst_headmodel(HeadModelFile, ApplyOrient)             : Read all the fields
%         HeadModel = in_bst_headmodel(HeadModelFile)                          : Read all the fields and do NOT constrain orientations
% 
% INPUT:
%    - HeadModelFile : Absolute or relative path to the headmodel file to read
%    - ApplyOrient   : If 1, return the Gain matrix for a constrained orientation (orientations from GridOrient field)
%    - FieldsList    : List of fields to read from headmodel file

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
% Authors: Francois Tadel, 2009-2016

%% ===== PARSE INPUTS =====
if (nargin < 2) || isempty(ApplyOrient)
    ApplyOrient = 0;
end
% Get protocol folders
ProtocolInfo = bst_get('ProtocolInfo');
% Filename: Relative / absolute
if ~file_exist(HeadModelFile)
    HeadModelFile = bst_fullfile(ProtocolInfo.STUDIES, HeadModelFile);
    if ~file_exist(HeadModelFile)
        error('Head model file not found.');
    end
end
% Specfied fields
if (nargin < 3)
    % Read all fields
    HeadModel = load(HeadModelFile);
else
    % Get fields to read
    FieldsToRead = varargin;
    % If Gain is required, and ApplyOrient is set to 1, we need also the GridOrient field
    if ismember('Gain', FieldsToRead) && ~ismember('GridOrient', FieldsToRead) && ApplyOrient
        FieldsToRead{end + 1} = 'GridOrient';
    end
    % If SurfaceFile required, also add GridLoc
    if ismember('SurfaceFile', FieldsToRead) && ~ismember('GridLoc', FieldsToRead)
        FieldsToRead{end + 1} = 'GridLoc';
    end
    if ismember('GridLoc', FieldsToRead) && ~ismember('SurfaceFile', FieldsToRead)
        FieldsToRead{end + 1} = 'SurfaceFile';
    end
    % If Comment required, also add HeadModelName
    if ismember('Comment', FieldsToRead) && ~ismember('HeadModelName', FieldsToRead)
        FieldsToRead{end + 1} = 'HeadModelName';
    end
    % Read specified files only
    warning off MATLAB:load:variableNotFound
    HeadModel = load(HeadModelFile, FieldsToRead{:});
    warning on MATLAB:load:variableNotFound
end

%% ===== REMOVE CELLS =====
% In previous verisons of Brainstorm, the values were contained in cell lists
% If some values are enclosed in cells, extract them from the cells
fieldsToProcess = {'Gain', 'GridLoc', 'GridOrient'};
% Loop over all fields
for i = 1:length(fieldsToProcess)
    if isfield(HeadModel, fieldsToProcess{i}) && iscell(HeadModel.(fieldsToProcess{i}))
        HeadModel.(fieldsToProcess{i}) = HeadModel.(fieldsToProcess{i}){1};
    end
end

%% ===== READ SOURCE LOCATIONS =====
SurfaceMat = [];
% If GridLoc is a filename
if isfield(HeadModel, 'GridLoc') && ischar(HeadModel.GridLoc)
    SurfaceFile = HeadModel.GridLoc;
    % Load surface file
    SurfaceMat = in_tess_bst(SurfaceFile, 1);
    HeadModel.GridLoc    = SurfaceMat.Vertices;
    HeadModel.SurfaceFile = SurfaceFile;
elseif ~isfield(HeadModel, 'SurfaceFile')
    HeadModel.SurfaceFile = '';
end
    
% Clean surface filename
if isfield(HeadModel, 'SurfaceFile') && ~isempty(HeadModel.SurfaceFile)
    HeadModel.SurfaceFile = file_short(HeadModel.SurfaceFile);
end


%% ===== READ SOURCE ORIENTATIONS =====
% If GridOrient is empty
if isfield(HeadModel, 'GridOrient') && isempty(HeadModel.GridOrient) && ~isempty(HeadModel.SurfaceFile)
    if isempty(SurfaceMat)
        SurfaceMat = in_tess_bst(HeadModel.SurfaceFile);
    end
    HeadModel.GridOrient = SurfaceMat.VertNormals;
end


%% ===== READ GAIN MATRIX =====
if isfield(HeadModel, 'Gain') 
    if ischar(HeadModel.Gain)
        % Get the proper gain covariance matrix
        gainfile = bst_fullfile(bst_fileparts(HeadModelFile), HeadModel.Gain);
        % If the 3 orientations are required, read the _xyz file
        if ~ApplyOrient
            gainfile = strrep(gainfile, '.bin', '_xyz.bin');
        end
        % Read full gain matrix
        HeadModel.Gain = old_read_gain(gainfile);
    else
        HeadModel.Gain = double(HeadModel.Gain);
    end

    % === APPLY ORIENTATIONS ====
    % If the gain matrix has 3 orientations per source, we need to apply the orientation
    if ApplyOrient && (size(HeadModel.Gain,2) == 3 * length(HeadModel.GridOrient))
        % Apply the fixed orientation to the Gain matrix (normal to the cortex)
        HeadModel.Gain = bst_gain_orient(HeadModel.Gain, HeadModel.GridOrient);
    end
end

%% ===== READ COMMENT =====
if isfield(HeadModel, 'HeadModelName') && ~isfield(HeadModel, 'Comment')
    HeadModel.Comment = HeadModel.HeadModelName;
end

%% ===== READ HEAD MODEL TYPE =====
if isfield(HeadModel, 'HeadModelType')
    if ~ismember(HeadModel.HeadModelType, {'surface', 'volume', 'mixed'})
        HeadModel.HeadModelType = 'surface';
    end
end

%% ===== GRID LOC =====
if isfield(HeadModel, 'GridLoc') && ~isempty(HeadModel.GridLoc)
    % Check matrix orientation
    if (size(HeadModel.GridLoc,2) ~= 3)
        HeadModel.GridLoc = HeadModel.GridLoc';
    end
end

%% ===== GRID LOC =====
if isfield(HeadModel, 'GridOrient') && ~isempty(HeadModel.GridOrient)
    % Check matrix orientation
    if (size(HeadModel.GridOrient,2) ~= 3)
        HeadModel.GridOrient = HeadModel.GridOrient';
    end
end

%% ===== ADD MISSING FIELDS =====
if (nargin >= 3)
    for i = 1:length(FieldsToRead)
        if ~isfield(HeadModel, FieldsToRead{i})
            HeadModel.(FieldsToRead{i}) = [];
        end
    end
end
