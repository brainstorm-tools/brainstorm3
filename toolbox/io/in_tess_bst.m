function [TessMat, TessFile] = in_tess_bst( TessFile, isComputeMissing )
% IN_TESS_BST: Load a Brainstorm surface file, and compute missing fields.
%
% USAGE:  TessMat = in_tess_bst(TessFile, isComputeMissing);
%         TessMat = in_tess_bst(TessFile);      % isComputeMissing = 1
%
% INPUT: 
%     - TessFile : full path or relative to a tesselation file
%     - isComputeMissing : 1, compute the missing fields in the file
%                          0, just return the contents of the file
% OUTPUT:
%     - TessMat  : Brainstorm tesselation structure
%     - TessFile : Full path to the tesselation file
%
% SEE ALSO: in_tess

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
% Authors: Francois Tadel, 2008-2013

if (nargin < 2) || isempty(isComputeMissing)
    isComputeMissing = 1; 
end
    
% ===== LOAD FILE =====
% Filename: Relative to absolute
TessFile = file_fullpath(TessFile);
if ~file_exist(TessFile)
    error(['Surface file not found:' 10 file_short(TessFile) 10 'You should reload this protocol (right-click > reload).']);
end
% Load file
TessMat = load(TessFile);

% ===== REFORMAT =====
% Convert older structures to new formats:
% - Remove cells: Old Brainstorm surface files contained more than one tesselation, now one tesselation = file
% - Check matrix orientations
% - Convert to double
% - Add Color field
UpdateFile = 0;
if isfield(TessMat, 'Faces')
    TessMat.Faces = double(TessMat.Faces);
    if iscell(TessMat.Faces)
        TessMat.Faces = TessMat.Faces{1};
        UpdateFile = 1;
    end
    if (size(TessMat.Faces,1) == 3) && (size(TessMat.Faces,2) ~= 3)
        TessMat.Faces = TessMat.Faces';
        UpdateFile = 1;
    end
end
if isfield(TessMat, 'Vertices')
    TessMat.Vertices = double(TessMat.Vertices);
    if iscell(TessMat.Vertices)
        TessMat.Vertices = TessMat.Vertices{1};
        UpdateFile = 1;
    end
    if (size(TessMat.Vertices,1) == 3) && (size(TessMat.Vertices,2) ~= 3)
        TessMat.Vertices = TessMat.Vertices';
        UpdateFile = 1;
    end
end
if isfield(TessMat, 'Comment') && iscell(TessMat.Comment)
    TessMat.Comment = TessMat.Comment{1};
    UpdateFile = 1;
end
if isfield(TessMat, 'VertConn') && iscell(TessMat.VertConn)
    TessMat.VertConn = TessMat.VertConn{1};
    UpdateFile = 1;
end
if isfield(TessMat, 'Curvature') && iscell(TessMat.Curvature)
    TessMat.Curvature = TessMat.Curvature{1};
    UpdateFile = 1;
end
if ~isfield(TessMat, 'Color')
    TessMat.Color = [];
    UpdateFile = 1;
end


% ===== ATLASES =====
if isfield(TessMat, 'Atlas') && ~isempty(TessMat.Atlas)
    if ~isfield(TessMat, 'iAtlas') || isempty(TessMat.iAtlas) || (TessMat.iAtlas > length(TessMat.Atlas))
        TessMat.iAtlas = 1;
        UpdateFile = 1;
    end
elseif isfield(TessMat, 'Scout') && ~isempty(TessMat.Scout)
    TessMat.Atlas = db_template('Atlas');
    TessMat.Atlas(2).Scouts = 'Loaded atlas';
    TessMat.Atlas(2).Scouts = TessMat.Scout;
    % Add the Region field
    for i = 1:length(TessMat.Atlas(2).Scouts)
        TessMat.Atlas(2).Scouts(i).Region = 'UU';
    end
    % Remove existing list of scouts
    TessMat = rmfield(TessMat, 'Scout');
    % Default atlas: the loaded regions
    TessMat.iAtlas = 2;
    UpdateFile = 1;
else
    TessMat.Atlas = db_template('Atlas');
    TessMat.iAtlas = 1;
    UpdateFile = 1;
end
if isfield(TessMat, 'Scout')
    TessMat = rmfield(TessMat, 'Scout');
    UpdateFile = 1;
end

% ===== VERTEX CONNECTIVITY =====
% If vertex connectivity field is not available for this surface: Compute it
if isComputeMissing && isfield(TessMat, 'Vertices') && (~isfield(TessMat, 'VertConn') || isempty(TessMat.VertConn) || ~issparse(TessMat.VertConn))
    TessMat.VertConn = tess_vertconn(TessMat.Vertices, TessMat.Faces);
    UpdateFile = 1;
end

% ===== VERTEX NORMALS =====
% If VertexNormal field is not available for this surface: Compute it
if isComputeMissing && isfield(TessMat, 'Vertices') && (~isfield(TessMat, 'VertNormals') || isempty(TessMat.VertNormals) || ((size(TessMat.VertNormals,1) == 3) && (size(TessMat.VertNormals,2) ~= 3)))
    TessMat.VertNormals = tess_normals(TessMat.Vertices, TessMat.Faces, TessMat.VertConn);
    UpdateFile = 1;
end

% ===== CURVATURE =====
% If Curvature field is not available for this surface: Compute it
if isComputeMissing && isfield(TessMat, 'Vertices') && (~isfield(TessMat, 'Curvature') || isempty(TessMat.Curvature) || (size(TessMat.Curvature,2) > 1))
    TessMat.Curvature = single(tess_curvature(TessMat.Vertices, TessMat.VertConn, TessMat.VertNormals, .1));
    UpdateFile = 1;
end
              
% ===== SULCI MAP =====
% If Curvature field is not available for this surface: Compute it
if isComputeMissing && isfield(TessMat, 'Vertices') && (~isfield(TessMat, 'SulciMap') || isempty(TessMat.SulciMap) || (size(TessMat.SulciMap,2) > 1))
    TessMat.SulciMap = tess_sulcimap(TessMat);
    UpdateFile = 1;
end

% If need to update file
if UpdateFile
    try
        bst_save(TessFile, TessMat, 'v7');
    catch
        disp(['BST> Warning: File is read-only: "' TessFile '"']);
    end
end



                
                
                
                