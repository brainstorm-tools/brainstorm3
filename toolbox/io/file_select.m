function [fileList, iFilter] = file_select( DialogType, WindowTitle, DefaultFile, Filters )
% FILE_SELECT: File selection based on Matlab functions only. 
%
% WARNING: In general, java_getfile should be used instead of file_select.
%          However, in some specific cases, java_getfile would freeze Matlab,
%          and this function can be used as a cheap replacement.
%
% INPUT:
%    - DialogType    : {'open', 'save'}
%    - WindowTitle   : String
%    - DefaultFile   : To ignore, set to []
%    - Filters       : {NbFilters x 2} cell array
%                      Filters(i,:) = {{'.ext1', '.ext2', '_tag1'...}, Description}
%
% OUTPUT:
%    - fileList : Cell-array of strings, full paths to the files that were selected
%    - iFilter  : Index of the file filter that was used when selecting the files

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
% Authors: Francois Tadel, 2012

% Default path
if ~isempty(DefaultFile)
    DefaultPath = bst_fileparts(DefaultFile);
else
    DefaultPath = [];
end
% Move to default path
if ~isempty(DefaultPath)
    prevDir = pwd;
    cd(DefaultPath);
end
% Get the file
switch(DialogType)
    case 'open'
        [fileList, fPath, iFilter] = uigetfile(Filters, WindowTitle, DefaultFile);
    case 'save'
        [fileList, fPath, iFilter] = uiputfile(Filters, WindowTitle, DefaultFile);
end
% If nothing was selected
if isequal(fileList,0) || isempty(fileList)
    fileList = [];
    iFilter = [];
    return
end
% Return selected files
if iscell(fileList)
    for i = 1:length(fileList)
        fileList{i} = bst_fullfile(fPath, fileList{i});
    end
else
    fileList = bst_fullfile(fPath, fileList);
end
% Restore initial folder
if ~isempty(DefaultPath)
    cd(prevDir);
end



