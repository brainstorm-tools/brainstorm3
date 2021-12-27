function filename = file_standardize( filename, isFullPath, repchar, isStrict )
% FILE_STANDARDIZE: Remove all the characters that might be source of problems when in filenames.
%
% USAGE:  filename = file_standardize( filename, isFullPath, repchar )
%         filename = file_standardize( filename, isFullPath )
%         filename = file_standardize( filename )
%
% INPUT:
%      - filename   : name of file or full path to standardize
%      - isFullPath : if 0, simple filename => remove '/' and '\'     (DEFAULT)
%                     if 1, full path to filename => keep '/' and '\'
%      - repchar    : replacement character (default '_');
%      - isStrict   : if 1, also removes the parenthesis: []()
% 
% OUTPUT: 
%      - filename   : standardized filename

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

if (nargin < 4) || isempty(isStrict)
    isStrict = 0;
end
if (nargin < 3) || isempty(repchar)
    repchar = '_';
end
if (nargin < 2) || isempty(isFullPath)
    isFullPath = 0;
end

intFilename = double(filename);

% Tables
if isStrict
    alphaNum = double('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-./\_@');
else
    alphaNum = double('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-.()[]/\_@');
end
eSpecial = 232:235;
aSpecial = 224:230;
cSpecial = 231;
uSpecial = 249;
slashes  = double('/\');

% Replace all special chars
intFilename(intFilename == cSpecial) = double('c');
intFilename(intFilename == uSpecial) = double('u');
intFilename(ismember(intFilename, eSpecial)) = double('e');
intFilename(ismember(intFilename, aSpecial)) = double('a');
intFilename(~ismember(intFilename, alphaNum)) = double(repchar);

% Replace slashes
if isFullPath
    intFilename(ismember(intFilename, slashes)) = filesep;
else
    intFilename(ismember(intFilename, slashes)) = double(repchar);
end

filename = char(intFilename);

end

