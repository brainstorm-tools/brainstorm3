function G = old_read_gain(FILENAME,chanID,srcID)
% READ_GAIN: Extract parts or a compete gain matrix from .bin binay gain file.
%
% USAGE:  G = old_read_gain(FILENAME,chanID,srcID);
%
% INPUT:
%    - FILENAME: A character string describing the name of the file containing the matrix 
%                The gain matrix file must be in the Brainstorm binary file format.
%    - chanID  : Optional vector of indices linked to the ROWS of the matrix (ie channels) to be extracted 
%                If chanID is LEFT EMPTY, the matrix is extracted for all channels
%    - srcID   : Optional vector of indices linked to the COLUMNS of the matrix to be extracted 
%                If srcID is LEFT EMPTY, matrix is extracted for all sources
% OUTPUT:
%    - G       : an array containing the forward fields of the gain (sub)matrix.
%
% SEE ALSO: GET_GAIN, LOAD_RAW, SAVE_RAW

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
% Authors: Sylvain Baillet, 2002

% Open the file
fid = fopen(FILENAME ,'r','ieee-be'); 
% If file not found: add STUDIES directory
if fid < 0
    ProtocolInfo = bst_get('ProtocolInfo');
    fid = fopen(bst_fullfile(ProtocolInfo.STUDIES, FILENAME) ,'r','ieee-be'); 
end

if fid < 0 
   error('HeadModel file not found.');
end

if nargin == 1
   G = old_get_gain(fid);
elseif nargin == 2
   G = old_get_gain(fid,srcID);
elseif nargin == 3
   if isempty(srcID) % ChanID is defined but srcID is left blank
      G = old_get_gain(fid);
   else
      G = old_get_gain(fid,srcID);
   end
   if ~isempty(chanID)
       G = G(chanID,:); % Keep only channels of interest
   end
end

fclose(fid);


  
