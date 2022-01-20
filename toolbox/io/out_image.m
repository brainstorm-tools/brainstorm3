function out_image(filename, img)
% OUT_IMAGE: Save an image in a matrix format to a file, and add it to database.
%
% USAGE:  out_image(filename, img)
%                       
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
% Authors: Francois Tadel, 2009

% Save image
imwrite(img, filename);

% Get protocol definition
ProtocolInfo = bst_get('ProtocolInfo');
% If image file not was saved in current protocol: exit
if isempty(strfind(filename, ProtocolInfo.STUDIES))
    return
end
filename = file_short(filename);
% Looking for a study file in this directory
studyDir = bst_fileparts(filename);
listFiles = dir(bst_fullfile(ProtocolInfo.STUDIES, studyDir, 'brainstormstudy*.mat'));
% If directory is not a brainstorm study: exit
if isempty(listFiles)
    return
end
% Look for this study file in database
[sStudy, iStudy] = bst_get('Study', bst_fullfile(studyDir, listFiles(1).name));
if isempty(sStudy)
    return
end

% Reload study
db_reload_studies(iStudy);

