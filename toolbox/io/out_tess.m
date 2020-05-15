function out_tess(BstFile, OutputFile, FileFormat, sMri)
% OUT_TESS: Exports a Brainstorm surface in another file format.
%
% USAGE:  out_tess(BstFile, OutputFile, FileFormat, sMri);
%
% INPUT: 
%     - BstFile    : Tesselation file from the Brainstorm database
%     - OutputFile : Full path to output filename
%     - FileFormat : String that describes the surface file format : {TRI, DFS, DSGL, MESH, BST ...}
%     - sMri       : Loaded MRI structure

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
% Authors: Francois Tadel, 2011-2016

% ===== PARSE INPUTS =====
if (nargin < 4)
    sMri = [];
end

% ===== LOAD SURFACE =====
% Load Brainstorm file
TessMat = in_tess_bst(BstFile);
% Convert back to MRI coordinates
if ~isempty(sMri)
    TessMat.Vertices = cs_convert(sMri, 'scs', 'mri', TessMat.Vertices);
else
    disp('BST> Warning: MRI is missing, cannot convert surface to Brainstorm coordinate system.');
end


% ===== SAVE SURFACE =====
[fPath, fBase, fExt] = bst_fileparts(OutputFile);
% Show progress bar
bst_progress('start', 'Export surface', ['Export surface to file "' [fBase, fExt] '"...']);
% Switch between file formats
switch upper(FileFormat)
    case 'DFS'
        % Remove a one voxel shift in all the directions to the surface (ADD FT: 10-May-2016)
        if ~isempty(sMri)
            TessMat.Vertices = bst_bsxfun(@minus, TessMat.Vertices, sMri.Voxsize / 1000);
        else
            TessMat.Vertices = bst_bsxfun(@minus, TessMat.Vertices, [1 1 1] / 1000);
        end
        % Export file
        out_tess_dfs(TessMat, OutputFile);
    case 'MESH'
        % Convert into BrainVISA MRI coordinates
        if ~isempty(sMri)
            mriSize = size(sMri.Cube(:,:,:,1)) .* sMri.Voxsize(:)' ./ 1000;
            TessMat.Vertices = bst_bsxfun(@minus, mriSize, TessMat.Vertices);
        end
        % Export file
        out_tess_mesh(TessMat, OutputFile);
    case 'GII'
        % Convert to BrainVISA MRI coordinates
        if ~isempty(sMri)
            mriSize = size(sMri.Cube(:,:,:,1)) .* sMri.Voxsize(:)' ./ 1000;
            TessMat.Vertices = bst_bsxfun(@minus, mriSize, TessMat.Vertices);
        end
        % Export file
        out_tess_gii(TessMat, OutputFile, 0);
    case 'FS'
        % Swap faces
        TessMat.Faces = TessMat.Faces(:,[2 1 3]);
        % MRI => FreeSurfer RAS coord
        if ~isempty(sMri)
            % TessMat.Vertices = bst_bsxfun(@minus, TessMat.Vertices, [128 129 128] / 1000);
            TessMat.Vertices = bst_bsxfun(@minus, TessMat.Vertices, (size(sMri.Cube(:,:,:,1))/2 + [0 1 0]) .* sMri.Voxsize / 1000);
        end
        % Export file
        out_tess_fs(TessMat, OutputFile);
    case 'OFF'
        out_tess_off(TessMat, OutputFile);
    case 'TRI'
        out_tess_tri(TessMat, OutputFile);
    otherwise
        error(['Unsupported file extension : "' OutputExt '"']);
end
% Hide progress bar
bst_progress('stop');



