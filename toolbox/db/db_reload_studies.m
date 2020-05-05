function db_reload_studies( iStudies, isUpdate )
% DB_RELOAD_STUDIES: Reload a set of studies of the current protocol.
% Parse the study's directory again and replace Study structure in Brainstorm database.
%
% USAGE:  db_reload_studies( iStudies );
%
% INPUT:  iStudies: array of study indices to reload in protocol studies array

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
% Authors: Francois Tadel, 2008-2010

% Parse inputs
if isempty(iStudies)
    return
end
if (nargin < 2) || isempty(isUpdate)
    isUpdate = 1;
end
% Get protocol information
ProtocolInfo = bst_get('ProtocolInfo');

% If no progressbar is visible: create one
isProgressBar = ~bst_progress('isVisible');
if isProgressBar
    bst_progress('start', 'Reload datasets', 'Reloading datasets...', 0, 100 * length(iStudies));
end
% Process
for iStudy = iStudies
    % Get study
    sStudy = bst_get('Study', iStudy);
    if isempty(sStudy)
        continue;
    end
    % Get study directory
    studySubDir = bst_fileparts(sStudy.FileName);
    % Check the existance of the study's directory
    if ~file_exist(bst_fullfile(ProtocolInfo.STUDIES, studySubDir))
        db_fix_protocol();
        bst_progress('stop');
        return
    end
    % Parse study directory
    sStudyNew = db_parse_study(ProtocolInfo.STUDIES, studySubDir, 100);
    % If study could not be loaded
    if isempty(sStudyNew)
        db_fix_protocol();
        bst_progress('stop');
        return
    end
    % Try to reuse the existing selection of headmodel (which is not saved on the hard drive)
    if ~isempty(sStudy.iHeadModel) && (sStudy.iHeadModel <= length(sStudyNew.HeadModel))
        sStudyNew.iHeadModel = sStudy.iHeadModel;
    end
    % Else study was reloaded
    bst_set('Study', iStudy, sStudyNew);
end

% Update display
if isUpdate
    % Update links
    db_links('Study', iStudies);
    % Update tree
    panel_protocols('UpdateNode', 'Study', iStudies);
end
% Save database
db_save();
% Close progress bar
if isProgressBar
    bst_progress('stop');
end




