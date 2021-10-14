function bst_save(FileName, FileMat, Version, isAppend)
% BST_SAVE: Safe call to Matlab save() that adapts the format to the data.
%
% USAGE:  bst_save(FileName, FileMat, Version='v7', isAppend=0)
%
% INPUTS: 
%    - FileName : Full path to the file to save
%    - FileMat  : Structure to save in the file
%    - Version  : 'v6', fastest option, bigger files, no files >2Gb
%                 'v7', slower option, compressed, no files >2Gb
%                 'v7.3', much slower, compressed, allows files >2Gb
%    - isAppend : {0,1}, if 1 appends/overwrite the new specified fields to the file

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
% Authors: Francois Tadel, 2013

% Parse inputs
if (nargin < 4) || isempty(isAppend)
    isAppend = 0;
end
if (nargin < 3) || isempty(Version)
    Version = 'v7';
else
    Version(Version == '-') = [];
end
    
% Check file size (>2Gb requires v7.3)
if ~strcmpi(Version, 'v7.3')
    s = whos('FileMat');
    sizeFile = s.bytes / 1024/1024/1024;
    if (sizeFile >= 2)
        disp(sprintf('BST> Warning: Uncompressed file size is %1.3f Gb, saving using v7.3 format...', sizeFile));
        Version = 'v7.3';
    end
end
% Check if all the mat-files should be compressed
if strcmpi(Version, 'v6') && bst_get('ForceMatCompression')
    Version = 'v7';
end

% Save file
isStop = 0;
isSetFormat = 1;
while ~isStop
    % Try to save the file
    try
        if isAppend
            save(FileName, '-struct', 'FileMat', '-append');
        elseif isSetFormat
            % No idea why this is crashing randomly on some linux computers for some specific filenames...
            save(FileName, '-struct', 'FileMat', ['-' Version]);
        else
            save(FileName, '-struct', 'FileMat');
        end
        isStop = 1;
    % If file could not be saved
    catch
        % Try again without specifying the file format
        if ~isAppend && isSetFormat
            isSetFormat = 0;
            continue;
        end
        if isAppend && exist(FileName, 'file') ~= 2
            errorStr = 'Trying to append to inexistent file.';
        else
            errorStr = 'Disk full, disconnected or read-only.';
        end
        % Display error message
        disp(['BST> Error: Could not write file: ' FileName 10 ...
              'BST> ' errorStr]);
        % Try deleting the contents in temporary directory
        isDelTmp = gui_brainstorm('EmptyTempFolder');
        if (isDelTmp == -1)
            isStop = 1;
        end
        % Display error message if possible
        [fPath, fBase, fExt] = bst_fileparts(FileName);
        if bst_get('isGUI') && ismember(fBase, {'brainstorm', 'protocol'})
            % Database file could not be written: ask user what to do
            res = java_dialog('question', [...
                'Error: ' errorStr 10 10 ...
                'Could not write file: ' 10 FileName 10], ...
                'Save file', [], {'Retry', 'Cancel'}, 'Retry');
            % Stop trying
            if ~isequal(res, 'Retry')
                isStop = 1;
            else
                file_delete(FileName, 1);
            end
        else
            error(['Could not save file: ' FileName 10 errorStr]);
        end
    end
end




