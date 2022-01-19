function TessMat = in_tess_mesh(TessFile)
% IN_TESS_MESH: Import BrainVisa .mesh tessellation files.
%
% USAGE:  TessMat = in_tess_mesh(TessFile);
%
% INPUT: 
%     - TessFile : full path to a tesselation file
% OUTPUT:
%     - TessMat:  Brainstorm tesselation structure
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
% Authors: Francois Tadel, 2008

% Initialize returned value
TessMat = struct('Vertices', [], 'Faces', []);

%% ===== READ MESH FILE =====
% Open file
fid = fopen(TessFile, 'r');
if (fid < 0)
   error('Cannot open file'); 
end

% === READ HEADER ===
file_format = char(fread(fid, 5, '*uchar'))' ;
% Check format
if ~strcmpi(file_format, 'binar')
    fclose(fid);
    error('Cannot import MESH files that are not in "binar" format.');
end
% Big/little endian
lbindian = char(fread(fid, 4, '*uchar'))' ;
if strcmpi(lbindian, 'DCBA')
    byteOrder = 'l';
else
    byteOrder = 'b';
end
% Read end of header
arg_size        = fread(fid, 1, 'uint32', 0, byteOrder) ;
VOID            = fread(fid, arg_size, 'uchar', 0, byteOrder) ;
vertex_per_face = fread(fid, 1, 'uint32', 0, byteOrder) ;
mesh_time       = fread(fid, 1, 'uint32', 0, byteOrder) ;

% === READ DATA ===
% Read all the tesselations that are stored in the file
for ii = 1:mesh_time    
    mesh_step = fread(fid, 1, 'uint32', 0, byteOrder) ;
    % Vertices
    nb_vertex{ii} = fread(fid, 1, 'uint32', 0, byteOrder) ;     
    vertex{ii} = fread(fid, 3*nb_vertex{ii}, '*float32', 0, byteOrder) ;
    vertex{ii} = reshape(vertex{ii},3,nb_vertex{ii})'; % read in mm
    % Normals
    nb_normals = fread(fid, 1, 'uint32', 0, byteOrder) ;          
    normal{ii} = fread(fid, 3*nb_normals, '*float32', 0, byteOrder) ;
    normal{ii} = reshape(normal{ii}, 3, nb_normals)' ;
    % Texture
    nb_texture  = fread(fid, 1, 'uint32', 0, byteOrder) ;   % ALWAYS ZERO 
    % Faces
    faces_number{ii} = fread(fid, 1, 'uint32', 0, byteOrder) ;
    faces{ii} = fread(fid, vertex_per_face * faces_number{ii}, 'uint32', 0, byteOrder) ;
    faces{ii} = reshape(faces{ii}, vertex_per_face, faces_number{ii})' ; 
end

fclose(fid) ;


%% ===== CONVERT TO BRAINSTORM STRUCTURE =====
for iTess = 1:mesh_time
    TessMat(iTess).Vertices = double(vertex{iTess}) / 1000;
    TessMat(iTess).Faces    = double(faces{iTess}) + 1;
end




