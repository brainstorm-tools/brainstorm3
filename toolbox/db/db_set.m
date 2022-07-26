function varargout = db_set(varargin)
% DB_SET: Set values in the protocol database from a Brainstorm structure
% This function is a newer API than bst_set
% 
% USAGE :
%    - db_set(contextName) or 
%    - db_set(sqlConn, contextName)
%
% ====== PROTOCOLS =====================================================================
%
%
% ====== SUBJECTS ======================================================================
%    - db_set('Subject', 'Delete')            : Delete all Subjects
%    - db_set('Subject', 'Delete', SubjectId) : Delete Subject by ID
%    - db_set('Subject', 'Delete', CondQuery) : Delete Subject with Query
%    - db_set('Subject', sSubject)            : Insert Subject
%    - db_set('Subject', sSubject, SubjectId) : Update Subject by ID
%
% ====== ANATOMY FILES =================================================================
%    - db_set('AnatomyFile', 'Delete')                      : Delete all AnatomyFiles
%    - db_set('AnatomyFile', 'Delete', AnatomyFileId)       : Delete AnatomyFile by ID
%    - db_set('AnatomyFile', 'Delete', CondQuery)           : Delete AnatomyFile with Query
%    - db_set('AnatomyFile', sAnatomyFile)                  : Insert AnatomyFile
%    - db_set('AnatomyFile', sAnatomyFile, AnatomyFileId)   : Update AnatomyFile by ID
%    - db_set('FilesWithSubject', 'Delete' , SubjectID)     : Delete all AnatomyFiles from SubjectID
%    - db_set('FilesWithSubject', sAnatomyFiles, SubjectID) : Insert AnatomyFiles with SubjectID
%
% ====== STUDIES =======================================================================
%    - db_set('Study', 'Delete')            : Delete all Studies
%    - db_set('Study', 'Delete', StudyId)   : Delete Study by ID
%    - db_set('Study', 'Delete', CondQuery) : Delete Study with Query
%    - db_set('Study', sStudy)              : Insert Study
%    - db_set('Study', sStudy, StudyId)     : Update Study by ID
%
% ====== FUNCTIONAL FILES ==============================================================
%    - db_set('FunctionalFile', 'Delete')                          : Delete all FunctionalFiles
%    - db_set('FunctionalFile', 'Delete', FunctionalFileId)        : Delete FunctionalFile by ID
%    - db_set('FunctionalFile', 'Delete', CondQuery)               : Delete FunctionalFile with Query
%    - db_set('FunctionalFile', sFunctionalFile)                   : Insert FunctionalFile
%    - db_set('FunctionalFile', sFunctionalFile, FunctionalFileId) : Update FunctionalFile by ID
%    - db_set('FilesWithStudy', 'Delete' , StudyID)                : Delete All FunctionalFiles from StudyID
%    - db_set('FilesWithStudy', sFunctionalFiles, StudyID)         : Insert FunctionalFiles with StudyID
%    - db_set('ParentCount', ParentFileID, modifier, count)        : Update NumChildren field in ParentFileID
%
% SEE ALSO db_get
%
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
% Authors: Martin Cousineau, 2020
%          Raymundo Cassani, 2021

%% ==== PARSE INPUTS ====
if (nargin > 1) && isjava(varargin{1})
    sqlConn = varargin{1};
    varargin(1) = [];
    handleConn = 0;
elseif (nargin >= 1) && ischar(varargin{1}) 
    sqlConn = sql_connect();
    handleConn = 1;
else
    error(['Usage : db_set(contextName) ' 10 '        db_set(sqlConn, contextName)']);
end

try
contextName = varargin{1};
args = {};
if length(varargin) > 1
    args = varargin(2:end);
end
varargout = {};
   
% Set required context structure
switch contextName
%% ==== SUBJECT ====
    % Success              = db_set('Subject', 'Delete')
    %                      = db_set('Subject', 'Delete', SubjectId)
    %                      = db_set('Subject', 'Delete', CondQuery)
    % [SubjectId, Subject] = db_set('Subject', Subject)
    %                      = db_set('Subject', Subject, SubjectId)
    case 'Subject'
        % Default parameters
        iSubject = [];       
        varargout{1} = [];
        
        if length(args) < 1
            error('Error in number of arguments')
        end
        
        sSubject = args{1};
        if length(args) > 1
            iSubject = args{2};
        end
        % Delete 
        if ischar(sSubject) && strcmpi(sSubject, 'delete')
            if isempty(iSubject)
                % Delete all rows in Subject table
                delResult = sql_query(sqlConn, 'DELETE', 'Subject');
                % Reset auto-increment
                sql_query(sqlConn, 'RESET-AUTOINCREMENT', 'Subject');
            else
                if isstruct(iSubject)
                    % Delete using the CondQuery
                    delResult = sql_query(sqlConn, 'DELETE', 'Subject', iSubject);
                elseif isnumeric(iSubject)
                    % Delete using iSubject
                    delResult = sql_query(sqlConn, 'DELETE', 'Subject', struct('Id', iSubject));
                end
            end
            if delResult > 0
                varargout{1} = 1;
            end
            
        % Insert or Update    
        elseif isstruct(sSubject)
            if isempty(iSubject)
                % Insert Subject row
                sSubject.Id = []; 
                iSubject = sql_query(sqlConn, 'INSERT', 'Subject', sSubject);
                varargout{1} = iSubject;
            else
                % Update Subject row
                if ~isfield(sSubject, 'Id') || isempty(sSubject.Id) || sSubject.Id == iSubject
                    resUpdate = sql_query(sqlConn, 'UPDATE', 'Subject', sSubject, struct('Id', iSubject));
                else
                    error('Cannot update Subject, Ids do not match');
                end
                if resUpdate>0
                    varargout{1} = iSubject;
                end
            end
            % If requested, get the inserted or updated row
            if nargout > 1
                varargout{2} = db_get(sqlConn, 'subject', iSubject);
            end
        else
            % No action
        end        

        
%% ==== ANATOMY FILES ====
    % Success                      = db_set('AnatomyFile', 'Delete')
    %                              = db_set('AnatomyFile', 'Delete', AnatomyFileId)
    %                              = db_set('AnatomyFile', 'Delete', CondQuery)
    % [AnatomyFileId, AnatomyFile] = db_set('AnatomyFile', AnatomyFile)
    %                              = db_set('AnatomyFile', AnatomyFile, AnatomyFileId)
    case 'AnatomyFile'
        % Default parameters
        iAnatFile = [];
        varargout{1} = [];
        
        if length(args) < 1
            error('Error in number of arguments')
        end
        
        sAnatFile = args{1};
        if length(args) > 1
            iAnatFile = args{2};
        end
        % Delete 
        if ischar(sAnatFile) && strcmpi(sAnatFile, 'delete')
            if isempty(iAnatFile)
                % Delete all rows in AnatomyFile table
                delResult = sql_query(sqlConn, 'DELETE', 'AnatomyFile');
                % Reset auto-increment
                sql_query(sqlConn, 'RESET-AUTOINCREMENT', 'AnatomyFile');
            else
                if isstruct(iAnatFile)
                    % Delete using the CondQuery
                    delResult = sql_query(sqlConn, 'DELETE', 'AnatomyFile', iAnatFile);
                elseif isnumeric(iAnatFile)
                    % Delete using iAnatomyFile
                    delResult = sql_query(sqlConn, 'DELETE', 'AnatomyFile', struct('Id', iAnatFile));
                end
            end
            if delResult > 0
                varargout{1} = 1;
            end
            
        % Insert or Update    
        elseif isstruct(sAnatFile)
            if isempty(iAnatFile)
                % Insert AnatomyFile row
                sAnatFile.Id = [];
                iAnatFile = sql_query(sqlConn, 'INSERT', 'AnatomyFile', sAnatFile);
                varargout{1} = iAnatFile;
            else
                % Update iAnatomyFile row
                if ~isfield(sAnatFile, 'Id') || isempty(sAnatFile.Id) || sAnatFile.Id == iAnatFile
                    resUpdate = sql_query(sqlConn, 'UPDATE', 'AnatomyFile', sAnatFile, struct('Id', iAnatFile));
                else
                    error('Cannot update AnatomyFile, Ids do not match');
                end
                if resUpdate>0
                    varargout{1} = iAnatFile;
                end
            end
            % If requested, get the inserted or updated row
            if nargout > 1
                varargout{2} = db_get(sqlConn, 'AnatomyFile', iAnatFile);
            end
        else
            % No action
        end
        
%% ==== FILES WITH SUBJECT ====
    % Success       = db_set('FilesWithSubject', 'Delete'     , SubjectID)
    % sAnatomyFiles = db_set('FilesWithSubject', sAnatomyFiles, SubjectID)
    case 'FilesWithSubject'
        sAnatFiles = args{1};
        iSubject = args{2};
        
        % Delete all AnatomyFiles with SubjectID
        if ischar(sAnatFiles) && strcmpi(sAnatFiles, 'delete')
            delResult = sql_query(sqlConn, 'DELETE', 'AnatomyFile', struct('Subject', iSubject));
            varargout{1} = 1;
        % Insert AnatomyFiles to SubjectID
        elseif isstruct(sAnatFiles)
            nAnatomyFiles = length(sAnatFiles);
            insertedIds = zeros(1, nAnatomyFiles);
            for ix = 1 : nAnatomyFiles
                sAnatFiles(ix).Subject = iSubject;
                insertedIds(ix) = db_set(sqlConn, 'AnatomyFile', sAnatFiles(ix));
            end
            % If requested get all the inserted AnatomyFiles
            if nargout > 0
                varargout{1} = db_get(sqlConn, 'AnatomyFile', insertedIds);
            end
        end


%% ==== STUDY ====
    % Success          = db_set('Study', 'Delete')
    %                  = db_set('Study', 'Delete', StudyId)
    %                  = db_set('Study', 'Delete', CondQuery)
    % [StudyId, Study] = db_set('Study', Study)
    %                  = db_set('Study', Study, StudyId)
    case 'Study'
        % Default parameters
        iStudy = [];
        varargout{1} = [];

        if length(args) < 1
            error('Error in number of arguments')
        end

        sStudy = args{1};
        if length(args) > 1
            iStudy = args{2};
        end
        % Delete
        if ischar(sStudy) && strcmpi(sStudy, 'delete')
            if isempty(iStudy)
                % Delete all rows in Study table
                delResult = sql_query(sqlConn, 'DELETE', 'Study');
                % Reset auto-increment
                sql_query(sqlConn, 'RESET-AUTOINCREMENT', 'Study');
            else
                if isstruct(iStudy)
                    % Delete using the CondQuery
                    delResult = sql_query(sqlConn, 'DELETE', 'Study', iStudy);
                elseif isnumeric(iStudy)
                    % Delete using iStudy
                    delResult = sql_query(sqlConn, 'DELETE', 'Study', struct('Id', iStudy));
                end
            end
            if delResult > 0
                varargout{1} = 1;
            end

        % Insert or Update
        elseif isstruct(sStudy)
            if isempty(iStudy)
                if isempty(sStudy.Subject)
                    % Get ID of parent subject
                    sSubject = db_get(sqlConn, 'Subject', sStudy.BrainStormSubject, 'Id');
                    sStudy.Subject = sSubject.Id;
                end
                % Insert Study row
                sStudy.Id = [];
                iStudy = sql_query(sqlConn, 'INSERT', 'Study', sStudy);
                varargout{1} = iStudy;
            else
                % Update Study row
                if ~isfield(sStudy, 'Id') || isempty(sStudy.Id) || sStudy.Id == iStudy
                    resUpdate = sql_query(sqlConn, 'UPDATE', 'Study', sStudy, struct('Id', iStudy));
                else
                    error('Cannot update Study, Ids do not match');
                end
                if resUpdate>0
                    varargout{1} = iStudy;
                end
            end
            % If requested, get the inserted or updated row
            if nargout > 1
                varargout{2} = db_get(sqlConn, 'study', iStudy);
            end
        else
            % No action
        end


%% ==== FILES WITH STUDY ====
    % Success          = db_set('FilesWithStudy', 'Delete'        , StudyID)
    % sFunctionalFiles = db_set('FilesWithStudy', sFunctionalFiles, StudyID)
    case 'FilesWithStudy'
        sFuncFiles = args{1};
        iStudy = args{2};
        
        % Delete all FunctionalFiles with StudyID
        if ischar(sFuncFiles) && strcmpi(sFuncFiles, 'delete')
            delResult = sql_query(sqlConn, 'DELETE', 'FunctionalFile', struct('Study', iStudy));
            varargout{1} = 1;

        % Insert FunctionalFiles to StudyID
        elseif isstruct(sFuncFiles)
            nFunctionalFiles = length(sFuncFiles);
            insertedIds = zeros(1, nFunctionalFiles);
            for ix = 1 : nFunctionalFiles
                sFuncFiles(ix).Study = iStudy;
                insertedIds(ix) = db_set(sqlConn, 'FunctionalFile', sFuncFiles(ix));
            end
            % If requested get all the inserted FunctionalFiles
            if nargout > 0
                varargout{1} = db_get(sqlConn, 'FunctionalFile', insertedIds);
            end
        end

        
%% ==== FUNCTIONAL FILES ====
    % Success                           = db_set('FunctionalFile', 'Delete')
    %                                   = db_set('FunctionalFile', 'Delete', FunctionalFileId)
    %                                   = db_set('FunctionalFile', 'Delete', CondQuery)
    % FunctionalFileId, FunctionalFile] = db_set('FunctionalFile', FunctionalFile)
    %                                   = db_set('FunctionalFile', FunctionalFile, FunctionalFileId)
    case 'FunctionalFile'
        % Default parameters
        iFuncFile = [];
        varargout{1} = [];

        if length(args) < 1
            error('Error in number of arguments')
        end
        
        sFuncFile = args{1};
        if length(args) > 1
            iFuncFile = args{2};
        end
        % Delete
        if ischar(sFuncFile) && strcmpi(sFuncFile, 'delete')
            if isempty(iFuncFile)
                % Delete all rows in FunctionalFile table
                delResult = sql_query(sqlConn, 'DELETE', 'FunctionalFile');
                % Reset auto-increment
                sql_query(sqlConn, 'RESET-AUTOINCREMENT', 'FunctionalFile');
            else
                if isstruct(iFuncFile)
                    % Delete using the CondQuery
                    delResult = sql_query(sqlConn, 'DELETE', 'FunctionalFile', iFuncFile);
                elseif isnumeric(iFuncFile)
                    % Get Id for parent of FunctionalFile to delete
                    parent = db_get(sqlConn, 'FunctionalFile', iFuncFile, 'ParentFile');
                    % Delete using iFunctionalFile
                    delResult = sql_query(sqlConn, 'DELETE', 'FunctionalFile', struct('Id', iFuncFile));
                    % Reduce the number of children in parent
                    if ~isempty(parent) && ~isempty(parent.ParentFile)
                       db_set(sqlConn, 'ParentCount', parent.ParentFile, '-', 1);
                    end
                end
            end
            if delResult > 0
                varargout{1} = 1;
            end

        % Insert or Update
        elseif isstruct(sFuncFile)
            % Modify UNIX time
            sFuncFile.LastModified = bst_get('CurrentUnixTime');

            % Insert FunctionalFile row
            if isempty(iFuncFile)
                sFuncFile.Id = [];
                switch sFuncFile.Type
                    % If data or matrix, check for 'datalist' and 'matrixlist'
                    case {'data', 'matrix'}
                        typeList = [sFuncFile.Type, 'list'];
                        cleanName = str_remove_parenth(sFuncFile.Name);
                        list = sql_query(sqlConn, 'SELECT', 'FunctionalFile', ...
                               struct('Name', cleanName, 'Study', sFuncFile.Study), ...;
                               'Id', ['AND Type = "' typeList '"']);
                        if ~isempty(list)
                            sFuncFile.ParentFile = list.Id;
                        end
                    % Check for parent files
                    case {'dipoles', 'result', 'results', 'timefreq'}
                        if ~isempty(sFuncFile.ExtraStr1) % Parent FileName
                            % Search parent in database (ignore 'datalist' and 'matrixlist' FunctionalFiles)
                            parent = sql_query(sqlConn, 'SELECT', 'FunctionalFile', ...
                                     struct('FileName', sFuncFile.ExtraStr1), ...
                                     'Id', 'AND Type <> "datalist" AND Type <> "matrixlist"');
                            if ~isempty(parent)
                                sFuncFile.ParentFile = parent.Id;
                            end
                        end
                    % Other types
                    otherwise
                        % Do nothing
                end
                iFuncFile = sql_query(sqlConn, 'INSERT', 'FunctionalFile', sFuncFile);
                varargout{1} = iFuncFile;
                % Increase the number of children in parent or list
                if ~isempty(sFuncFile.ParentFile) && sFuncFile.ParentFile > 0
                   db_set(sqlConn, 'ParentCount', sFuncFile.ParentFile, '+', 1);
                end

            % Update iFunctionalFile row
            else
                if ~isfield(sFuncFile, 'Id') || isempty(sFuncFile.Id) || sFuncFile.Id == iFuncFile
                    resUpdate = sql_query(sqlConn, 'UPDATE', 'FunctionalFile', sFuncFile, struct('Id', iFuncFile));
                else
                    error('Cannot update FunctionalFile, Ids do not match');
                end
                if resUpdate > 0
                    varargout{1} = iFuncFile;
                end
            end
            % If requested, get the inserted or updated row
            if nargout > 1
                varargout{2} = db_get(sqlConn, 'FunctionalFile', iFuncFile);
            end
        else
            % No action
        end


%% ==== PARENT COUNT ====       
    % db_set('ParentCount', ParentFile, modifier, count)
    case 'ParentCount'
        iFile = args{1};
        modifier = args{2};
        count = args{3};
        
        qry = 'UPDATE FunctionalFile SET NumChildren = ';
        
        switch modifier
            case '+'
                qry = [qry 'NumChildren + ' num2str(count)];
            case '-'
                qry = [qry 'NumChildren - ' num2str(count)];
            case '='
                qry = num2str(count);
            otherwise
                error('Unsupported call.');
        end
        
        sql_query(sqlConn, [qry ' WHERE Id = ' num2str(iFile)]);

%% ==== ERROR ====      
    otherwise
        error('Invalid context : "%s"', contextName);
end
catch ME
    % Close SQL connection if error
    sql_close(sqlConn);
    rethrow(ME)
end

% Close SQL connection if it was created
if handleConn
    sql_close(sqlConn);
end

end
