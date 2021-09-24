function FibMat = in_fibers(FibersFile, FileFormat, N, sMri, OffsetMri)
% IN_FIBERS: Detect file format and load fibers file.
%
% USAGE:  FibMat = in_fibers(FibersFile, FileFormat='ALL', sMri=[], Offset=[]);
%
% INPUT: 
%     - FibersFile : full path to a fibers file
%     - FileFormat : String that describes the fibers file format : {TRK, BST, ...}
%     - N          : Number of points per fiber
%     - sMri       : Loaded MRI structure
%     - OffsetMri  : (x,y,z) values to add to the coordinates of the fibers before converting it to SCS
%
% OUTPUT:
%     - FibMat:  Brainstorm fibers structure with fields:
%         |- Points : {[3 x nbFibers] double}, in millimeters
%         |- Comment  : {information string}

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
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
% Authors: Martin Cousineau, 2019

%% ===== PARSE INPUTS =====
% Initialize returned variables
FibMat = [];
% Try to get the associate MRI filename (already imported in BST)
if (nargin < 5) || isempty(OffsetMri)
    OffsetMri = [];
end
if (nargin < 4)
    sMri = [];
end
if (nargin < 3) || isempty(N)
    N = [];
end
if (nargin < 2) || isempty(FileFormat)
    FileFormat = [];
end
isConvertScs = 1;


%% ===== DETECT FILE FORMAT ====
% Get filename and extension (used as comments for some file formats)
[filePath, fileBase, fileExt] = bst_fileparts(FibersFile);
% If format is not specified, try to identify the format based on its extension
if ~isempty(fileExt) && (isempty(FileFormat) || strcmpi(FileFormat, 'ALL'))
    switch(fileExt)
        case '.trk'
            FileFormat = 'TRK';
        case '.mat'
            FileFormat = 'BST';
    end
end
% If format was not detected
if isempty(FileFormat) || strcmpi(FileFormat, 'ALL')
    bst_error(['File format could not be detected automatically.' 10 'Please try again with a specific file format.'], 'Import fibers', 0);
    return;
end


%% ===== READ FIBERS =====
% Switch between different import functions 
switch (FileFormat)
    case 'BST'
        FibMat = load(file_fullpath(FibersFile));
        isConvertScs = 0;
        if ~isempty(N) && (N ~= size(FibMat.Points, 2))
            error('Cannot interpolate the number of coordinates from an already imported fibers file.');
        end
    case 'TRK'
        % Read using external function
        bst_progress('text', 'Reading TRK...');
        [header, tracks] = trk_read(FibersFile);
        % Convert to N points
        if ~isempty(N)
            bst_progress('text', ['Interpolating fibers to ' num2str(N) ' points...']);
            tracks = trk_interp(tracks, N);
        end
        % Convert to meters
        tracks = tracks / 1000;
        % Build Brainstorm structure
        FibMat = db_template('fibersmat');
        FibMat.Points = permute(tracks, [3,1,2]);
        FibMat.Header = header;
        FibMat = fibers_helper('ComputeColor', FibMat);
end
% If an error occurred: return
if isempty(FibMat)
    return;
end
% Fix the fibers
for iFib = 1:length(FibMat)
    % Make sure all the values are double
    FibMat(iFib).Points = double(FibMat(iFib).Points);
    % Fix the matrix orientations
    if (size(FibMat(iFib).Points,3) ~= 3) || (~isempty(N) && size(FibMat(iFib).Points,2) ~= N)
        error('Please permute the Points matrix to nbFibers x nbPoints x 3');
    end
    % Add coordinates offset
    if ~isempty(OffsetMri) && ~isempty(sMri)
        % Convert to 2D matrix to do it in one go
        [pts2D, shape3D] = fibers_helper('Conv3Dto2D', FibMat(iFib).Points);
        pts2D = bst_bsxfun(@plus, pts2D, OffsetMri .* sMri.Voxsize ./ 1000);
        FibMat(iFib).Points = fibers_helper('Conv2Dto3D', pts2D, shape3D);
    end
end
        
%% ===== CONVERSION MRI TO SCS =====
if isConvertScs
    if ~isempty(sMri) && isfield(sMri, 'SCS') && isfield(sMri.SCS, 'NAS') && ~isempty(sMri.SCS.NAS)
        bst_progress('start', 'Importing fibers' , 'Converting coordinates to SCS...', 0, length(FibMat));
        for iFib = 1:length(FibMat)
            % Convert to 2D matrix to do it in one go using cs_convert()
            [pts2D, shape3D] = fibers_helper('Conv3Dto2D', FibMat(iFib).Points);
            pts2D = cs_convert(sMri, 'mri', 'scs', pts2D);
            FibMat(iFib).Points = fibers_helper('Conv2Dto3D', pts2D, shape3D);
            bst_progress('inc', 1);
        end
    else
        disp(['IN_FIBERS> Warning: MRI is missing, or fiducials are not defined.' 10 ...
              'IN_FIBERS> Cannot convert fibers to Brainstorm coordinate system.']);
    end
end

%% ===== COMMENT =====
% Set number of loaded fibers as comment
for iFib = 1:length(FibMat)
    % If comment is not defined from the file
    if ~isfield(FibMat(iFib), 'Comment') || isempty(FibMat(iFib).Comment)
        FibMat(iFib).Comment = sprintf('fibers_%dPt_%dFib', N, size(FibMat(iFib).Points, 1));
    end
end
