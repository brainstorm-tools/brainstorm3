function hs = read_4d_hs(HeadshapeFile)
% READ_4D_HS: Read a 4D/BTi headshape file.
% 
% USAGE:  hs = read_4d_hs(HeadshapeFile)

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

% Open file
fid = fopen(HeadshapeFile, 'r', 'b');
if (fid < -1)
    error('Cannot open headshape file.');
end
% Read file header
hs.version   = fread(fid, 1, 'uint32');
hs.timestamp = fread(fid, 1, 'int32');
hs.checksum  = fread(fid, 1, 'int32');
hs.nPoints   = fread(fid, 1, 'int32=>double');
% Read fiducials
refPoints = fread(fid, [3,5], 'double')';
% Read head points
hs.points = fread(fid, [3, hs.nPoints], 'double')';
% Read 
fclose(fid);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% FOLLOWING PART BASED ON ASSUMPTIONS BY ROBERT OOSTENVELD, EEGLAB, 2008
%%% TO BE VERIFIED 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Detect the indices of nasion, left and right
[junk, iNas] = max(refPoints(1:3,1));
[junk, iLpa] = max(refPoints(1:3,2));
[junk, iRpa] = min(refPoints(1:3,2));
hs.SCS.NAS = refPoints(iNas,:);
hs.SCS.LPA = refPoints(iLpa,:);
hs.SCS.RPA = refPoints(iRpa,:);

        