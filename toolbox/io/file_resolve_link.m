function [OutputFile, DataFile] = file_resolve_link( InputFile )
% FILE_RESOLVE_LINK: Resolve a brainstorm 'link' filename to the right 'results' file.
%
% USAGE:  [OutputFile, DataFile] = file_resolve_link(InputFile)
%
% INPUT:
%    - InputFile  : Full path to file to resolve
%
% OUTPUT:
%    If InputFile type is 'link':
%        - OutputFile : corresponding 'results' file
%        - DataFile   : corresponding 'data' file
%    Else, InputFile is not a link:
%        - OutputFile : the same path as InputFile.
%        - DataFile   : []

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
% Authors: Francois Tadel, 2008-2013

% Get protocol folders
ProtocolInfo = bst_get('ProtocolInfo');
% InputFile is a link
if strcmpi(file_gettype(InputFile), 'link')
    % Split string around '|'
    splitFile = str_split(InputFile, '|');
    % Get results and data full filenames
    OutputFile = bst_fullfile(ProtocolInfo.STUDIES, splitFile{2});
    DataFile = bst_fullfile(ProtocolInfo.STUDIES, splitFile{3});
% InputFile is a real results filename
else
    % Return full filename
    OutputFile = strrep(InputFile, ProtocolInfo.STUDIES, '');
    OutputFile = bst_fullfile(ProtocolInfo.STUDIES, OutputFile);
    DataFile = [];
end



