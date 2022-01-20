function out_tess_mesh( TessMat, OutputFile )
% OUT_TESS_MESH: Exports a surface to a BrainVISA .mesh file.
% 
% USAGE:  out_tess_mesh( TessMat, OutputFile )
%
% INPUT: 
%    - TessMat    : Brainstorm tesselation matrix
%    - OutputFile : full path to output file (with '.mesh' extension)

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
% Authors: Francois Tadel, 2008-2011

% ===== PARSE INPUTS =====
% Little Endian / Big Endian
machineFormat = bst_get('ByteOrder'); 
%machineFormat = 'b';
if ~strcmpi(machineFormat, 'l')
    byteOrderStr = 'ABCD';
else
    byteOrderStr = 'DCBA';
end

% ===== CONVERT TO BRAIVISA FORMAT ======
Vertices = TessMat.Vertices .* 1000;
Faces    = TessMat.Faces - 1;


%% ===== SAVE FILE =====
% Open file for binary writing
[fid, message] = fopen(OutputFile, 'wb', machineFormat);
if (fid < 0)
    error(['Could not create file : ' message]);
end

% Header values
fwrite(fid, 'binar',      'uchar') ;      % file_format
fwrite(fid, byteOrderStr, 'uchar') ;      % lbindian
fwrite(fid, 4,            'uint32') ;     % arg_size
fwrite(fid, 'VOID',       'uchar') ;      % VOID
fwrite(fid, 3,            'uint32') ;     % vertex_per_face
fwrite(fid, 1,            'uint32') ;     % mesh_time

% === Surface mesh ===
% Mesh indice
fwrite(fid, 0, 'uint32') ;   
% Vertices
fwrite(fid, length(Vertices), 'uint32') ;  % vertex_number
fwrite(fid, Vertices', 'float32') ; % vertex
% Normals
fwrite(fid, 0, 'uint32') ;  % arg_size
% Texture
fwrite(fid, 0, 'uint32') ;  % arg_size
% Faces
fwrite(fid, length(Faces), 'uint32') ;  % faces_number
fwrite(fid, Faces', 'uint32') ;  % faces


fclose(fid);



