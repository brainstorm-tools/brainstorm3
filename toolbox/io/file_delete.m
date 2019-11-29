function isDeleted = file_delete( fileList, isForced, isRecursive )
% FILE_DELETE: Delete a file, or a list of file, with user confirmation.
%
% USAGE:  isDeleted = file_delete( fileList, isForced, isRecursive=-1 );
% 
% INPUT: 
%     - fileList    : cell array of files or directories to delete
%     - isForced    : if 0, ask user confirmation before deleting files (default)
%                     if 1, do not ask user confirmation
%     - isRecursive : if 3, allow to delete folders that are not part of the database
%                     if 2, allow to delete the studies/anatomy folders
%                     if 1, allow to delete a folder and all its subfolders
%                     if 0, allow to delete only an empty folder
%                     if -1, do not allow to delete a folder (default)
% OUTPUT:
%     - isDeleted :  0 if user aborted deletion
%                   -1 if an error occured
%                    1 if success

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2008-2019

% Parse inputs
if (nargin < 2)
    error('Invalid call to file_delete().');
elseif (nargin < 3) || isempty(isRecursive)
    isRecursive = -1;
end
isDeleted = 0;
% If input is not a cell list : convert it into a cell list
if ischar(fileList)
    fileList = {fileList};
end

% Build string to ask for the deletion
strFiles = [];
strInvalidFiles = [];
nbInvalidFiles = 0;
nbValidFiles = 0;
for i=1:length(fileList)
    if file_exist(fileList{i})
        strFiles = [strFiles '' fileList{i} 10];
        nbValidFiles = nbValidFiles + 1;
    else
        strInvalidFiles = [strInvalidFiles fileList{i} 10];
        fileList{i} = '';
        nbInvalidFiles = nbInvalidFiles + 1;
    end
end

% If invalid filenames were found : display warning message
if ~isempty(strInvalidFiles)
    if ~isForced
        if (nbInvalidFiles <= 10)
            bst_error(['Following files and directories were not found : ' 10 strInvalidFiles], 'Delete files', 0);
        else
            bst_error(sprintf('Warning: %d files and directories were not found.\n\n', nbInvalidFiles), 'Delete files', 0);
        end
    end
    isDeleted = -1;
    return;
end
if isempty(strFiles)
    return
end

% Ask the user a confirmation (if deletion is not forced)
if ~isForced 
    if (nbValidFiles <= 10)
        questStr = ['<HTML>The following files and directories are going to be permanently deleted :<BR><BR>' strrep(strFiles, char(10), '<BR>')];
    else
        questStr = sprintf('<HTML>Warning: %d files are going to be permanently deleted.<BR><BR>', nbValidFiles);
    end
    % Raw warning
    if ~all(cellfun(@(c)isempty(strfind(c, '_0raw')), fileList))
        questStr = [questStr '<BR><FONT color="#008000">Removing links to raw files does not delete the original recordings from<BR>' ...
                        'your hard drive. You can only do this from your operating system file manager.<BR><BR></FONT>'];
                
    end
    isConfirmed = java_dialog('confirm', questStr, 'Delete files');
else
    isConfirmed = 1;
end
% If deletion was confirmed
if isConfirmed
    isDeleted = 1;
    % Delete each file
    for i=1:length(fileList)
        if ~isempty(fileList{i})
            iDSUnload = [];
            % Unload corresponding file
            fileType = file_gettype(fileList{i});
            switch (fileType)
                case {'cortex','scalp','innerskull','outerskull','tess'}
                    bst_memory('UnloadSurface', file_short(fileList{i}), 1);
                case 'subjectimage'
                    bst_memory('UnloadMri', file_short(fileList{i}));
                case 'channel'
                    iDSUnload = bst_memory('GetDataSetChannel', file_short(fileList{i}));
                case {'pdata', 'data'}
                    iDSUnload = bst_memory('GetDataSetData', file_short(fileList{i}));
                case {'presults', 'results', 'link'}
                    iDSUnload = bst_memory('GetDataSetResult', file_short(fileList{i}));
                case {'timefreq', 'ptimefreq'}
                    iDSUnload = bst_memory('GetDataSetTimefreq', file_short(fileList{i}));
            end
            % Unload target datasets
            if ~isempty(iDSUnload)
                bst_memory('UnloadDataSets', iDSUnload);
            end
            % Remove directory
            if isdir(fileList{i})
                switch (isRecursive)
                    case {1, 2, 3}
                        % Get protocol folder
                        ProtocolInfo = bst_get('ProtocolInfo');
                        % Check if the folder to delete is what it is supposed to be
                        if ~isempty(ProtocolInfo)
                            % Delete a CTF .ds folder
                            if strcmpi(fileList{i}(end-2:end), '.ds')
                                isSafe = 1;
                            % Delete external folders
                            elseif (isRecursive == 3)
                                isSafe = 1;
                            % Delete SUBJECTS/STUDIES folders
                            elseif (isRecursive == 2)
                                isSafe = file_compare(fileList{i}, ProtocolInfo.SUBJECTS) || file_compare(fileList{i}, ProtocolInfo.STUDIES);
                            % Delete subfolders of the SUBJECTS/STUDIES folders
                            elseif (isRecursive == 1)
                                isSafe = (~isempty(strfind(file_win2unix(fileList{i}), file_win2unix(ProtocolInfo.SUBJECTS))) && ~file_compare(fileList{i}, ProtocolInfo.SUBJECTS)) || ...
                                         (~isempty(strfind(file_win2unix(fileList{i}), file_win2unix(ProtocolInfo.STUDIES)))  && ~file_compare(fileList{i}, ProtocolInfo.STUDIES)) || ...
                                         ~isempty(strfind(file_win2unix(fileList{i}), bst_get('BrainstormUserDir')));
                            end
                        else
                            isSafe = 1;
                        end
                        % If the folder is one of the folders that brainstorm is allowed to modify: proceed
                        if isSafe
                            try
                                rmdir(fileList{i}, 's');
                            catch
                                disp(['BST> Error: Could not delete folder "' fileList{i} '" and all its subfolders.']);
                                isDeleted = -1;
                            end
                        else
                            bst_error(['This call to file_delete() is trying to delete the following folder:' 10 fileList{i} 10 ...
                                       'This is not considered to be a folder managed by Brainstorm, the request was cancelled.' 10 10 ...
                                       'Please report this error to the Brainstorm developers using the user forum:' 10 ...
                                       'https://neuroimage.usc.edu/forums/'], 'Error in file_delete.m', 1);
                            isDeleted = -1;
                            return;
                        end
                        
                    % Delete empty folders
                    case 0
                        % Check if the folder is empty
                        if (length(dir(fileList{i})) > 2)
                            disp(['BST> Error: Folder "' fileList{i} '" is not empty, not deleted.']);
                            isDeleted = -1;
                        else
                            try
                                rmdir(fileList{i});
                            catch
                                disp(['BST> Error: Could not delete folder "' fileList{i} '"']);
                                isDeleted = -1;
                            end
                        end
                        
                    % Delete only single files, no folders
                    case -1
                        bst_error(['This call to file_delete() is trying to delete the following folder instead of a single file:' 10 fileList{i} 10 10 ...
                                   'Please report this error to the Brainstorm developers using the user forum:' 10 ...
                                   'https://neuroimage.usc.edu/forums/'], 'Error in file_delete.m', 1);
                        isDeleted = -1;
                        return;
                end
            % Remove single file
            else
                warning('off', 'MATLAB:DELETE:Permission');
                delete(fileList{i});
                isDeleted = 1;
            end
        end
    end
end
    
