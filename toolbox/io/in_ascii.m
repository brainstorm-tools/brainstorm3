function F = in_ascii(DataFile, SkipLines)
% IN_ASCII: Read an ASCII file containing a matrix of floats or integers.
%
% USAGE:  F = in_ascii(DataFile, SkipLines)
%         F = in_ascii(DataFile)
%
% INPUT: 
%    - DataFile  : Full path to an ASCII file
%    - SkipLines : Number of lines to skip at the beginning of the file (default: 0)
% OUTPUT:
%    - F : Matrix read from the files (single)

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2016 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2009-2010

% Parse inputs 
if (nargin < 2) || isempty(SkipLines)
    SkipLines = 0;
end

% If no lines to skip at the beginning of the file: use Matlab's "load" function
if (SkipLines == 0)
    try 
        F = double(load(DataFile, '-ascii'));  % FT 11-Jan-10: Remove "single"
    catch
        F = [];
    end
% Else use the "txt2mat" function
else
    F = double(txt2mat(DataFile, SkipLines));  % FT 11-Jan-10: Remove "single"
end



            