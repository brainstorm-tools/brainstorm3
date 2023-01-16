function [FileName, FileType, isAnatomy] = file_short( FileName )
% FILE_SHORT: Return a relative filename from the full filename 
% 
% USAGE:  [FileName, FileType, isAnatomy] = file_short( FileName )
%         [FileName, FileType, isAnatomy] = file_short( FileNames )

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
% Authors: Francois Tadel, 2012-2022

% Empty input
if isempty(FileName)
    disp('FILE_SHORT> Input filename is empty');
    return;
% List of files: recursive calls
elseif iscell(FileName)
    for i = 1:length(FileName)
        FileName{i} = file_short( FileName{i} );
    end
    return
end

% Get protocol folders
ProtocolInfo = bst_get('ProtocolInfo');
if isempty(ProtocolInfo)
    return
end
% Get file type
FileType = file_gettype(FileName);
isAnatomy = 0;
% Add protocol path
switch lower(FileType)
    case {'brainstormsubject', 'subject', 'subjectimage', 'anatomy', 'scalp', 'outerskull', 'innerskull', 'cortex', 'fibers', 'fem', 'other', 'tess'}
        FileName = file_win2unix(strrep(FileName, ProtocolInfo.SUBJECTS, ''));
        isAnatomy = 1;
    case {'brainstormstudy', 'study', 'studysubject', 'condition', 'rawcondition', 'channel', 'headmodel', 'data', 'rawdata', 'results', 'kernel', 'pdata', 'presults', 'noisecov', 'ndatacov', 'dipoles', 'timefreq', 'spectrum', 'ptimefreq', 'pspectrum', 'matrix', 'pmatrix', 'proj', 'image', 'video', 'videolink', 'spike', 'dirspikes'}
        FileName = file_win2unix(strrep(FileName, ProtocolInfo.STUDIES, ''));
    case 'link'
        % Keep it the way it is
    otherwise
        %error('Unsupported file type.');
end


