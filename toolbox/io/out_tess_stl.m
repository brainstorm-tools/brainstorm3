function [nVertices, nFaces, BstMat] = out_tess_stl(BstFile, OutputFile, isAscii)
% OUT_TESS_STL: Exports a surface to a STL file.
%
% USAGE:  [nVertices, nFaces] = out_tess_tri( BstFile, OutputFile )
%         [nVertices, nFaces] = out_tess_tri( BstFile/TessMat, OutputFile, isAscii=0 )
%
% INPUT:
%    - BstFile    : full path to Brainstorm file to export
%    - OutputFile : full path to output file (with '.stl' extension)
%    - isAscii    : if flag set to 1, write ASCII STL file, binary STL otherwise (default = 0)
%
% REFERENCE:
%    - https://en.wikipedia.org/wiki/STL_(file_format)

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
% Author: Raymundo Cassani, 2025

if (nargin < 3) || isempty(isAscii)
    isAscii = 0;
end

% ===== LOAD BRAINSTORM SURFACE =====
if ischar(BstFile)
    BstMat = in_tess_bst(BstFile);
else
    BstMat = BstFile;
end

% ===== PREPARE VALUES ======
% Vertices (=> in millimeters)
Vertices = BstMat.Vertices * 1000;
% Faces
Faces = BstMat.Faces;
% Face normals
[~, FaceNormals] = tess_normals(Vertices, Faces, BstMat.VertConn);
% Return surface sizes
nVertices = length(BstMat.Vertices);
nFaces = length(BstMat.Faces);
% Name
if isfield(BstMat, 'Comment') && ~isempty(BstMat.Comment)
    if iscell(BstMat.Comment)
        Name = BstMat.Comment{1};
    else
        Name = BstMat.Comment;
    end
else
    Name = 'Surface';
end
Name = [Name ' exported with Brainstorm'];
Name = strrep(Name, ' ', '_');

% ===== SAVE STL FILE =====
if isAscii
    % Open file
    [fid, message] = fopen(OutputFile, 'w');
    if (fid < 0)
        error(['Could not create file : ' message]);
    end
    % Write header
    fprintf(fid, 'solid %s\n', Name);
    % Write faces and vertices
    for iFace = 1 : nFaces
        fprintf(fid, ' facet normal %g %g %g\n', FaceNormals(iFace, :));
        fprintf(fid, '  outer loop\n');
        for iVertex = 1 : length(Faces(iFace, :))
            fprintf(fid, '   vertex %g %g %g\n', Vertices(Faces(iFace, iVertex), :));
        end
        fprintf(fid, '  endloop\n');
        fprintf(fid, ' endfacet\n');
    end
    % Write footer
    fprintf(fid, 'endsolid %s\n', Name);
    % Close file
    fclose(fid);
else
    % Open file
    [fid, message] = fopen(OutputFile, 'w+', 'l');
    if (fid < 0)
        error(['Could not create file : ' message]);
    end
    % UINT8[80]      – Header              - 80 bytes
    % Pad the header to 80 characters
    Name = pad(Name, 80, 'right');
    Name = Name(1:80);
    fwrite(fid, Name, 'char');
    % UINT32         – Number of triangles - 04 bytes
    fwrite(fid, nFaces, 'int32');
    for iFace = 1 : nFaces
        %  REAL32[3] – Normal vector       - 12 bytes
        fwrite(fid, FaceNormals(iFace, :), 'float');
        %  REAL32[3] – Vertex 1            - 12 bytes
        %  REAL32[3] – Vertex 2            - 12 bytes
        %  REAL32[3] – Vertex 3            - 12 bytes
        for iVertex = 1 : length(Faces(iFace, :))
            fwrite(fid, Vertices(Faces(iFace, iVertex), :), 'float');
        end
        %  UINT16  – Attribute byte count  - 02 bytes
        fwrite(fid, 0, 'int16');
    end
    % Close file
    fclose(fid);
end

