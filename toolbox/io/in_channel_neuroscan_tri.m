function ChannelMat = in_channel_neuroscan_tri(ChannelFile)
% IN_CHANNEL_NEUROSCAN_TRI: Read a electrodes positions from a Neuroscan .TRI tesselation file.
% 
% USAGE:  ChannelMat = in_channel_neuroscan_tri(ChannelFile)
%
% INPUT: 
%    - ChannelFile : Full path to the file to open
% OUTPUT:
%    - ChannelMat  : Brainstorm channel structure

% NOTE: The function was base on a function from the Bioelectomagnetic toolbox: elec_load_scan_tri
%
% FILE FORMAT: Binary file composed with a header followed by a data block.
%    - HEADER{
%           long  id;                  // 100003, or 100004. (or 100002)
%           short filetype;            // =2 for triangle file
%           short revision;
%           float electrodethickness;
%           float electrodediameter;
%           BYTE  reserved[4080];
%           short nFaces;              // Number of faces
%           short nVertices;           // Number of vertices
%      }
%    - DATA{
%           float centroids[4 * nFaces];       // Center of each face: normalized vector (x,y,z) + norm of this vector
%           float vertices[4 * nVertices];     // Position of each vertex: normalized vector (x,y,z) + norm of this vector
%           short faces[3 * nFaces];           // Indices of the 3 vertices of each face
%           unsigned short nElectrodes;        // Number of electrodes
%           ELECTRODE electrodes[nElectrodes]; // List of electrdes structures
%      }
%    - ELECTRODE{
%           char  label[10];     // Electrode label (including '\0') 
%           short key;           // Usually 'e' for electrode
%           float x, y, z;       // 3D position
%           unsigned short ix;   // Electrode index number
%      }
%
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
% Authors: Francois Tadel, 2009

% Initialize returned structure
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'Neuroscan channels';
% Open file
fid = fopen(ChannelFile, 'r', 'ieee-le');
if (fid == -1)
    error('Could not open file: "%s"',ChannelFile);
end

% ===== READ HEADER =====
hdr.ID       = fread(fid,1,'long');     % Long ID (should be 100003, or 100004. (or 100002) )
hdr.filetype = fread(fid,1,'short');    % Short Filetype (=2 for triangle file)
hdr.rev      = fread(fid,1,'short');    % short revision
hdr.elthick  = fread(fid,1,'float');    % float electrodethickness
hdr.eldiam   = fread(fid,1,'float');    % float electrodediameter
hdr.reserved = fread(fid, 4080,'char'); % BYTE reserved[4080]
hdr.nFaces     = fread(fid,1,'short');
hdr.nVertices  = fread(fid,1,'short');
    
% ===== READ TESSELATION =====
% Centroids, vertices, faces
centroid = fread(fid, 4* hdr.nFaces,'float');
vertices = fread(fid, 4* hdr.nVertices,'float');
faces    = fread(fid, 3* hdr.nFaces,'short');
    
% ===== READ ELECTRODES =====
% Number of electrodes
hdr.nElectrodes = fread(fid,1,'ushort');
% Read each electrode
for i = 1:hdr.nElectrodes,
    hdr.elec(i).lab   = deblank(strtrim(char(fread(fid,10,'char')')));; % label of electrode, max 9 chars + \0
    hdr.elec(i).key   = fread(fid,1,'short');  % key, normally = 'e' for electrode
    hdr.elec(i).pos   = fread(fid,3,'float')'; % x, y, z (position)
    hdr.elec(i).index = fread(fid,1,'ushort'); % electrode index number
end
% Close file
fclose(fid);

% ===== CONVERT TO BRAINSTORM FORMAT =====
% Define a 90deg Z rotation
R = [0 1 0;-1 0 0; 0 0 1];
% Electrodes positions
for i = 1:hdr.nElectrodes
    ChannelMat.Channel(i).Type    = 'EEG';
    ChannelMat.Channel(i).Name    = hdr.elec(i).lab;
    ChannelMat.Channel(i).Loc     = R * hdr.elec(i).pos' ./ 100;
    ChannelMat.Channel(i).Orient  = [];
    ChannelMat.Channel(i).Comment = '';
    ChannelMat.Channel(i).Weight  = 1;
end

