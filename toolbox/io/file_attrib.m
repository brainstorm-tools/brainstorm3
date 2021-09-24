function isOk = file_attrib(fName, right)
% FILE_ATTRIB: Return 1 if user have the given right on the file fName, else 0.
% On Windows: Tries to get the permission for writing automatically on folders
%
% USAGE:  isOk = file_attrib(fName, 'r')
%         isOk = file_attrib(fName, 'w')

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
% Authors: Francois Tadel, 2008-2018

if isempty(fName)
    isOk = 0;
elseif ~isdir(fName)
    % If file exists
    isExisting = file_exist(fName);
    % Try to open the file with required attribute
    if isExisting && (right == 'w')
        fid = fopen(fName, 'a');
    else
        fid = fopen(fName, right);
    end
    % Check fopen return status
    if (fid > 0)
        % File was successfully open
        isOk = 1;
        % Close file
        fclose(fid);
        % If file was not existing, it has been create => delete
        if ~isExisting
            delete(fName);
        end
    else
        % File was not open
        isOk = 0;
    end
elseif isdir(fName)
    % Get all the rights
    [tmp__,att] = fileattrib(fName);
%     % On windows: grab write permission automatically
%     if ispc && (right == 'w') && ~att.UserWrite
%         % Use attrib function to update the file
%         system(['attrib -r ' fName ' /s /d']);
%         % Read again the permissions
%         [tmp__,att] = fileattrib(fName);
%     end
    % Get proper right
    switch (right)
        case 'r'
            if isfield(att, 'UserRead')
                isOk = att.UserRead;
            else
                isOk = 0;
            end
        case 'w'
            if isfield(att, 'UserWrite')
                isOk = att.UserWrite;
            else
                isOk = 0;
            end
        otherwise
            error('Invalid option.');
    end
end



