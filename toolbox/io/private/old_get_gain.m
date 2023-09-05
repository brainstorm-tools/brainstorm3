function A = old_get_gain(fid,ndx)
% GET_GAIN: Get a set of source foward fields from a .bin gain matrix file.
%
% USAGE:  A = old_get_gain(fid,ndx);
%
% INPUT:
%    - fid : a file identifier following a fopen call on a valid binary gain matrix file
%    - ndx : vector array of source indices for which the forward fields are requested
% OUTPUT:
%    - A   : array of requested forward fields
%
% NOTES:
%    - The user is responsible for opening the file in the proper machine format.
%    - For head model matrices, this routine should only be accessed from read_gain,
%      so that a consistent machine format is used to read the file.
%
% SEE ALSO: READ_GAIN, LOAD_RAW, SAVE_RAW

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
% Authors: Sylvain Baillet, October 2002

frewind(fid);

rows = fread(fid,1,'uint32');

if nargin == 2 
   cols = length(ndx);
   
   A = zeros(rows,cols);
   
   for i = 1:cols,
      % 4 bytes per element, find starting point
      offset = 4 + (ndx(i)-1)*rows*4;
      status = fseek(fid,offset,'bof');
      if(status == -1),
         error('Error reading file at column %.0f',i);
      end
      
      A(:,i) = fread(fid,[rows,1],'float32'); 
      
   end
   
   return
   
else % ndx is not specified: read the whole matrix
   
   offset = 4;
   fseek(fid,offset,'bof');
   fbegin = ftell(fid);
   fseek(fid,0,'eof');
   fend = ftell(fid);
   
   frewind(fid);
   offset = 4;
   fseek(fid,offset,'bof');
   
   cols = (fend - fbegin + 1) / (4* rows); % Number of sources / columns
   
   A = fread(fid,[rows, cols],'float32');
   
end





