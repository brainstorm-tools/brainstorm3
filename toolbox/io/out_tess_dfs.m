function out_tess_dfs( TessMat, OutputFile )
% OUT_TESS_DFS: Exports a surface to a BrainSuite .dfs file.
% 
% USAGE:  out_tess_dfs( TessMat, OutputFile )
%
% INPUT: 
%    - TessMat    : Brainstorm tesselation matrix
%    - OutputFile : full path to output file (with '.dfs' extension)

% FILE FORMAT:
%	char  hdrversion[12];   // "DFS_LE v1.0\0" on little-endian machines or "DFS_BE v1.0\0" on big-endian machines
%	int32 hdrsize;          // Size of complete header (i.e., offset of first data element)
%	int32 mdoffset;         // Start of metadata.
%	int32 pdoffset;         // Start of patient data header.
%	int32 nTriangles;		// Number of triangles
%	int32	nVertices;		// Number of vertices
%	int32 nStrips;			// Number of triangle strips
%	int32 stripSize;		// size of strip data
%	int32 normals;			// 4	Int32	<normals>	Start of vertex normal data (0 if not in file)
%	int32 uvStart;			// Start of surface parameterization data (0 if not in file)
%	int32 vcoffset;			// vertex color
%	uint8 precision;		// Vertex Precision -- usually float32 or float64
%	uint8	pad[3];				// padding
%	float64 orientation[4][4]; //4x4 matrix, affine transformation to world coordinates

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
% Authors: David Shattuck (shattuck@loni.ucla.edu)
%          Francois Tadel, 2009-2016

% ===== CONVERT TO BRAINSUITE FORMAT =====
TessMat.Vertices = TessMat.Vertices' * 1000;
TessMat.Faces    = TessMat.Faces' - 1; 


% ===== SAVE FILE =====
% Open file for binary writing
[fid, message] = fopen(OutputFile, 'wb', 'ieee-le');
if (fid < 0)
    error(['Could not create file : ' message]);
end

% Define header
magic = ['DFS_LE v1.0' 0];
hdrsize = 184;
mdoffset = 0;			% Start of metadata.
pdoffset = 0;          % Start of patient data header.
nTriangles = length(TessMat.Faces(:))/3;
nVertices  = length(TessMat.Vertices(:))/3;
nStrips = 0;
stripSize = 0;
normals = 0;
uvStart = 0;
vcoffset = 0;
precision = 0; 
pad=[0 0 0];
orientation=eye(4);

% Write header
fwrite(fid,magic,'char');
fwrite(fid,hdrsize,'int32');
fwrite(fid,mdoffset,'int32');
fwrite(fid,pdoffset,'int32');
fwrite(fid,nTriangles,'int32');
fwrite(fid,nVertices,'int32');
fwrite(fid,nStrips,'int32');
fwrite(fid,stripSize,'int32');
fwrite(fid,normals,'int32');
fwrite(fid,uvStart,'int32');
fwrite(fid,vcoffset,'int32');
fwrite(fid,precision,'int32');
fwrite(fid,orientation,'float64');
% Write faces
fwrite(fid,TessMat.Faces,'int32');
fwrite(fid,TessMat.Vertices,'float32');
fclose(fid);


