function varargout = file_update( fileName, action, varargin )
% FILE_UPDATE: Changes the name, the location, or a field of a Brainstorm .Mat file.
%
% USAGE:  [status, newFileName] = file_update(fileName, 'FileType', filetype);
%              => Renames the file removing all the reserved words and adding the target 
%                 reserved word <value>
%
%         [status] = file_update(fileName, 'Field', fieldName, fieldValue);
%              => Load the file, add or update the field <fieldname> with <value>
%                 and save the file back.
%              => fieldName and fieldValue can be either single objects or cell arrays of the same size

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
% Authors: Francois Tadel, 2008-2010
switch (action)
    % ===== FILETYPE =====
    case 'FileType'
        % Parse inputs
        if (nargin == 3)
            filetype = varargin{1};
        else
            error('Usage : file_update(fileName, ''FileType'', filetype)');
        end
        % Get extract file name, path and extension
        [filePath, fileBase, fileExt] = bst_fileparts(fileName);
        % Remove all the markers from the filename
        markersList = {'brainstormsubject', 'subjectimage', 'tess', 'cortex', 'brain', 'scalp', ...
                       'head', 'skull', 'outerskull', 'innerskull', 'vertconn', 'brainstormstudy', ...
                       'channel', 'data', 'headmodel', 'res4', 'results', 'ctf', 'fibers'};
        for i=1:length(markersList)
            % Remove tags inside the filename
            fileBase = strrep(fileBase, ['_' markersList{i}], '');
            % Remove tags at the beginning of the filename
            iTags = strfind(fileBase, markersList{i});
            if ~isempty(iTags) && (iTags(1) == 1)
                fileBase = strrep(fileBase, [markersList{i} '_'], '');
            end
            if (length(markersList{i}) <= length(fileBase)) && strcmpi(fileBase(1:length(markersList{i})), markersList{i})
                fileBase(1:length(markersList{i})) = [];
            end
        end
        % If filename contained only significative tags => use a default
        if isempty(fileBase)
            fileBase = '01';
        end
        % Add new filetype marker
        newFileName = bst_fullfile(filePath, [filetype, '_', fileBase, fileExt]);
        % Make new filename unique
        newFileName = file_unique(newFileName);
        % Try name to rename file
        [status,errmsg,errmsgid] = movefile(fileName, newFileName);
        if ~status
            isOk = 0;
            warning('Cannot rename file "%s": \n=> %s', fileName, errmsg);
        else
            isOk = 1;
        end
        % Return status and newFileName
        if (nargout >= 1)
            varargout{1} = isOk;
        end
        if (nargout >= 2)
            varargout{2} = newFileName;
        end
        
        
    % ===== FIELD =====
    case 'Field'
        % Returned satuts
        if (nargout >= 1)
            varargout{1} = 0;
        end
        % Parse inputs
        if (nargin == 4) && iscell(varargin{1}) && iscell(varargin{2}) && (length(varargin{1}) == length(varargin{2}))
            fieldName  = varargin{1};
            fieldValue = varargin{2};
        elseif (nargin == 4) && ischar(varargin{1})
            fieldName  = varargin(1);
            fieldValue = varargin(2);
        else
            error('Usage : file_update(fileName, ''Field'', fieldName, fieldValue)');
        end

        % Create structure to add export to the file
        bstMat = struct();
        for i = 1:length(fieldName)
            bstMat.(fieldName{i}) = fieldValue{i};
        end
        
        [tmpp, filenameshort, filenameext] = bst_fileparts(fileName);
        bst_progress('start', 'Update Brainstorm file', ['Updating file "' filenameshort filenameext '"...']);

        % Try to save file
        try
            save(fileName, '-struct', 'bstMat', '-append');
            % Return status = 1
            if (nargout >= 1)
                varargout{1} = 1;
            end  
        catch
            warning('Cannot save file "%s": \n=> %s', fileName, lasterr);
        end
        
        bst_progress('stop');
        
    otherwise
        warning('Invalid action.');
end





