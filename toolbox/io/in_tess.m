function TessMat = in_tess(TessFile, FileFormat, sMri, OffsetMri)
% IN_TESS: Detect file format and load tesselation file.
%
% USAGE:  TessMat = in_tess(TessFile, FileFormat='ALL', sMri=[], Offset=[]);
%
% INPUT: 
%     - TessFile   : full path to a tesselation file
%     - FileFormat : String that describes the surface file format : {TRI, DFS, DSGL, MESH, BST, ALL ...}
%     - sMri       : Loaded MRI structure
%     - OffsetMri  : (x,y,z) values to add to the coordinates of the surface before converting it to SCS
%
% OUTPUT:
%     - TessMat:  Brainstorm tesselation structure with fields:
%         |- Vertices : {[3 x nbVertices] double}, in millimeters
%         |- Faces    : {[nbFaces x 3] double}
%         |- Comment  : {information string}

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
% Authors: Francois Tadel, 2008-2019

%% ===== PARSE INPUTS =====
% Initialize returned variables
TessMat = [];
% Try to get the associate MRI filename (already imported in BST)
if (nargin < 4) || isempty(OffsetMri)
    OffsetMri = [];
end
if (nargin < 3)
    sMri = [];
end
if (nargin < 2) || isempty(FileFormat)
    FileFormat = 'ALL';
end
isConvertScs = 1;


%% ===== DETECT FILE FORMAT ====
% Get filename and extension (used as comments for some file formats)
[filePath, fileBase, fileExt] = bst_fileparts(TessFile);
% If format is not specified, try to identify the format based on its extension
if isempty(fileExt)
    if ~isempty(strfind(fileBase, '_surface'))
        FileFormat = 'FS';
    end
elseif strcmpi(FileFormat, 'ALL')
    switch(fileExt)
        case '.mesh'
            FileFormat = 'MESH';
        case '.dfs'
            FileFormat = 'DFS';
        case '.dsgl'
            FileFormat = 'DSGL';
        case {'.bd0','.bd1','.bd2','.bd3','.bd4','.bd5','.bd6','.bd7','.bd8','.bd9', '.s00','.s01','.s02','.s03','.s04','.s05','.s06','.s07','.s08','.s09'}
            FileFormat = 'CURRY-BEM';
        case '.vtk'
            FileFormat = 'VTK';
        case '.off'
            FileFormat = 'OFF';
        case '.gii'
            FileFormat = 'GII';
        case '.fif'
            FileFormat = 'FIF';
        case '.obj'
            FileFormat = 'MNIOBJ';
        case '.tri'
            FileFormat = 'TRI';
        case '.mat'
            FileFormat = 'BST';
        case '.nwb'
            FileFormat = 'NWB';
        case {'.pial', '.white', '.inflated', '.nofix', '.orig', '.smoothwm', '.sphere', '.reg', '.surf'}
            FileFormat = 'FS';
    end
end
% If format was not detected
if strcmpi(FileFormat, 'ALL')
    bst_error(['File format could not be detected automatically.' 10 'Please try again with a specific file format.'], 'Import surface', 0);
    return;
end


%% ===== READ SURFACE =====
% Switch between different import functions 
switch (FileFormat)
    case 'BST'
        TessMat = in_tess_bst(TessFile);
        isConvertScs = 0;
    case 'DFS'
        TessMat = in_tess_dfs(TessFile);
        % Add a one voxel shift in all the directions to the surface (ADD FT: 12-Jan-2016)
        if ~isempty(sMri)
            TessMat.Vertices = bst_bsxfun(@plus, TessMat.Vertices, sMri.Voxsize / 1000);
        else
            TessMat.Vertices = bst_bsxfun(@plus, TessMat.Vertices, [1 1 1] / 1000);
        end
    case 'MESH'
        TessMat = in_tess_mesh(TessFile);
        % Convert into local MRI coordinates
        if ~isempty(sMri)
            mriSize = size(sMri.Cube) .* sMri.Voxsize(:)' ./ 1000;
            TessMat.Vertices = bst_bsxfun(@minus, mriSize, TessMat.Vertices);
        end
    case 'GII'
        TessMat = in_tess_gii(TessFile);
        % Convert into local MRI coordinates
        if ~isempty(sMri)
            mriSize = size(sMri.Cube) .* (sMri.Voxsize(:))' ./ 1000;
            for iTess = 1:length(TessMat)
                TessMat(iTess).Vertices = bst_bsxfun(@minus, mriSize, TessMat(iTess).Vertices);
            end
        else
            % Swap faces
            for iTess = 1:length(TessMat)
                TessMat(iTess).Faces = TessMat(iTess).Faces(:,[2 1 3]);
            end
        end
    case 'GII-MNI'
        TessMat = in_tess_gii(TessFile);
        % Process all the surfaces
        for iTess = 1:length(TessMat)
            % Convert from MNI to MRI coordinates
            if ~isempty(sMri)
                TessMat(iTess).Vertices = cs_convert(sMri, 'mni', 'mri', TessMat(iTess).Vertices);
                if isempty(TessMat(iTess).Vertices)
                    error('You must compute the MNI transformation for the MRI first.');
                end
            end
            % Swap faces
            TessMat(iTess).Faces = TessMat(iTess).Faces(:,[2 1 3]);
        end
    case 'GII-WORLD'
        TessMat = in_tess_gii(TessFile);
        % Process all the surfaces
        for iTess = 1:length(TessMat)
            % Convert from MNI to MRI coordinates
            if ~isempty(sMri)
                TessMat(iTess).Vertices = cs_convert(sMri, 'world', 'mri', TessMat(iTess).Vertices);
                if isempty(TessMat(iTess).Vertices)
                    error('You must compute the MNI transformation for the MRI first.');
                end
            end
            % Swap faces
            TessMat(iTess).Faces = TessMat(iTess).Faces(:,[2 1 3]);
        end
    case 'FS'
        % Read file with MNE function
        [TessMat.Vertices, TessMat.Faces] = mne_read_surface(TessFile);
        % FreeSurfer RAS coord => MRI  (NEW VERSION: 12-Jan-2016 / relative size: 28-Aug-2017)
        if ~isempty(sMri)
            TessMat.Vertices = bst_bsxfun(@plus, TessMat.Vertices, (size(sMri.Cube)/2 + [0 1 0]) .* sMri.Voxsize / 1000);
        else
            TessMat.Vertices = bst_bsxfun(@plus, TessMat.Vertices, [128 129 128] / 1000);
        end
        % Swap faces
        TessMat.Faces = TessMat.Faces(:,[2 1 3]);
    case 'OFF'
        TessMat = in_tess_off(TessFile);
    case 'TRI'
        TessMat = in_tess_tri(TessFile);
    case 'DSGL'
        TessMat = in_tess_dsgl(TessFile);
    case 'FIF'
        TessMat = in_tess_fif(TessFile);
    case 'VTK'
        TessMat = in_tess_vtk(TessFile);
        
    case 'CURRY-BEM'
        TessMat = in_tess_curry(TessFile);
        TessMat.Vertices = TessMat.Vertices / 1000;

    case 'MNIOBJ'
        TessMat = in_tess_mniobj(TessFile);
        % MNI MRI coord => MRI
        if ~isempty(sMri) && isfield(sMri, 'Header') && isfield(sMri.Header, 'info') && isfield(sMri.Header.info, 'mat') && ~isempty(sMri.Header.info.mat)
            % Check if rotation is the identity
            if ~isequal(sMri.Header.info.mat(1:3,1:3) / sMri.Header.info.mat(1,1), eye(3))
                disp('MINC> Warning: cosine matrix is different from identity. Not supported yet...');
            end
            % Apply translation
            T = sMri.Header.info.mat(1:3,4)' - 1;
            TessMat.Vertices = bst_bsxfun(@minus, TessMat.Vertices, T / 1000);            
        end
        
    case 'MRI-MASK'
        TessMat = in_tess_mrimask(TessFile, 0);
        
    case 'MRI-MASK-MNI'
        TessMat = in_tess_mrimask(TessFile, 1);
        % Convert from MNI coordinates back to SCS
        if ~isempty(sMri) && isfield(sMri, 'SCS') && isfield(sMri.SCS, 'NAS') && ~isempty(sMri.SCS.NAS)
            for iTess = 1:length(TessMat)
                TessMat(iTess).Vertices = cs_convert(sMri, 'mni', 'scs', TessMat(iTess).Vertices);
            end
        end
        isConvertScs = 0;
        
    case 'NWB'
        TessMat = in_tess_nwb(TessFile);
end
% If an error occurred: return
if isempty(TessMat)
    return;
end
% Fix the tesselations
for iTess = 1:length(TessMat)
    % Make sure all the values are double
    TessMat(iTess).Vertices = double(TessMat(iTess).Vertices);
    TessMat(iTess).Faces = double(TessMat(iTess).Faces);
    % Fix the matrix orientations
    if (size(TessMat(iTess).Vertices,1) == 3) && (size(TessMat(iTess).Vertices,2) ~= 3) 
        TessMat(iTess).Vertices = TessMat(iTess).Vertices';
    end
    if (size(TessMat(iTess).Faces,1) == 3) && (size(TessMat(iTess).Faces,2) ~= 3) 
        TessMat(iTess).Faces = TessMat(iTess).Faces';
    end
    % Add coordinates offset
    if ~isempty(OffsetMri) && ~isempty(sMri)
        TessMat(iTess).Vertices = bst_bsxfun(@plus, TessMat(iTess).Vertices, OffsetMri .* sMri.Voxsize ./ 1000 );
    end
end

        
%% ===== CONVERSION MRI TO SCS =====
if isConvertScs
    if ~isempty(sMri) && isfield(sMri, 'SCS') && isfield(sMri.SCS, 'NAS') && ~isempty(sMri.SCS.NAS)
        for iTess = 1:length(TessMat)
            TessMat(iTess).Vertices = cs_convert(sMri, 'mri', 'scs', TessMat(iTess).Vertices);
        end
    else
        disp(['IN_TESS> Warning: MRI is missing, or fiducials are not defined.' 10 ...
              'IN_TESS> Cannot convert surface to Brainstorm coordinate system.']);
    end
end

%% ===== COMMENT =====
% Add a comment field to the TessMat structure.
% If various tesselations were loaded from one file
if (length(TessMat) > 1)
    for iTess = 1:length(TessMat)
        if ~isfield(TessMat(iTess), 'Comment') || isempty(TessMat(iTess).Comment)
            TessMat(iTess).Comment = sprintf('%s#%d', fileBase, iTess);
        end
    end
elseif (length(TessMat) == 1)
    % If comment is not defined from the file
    if ~isfield(TessMat, 'Comment') || isempty(TessMat.Comment)
        % Surface comment
        switch(FileFormat)
            case 'FS'
                % FreeSurfer: we need to keep the extension
                TessMat.Comment = [fileBase fileExt];
            otherwise
                % Other formats: use the base filename (without extension)
                TessMat.Comment = fileBase;
        end
    end
end


