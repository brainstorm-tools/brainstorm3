function TessMat = in_tess_dsgl(TessFile)
% IN_TESS_DSGL: Load the old BrainSuite .dsgl format tessellation file.
%
% USAGE:  TessMat = in_tess_dsgl(TessFile);
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
% Authors: Francois Tadel, 2008-2010

% Initialize returned value
TessMat = struct('Vertices', [], 'Faces', []);


%% ===== READ DSGL FILE =====
% Open file
fid = fopen(TessFile, 'rb', 'ieee-le');
if (fid < 0)
   error('Cannot open file'); 
end

% Check if file should be read in Big or Little Endian
magic1 = ('dsgl')';
magic2 = ('lgsd')';
magic  = fread(fid, 4, '*char');
if (magic ~= magic1)
   if (magic == magic2)
       % Reopen file in big endian
       fclose(fid);
       fid = fopen(s,'rb','ieee-be');
       if (fid<0) 
           error('Cannot open file'); 
       end
   end
end

origin = [0 0 0];
hsize = fread(fid, 1, 'int32');

if (hsize>44)
   version = char(fread(fid,8,'char'))';
end

ntris=fread(fid,1,'int32');
nverts=fread(fid,1,'int32');
nStripPoints=fread(fid,1,'int32');
res   = fread(fid,3,'*float32');

if (hsize>44)
   origin = fread(fid,3,'float');
end

r = fseek(fid, double(hsize), -1);
if (r~=0) 
   error('file is truncated'); 
end

% Read faces and vertices
Faces    = fread(fid,[3 ntris  ],'int32') + 1;
Vertices = fread(fid,[3 nverts ],'float');
Faces    = double(Faces');
Vertices = double(Vertices');

fclose(fid);


%% ===== CONVERT IN BRAINSTORM FORMAT =====
TessMat.Vertices = double([Vertices(:,1) * (res(1)/1000), ...
                           Vertices(:,2) * (res(2)/1000), ...
                           Vertices(:,3) * (res(3)/1000)]');
TessMat.Faces = Faces;






