function [TessMat,NFV] = in_tess_dfs(TessFile)
% IN_TESS_DFS: Read a BrainSuite tesselation file
%
% USAGE:  [TessMat,NFV] = in_tess_bst(TessFile);
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
% Authors: David Shattuck
%          Francois Tadel, 2008-2015

% Initialize returned value
TessMat = struct('Vertices', [], 'Faces', []);


%% ===== READ DFS FILE =====
% Open file
fid = fopen(TessFile, 'rb', 'ieee-le');
if (fid < 0) 
    error('Cannot open file'); 
end

% HEADER DESCRIPTION:
% char hdrversion[12];  // "DFS_LE v1.0\0" on little-endian machines or "DFS_BE v1.0\0" on big-endian machines
% int32 hdrsize;		// Size of complete header (i.e., offset of first data element)
% int32 mdoffset;		// Start of metadata.
% int32 pdoffset;		// Start of patient data header.
% int32 nTriangles;		// Number of triangles
% int32 nVertices;		// Number of vertices
% int32 nStrips;		// Number of triangle strips
% int32 stripSize;		// size of strip data
% int32 normals;		// 4	Int32	<normals>	Start of vertex normal data (0 if not in file)
% int32 uvStart;		// Start of surface parameterization data (0 if not in file)
% int32 vcoffset;		// vertex color
% uint8 precision;		// Vertex Precision -- usually float32 or float64
% uint8 pad[3];			// padding
% float64 orientation[4][4]; //4x4 matrix, affine transformation to world coordinates

% Read header
hdr.hdrversion  = fread(fid, 12, '*char');
hdr.hdrsize     = fread(fid, 1, 'int32');
hdr.mdoffset    = fread(fid, 1, 'int32');
hdr.pdoffset    = fread(fid, 1, 'int32');
hdr.nTriangles  = fread(fid, 1, 'int32');
hdr.nVertices   = fread(fid, 1, 'int32');
hdr.nStrips     = fread(fid, 1, 'int32');
hdr.stripSize   = fread(fid, 1, 'int32');
hdr.normals     = fread(fid, 1, 'int32');
hdr.uvStart     = fread(fid, 1, 'int32');
hdr.vcoffset    = fread(fid, 1, 'int32');
hdr.labelOffset = fread(fid, 1, 'int32');
hdr.vertexAttributes = fread(fid, 1, 'int32');

% Go to the end of the header
fseek(fid, double(hdr.hdrsize), -1);
% Read tesselation structure
NFV.faces    = fread(fid, [3 hdr.nTriangles], 'int32');
NFV.vertices = fread(fid, [3 hdr.nVertices],  '*float32');

% Read additional fields
if (nargout > 1)
    % Read normals
    if (hdr.normals > 0)  
        fseek(fid, double(hdr.normals), -1);
        NFV.normals = fread(fid,[3 hdr.nVertices],'*float32')';
    end
    % Read color
    if (hdr.vcoffset > 0)  
        fseek(fid, double(hdr.vcoffset), -1);
        NFV.vcolor = fread(fid, [3 hdr.nVertices], 'float32')';
    end
    % Read U,V
    if (hdr.uvStart > 0)
        fseek(fid, double(hdr.uvStart), -1);
        uv = fread(fid,[2 hdr.nVertices],'*float32');
        NFV.u = uv(1,:);
        NFV.v = uv(2,:);
    end
    % Read vertex labels
    if (hdr.labelOffset > 0)
        fseek(fid,hdr.labelOffset,-1);
        NFV.labels = fread(fid,[hdr.nVertices],'uint16');
    end
    if (hdr.vertexAttributes > 0)
        fseek(fid,hdr.vertexAttributes,-1);
        NFV.attributes = fread(fid,[hdr.nVertices],'float32');
    end
end
% Close file
fclose(fid);


%% ===== CONVERT IN BRAINSTORM FORMAT =====
TessMat.Vertices = double(NFV.vertices') / 1000;
TessMat.Faces    = double(NFV.faces') + 1; 








