function db_delete_studies( iStudies )
% DB_DELETE_STUDIES: Delete some studies from the brainstorm database.
%
% USAGE:  db_delete_studies( iStudies )
%
% INPUT:
%    - iStudies : indices of the studies to delete

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
% Authors: Francois Tadel, 2009-2014
%          Raymundo Cassani, 2022

sqlConn = sql_connect();
ProtocolInfo = bst_get('ProtocolInfo');
save_db = 0;

% For each study
for iStudy = iStudies
    % Get filename of study
    sStudy = db_get(sqlConn, 'Study', iStudy, 'FileName');
    % Delete study directory (and all its subdirectories)
    dirStudy = bst_fullfile(ProtocolInfo.STUDIES,  bst_fileparts(sStudy.FileName));
    if file_exist(dirStudy)
        result = file_delete(dirStudy, 1, 1);
    else
        result = 1;
    end
    % If the study was removed
    if (result == 1)
        % TODO: This could be done more efficient with ON DELETE CASCADE
        % Remove Study from DB
        db_set(sqlConn, 'Study', 'Delete', iStudy);
        % Remove FunctionalFiles for Study from DB
        db_set(sqlConn, 'FilesWithStudy', 'Delete', iStudy);
        save_db = 1;
    end
%     % Try to remove all the parents dirs until STUDIES dir, if they are empty
%     parentDir = bst_fileparts(bst_fileparts(ProtocolStudies.Study(iStudy).FileName), 1);
%     while isDeleted && ~isempty(parentDir)
%         % Try to delete it
%         try
%             rmdir(bst_fullfile(ProtocolInfo.STUDIES, parentDir));
%             isDeleted = 1;
%         catch
%             isDeleted = 0;
%         end
%         % Get parent directory
%         parentDir = bst_fileparts(parentDir, 1);
%     end
end
sql_close(sqlConn);

% If something was deleted, save database
if save_db
    db_save();
end




