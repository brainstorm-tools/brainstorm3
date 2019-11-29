function [FileName, FileType, isAnatomy] = file_fullpath( FileName )
% FILE_FULLPATH: Return the full filename from a relative filename
% 
% USAGE:  [FileName, FileType, isAnatomy] = file_fullpath( FileName )
%         [FileName, FileType, isAnatomy] = file_fullpath( FileNames )

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
% Authors: Francois Tadel, 2011-2012

% Empty input
if isempty(FileName)
    disp('FILE_FULLPATH> Input filename is empty');
    return;
% List of files: recursive calls
elseif iscell(FileName)
    for i = 1:length(FileName)
        FileName{i} = file_fullpath( FileName{i} );
    end
    return
end

% Get protocol folders
ProtocolInfo = bst_get('ProtocolInfo');
% Get file type
FileType = file_gettype(FileName);
isAnatomy = 0;
tmpFile = [];
% Add protocol path
switch lower(FileType)
    case {'brainstormsubject', 'subject', 'subjectimage', 'anatomy', 'scalp', 'outerskull', 'innerskull', 'cortex', 'fibers', 'fem', 'other', 'tess'}
        if ~file_exist(FileName)
            tmpFile = bst_fullfile(ProtocolInfo.SUBJECTS, FileName);
        end
        isAnatomy = 1;
    case {'brainstormstudy', 'study', 'studysubject', 'condition', 'rawcondition', 'channel', 'headmodel', 'data', 'rawdata', 'results', 'kernel', 'pdata', 'presults', 'noisecov', 'ndatacov', 'dipoles', 'timefreq', 'spectrum', 'ptimefreq', 'pspectrum', 'matrix', 'pmatrix', 'proj', 'image', 'video', 'videolink', 'spikes'}
        if ~file_exist(FileName)
            tmpFile = bst_fullfile(ProtocolInfo.STUDIES, FileName);
        end
    case 'link'
        tmpFile = file_resolve_link(FileName);
    otherwise
        error('Unsupported file type.');
end

% If something was changed
if ~isempty(tmpFile)
    % Check for file existence
    if ~isempty(dir(tmpFile))
        FileName = tmpFile;
    else
        warning(['File not found: ', tmpFile]);
    end
end
end

