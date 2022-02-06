function MatString = view_struct( filename )
% VIEW_STRUCT: Display all the variables contained in a .MAT file or a structure.
%
% USAGE:  MatString = view_struct( filename )
%         MatString = view_struct( structure )

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
% Authors: Francois Tadel, 2008-2012

% If need to read a file
if ischar(filename)
    bst_progress('start', 'View .MAT file', 'Loading file...');
    % Check file type
    fileType = file_gettype(filename);
    if strcmpi(fileType, 'link')
        filename = file_resolve_link(filename);
    end
    % Load file 
    MatContents = load(filename);
    % Try to get file in database
    [sStudy, iStudy, iItem] = bst_get('AnyFile', filename);
    % Display header : file path, file name
    if isempty(sStudy)
        [filePath, fileBase, fileExt] = bst_fileparts(filename);
        fileBase = [fileBase, fileExt];
    else
        ProtocolInfo = bst_get('ProtocolInfo');
        [filename, FileType, isAnatomy] = file_fullpath(filename);
        if isAnatomy
            filePath = ProtocolInfo.SUBJECTS;
        else
            filePath = ProtocolInfo.STUDIES;
        end
        fileBase = file_win2unix(strrep(filename, filePath, ''));
    end
    nbSeparators = 6 + max(length(filePath), length(fileBase));
    MatString = sprintf('\nPath: %s\nName: %s\n%s\n  |  ', filePath, fileBase, repmat('-', [1,nbSeparators]));
    % Window title
    wndTitle = fileBase;
elseif isstruct(filename)
    MatContents = filename;
    % Display header
    MatString = 'Structure';
    wndTitle = 'Structure';
else
    error('Cannot display this type of variable.');
end

% Display all the file fields
MatString = [MatString, str_format(MatContents)];
% Open text viewer
view_text( MatString, wndTitle );

bst_progress('stop');

end






 
