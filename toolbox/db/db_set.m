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
%
%
% ====== STUDIES =======================================================================
%
%
% ====== ANATOMY AND FUNCTIONAL FILES ==================================================
%    - db_set('FilesWithSubject', FileType, db_template('anatomy/surface'), SubjectID, selectedAnat/Surf)
%    - db_set('FilesWithStudy', FileType, db_template('data/timefreq/etc'), StudyID)
%    - db_set('FilesWithStudy', sStudy, [selectedChannel/HeadModel])
%    - db_set('FunctionalFile', 'insert', db_template('FunctionalFile'))
%    - db_set('FunctionalFile', 'update', db_template('FunctionalFile'), struct('Id', 1))
%    - db_set('ParentCount', ParentFile, modifier, count)    
%
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
    % [Success]              db_set('Subject', 'Delete')
    % [Success]              db_set('Subject', 'Delete', SubjectId)
    % [Success]              db_set('Subject', 'Delete', CondQuery)
    % [SubjectId, Subject] = db_set('Subject', Subject)
    % [SubjectId, Subject] = db_set('Subject', Subject, SubjectId)
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
                delResult = sql_query(sqlConn, 'delete', 'subject');
            else
                if isstruct(iSubject)
                    % Delete using the CondQuery
                    delResult = sql_query(sqlConn, 'delete', 'subject', iSubject);                    
                elseif isnumeric(iSubject)
                    % Delete using iSubject
                    delResult = sql_query(sqlConn, 'delete', 'subject', struct('Id', iSubject));  
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
                iSubject = sql_query(sqlConn, 'insert', 'subject', sSubject);
                varargout{1} = iSubject;
            else
                % Update Subject row
                if ~isfield(sSubject, 'Id') || isempty(sSubject.Id) || sSubject.Id == iSubject
                    resUpdate = sql_query(sqlConn, 'update', 'subject', sSubject, struct('Id', iSubject));
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
    % [Success]                      db_set('AnatomyFile', 'Delete')
    % [Success]                      db_set('AnatomyFile', 'Delete', AnatomyFileId)
    % [Success]                      db_set('AnatomyFile', 'Delete', CondQuery)
    % [AnatomyFileId, AnatomyFile] = db_set('AnatomyFile', AnatomyFile)
    % [AnatomyFileId, AnatomyFile] = db_set('AnatomyFile', AnatomyFile, AnatomyFileId)
    case 'AnatomyFile'
        % Default parameters
        iAnatomyFile = [];       
        varargout{1} = [];
        
        if length(args) < 1
            error('Error in number of arguments')
        end
        
        sAnatomyFile = args{1};
        if length(args) > 1
            iAnatomyFile = args{2};
        end
        % Delete 
        if ischar(sAnatomyFile) && strcmpi(sAnatomyFile, 'delete')
            if isempty(iAnatomyFile)
                % Delete all rows in AnatomyFile table
                delResult = sql_query(sqlConn, 'delete', 'anatomyfile');
            else
                if isstruct(iAnatomyFile)
                    % Delete using the CondQuery
                    delResult = sql_query(sqlConn, 'delete', 'anatomyfile', iAnatomyFile);                    
                elseif isnumeric(iAnatomyFile)
                    % Delete using iAnatomyFile
                    delResult = sql_query(sqlConn, 'delete', 'anatomyfile', struct('Id', iAnatomyFile));  
                end
            end
            if delResult > 0
                varargout{1} = 1;
            end
            
        % Insert or Update    
        elseif isstruct(sAnatomyFile)
            if isempty(iAnatomyFile)
                % Insert AnatomyFile row
                sAnatomyFile.Id = []; 
                iAnatomyFile = sql_query(sqlConn, 'insert', 'anatomyfile', sAnatomyFile);
                varargout{1} = iAnatomyFile;
            else
                % Update iAnatomyFile row
                if ~isfield(sAnatomyFile, 'Id') || isempty(sAnatomyFile.Id) || sAnatomyFile.Id == iAnatomyFile
                    resUpdate = sql_query(sqlConn, 'update', 'anatomyfile', sAnatomyFile, struct('Id', iAnatomyFile));
                else
                    error('Cannot update AnatomyFile, Ids do not match');
                end
                if resUpdate>0
                    varargout{1} = iAnatomyFile;
                end
            end
            % If requested, get the inserted or updated row
            if nargout > 1
                varargout{2} = db_get(sqlConn, 'AnatomyFile', iAnatomyFile);
            end
        else
            % No action
        end
        
    
%% ==== FILES WITH SUBJECT ====
    % [sAnatomyFiles, iSelected] = db_set('FilesWithSubject', sAnatomyFiles, SubjectID, iSelected)
    case 'FilesWithSubject'
        sAnatomyFiles = args{1};
        iSubject = args{2};
        nAnatomyFiles = length(sAnatomyFiles);
        if length(args) > 2
            if iscell(args{3})
                selFile = args{3};
            else
                selFile = args(3);
            end
            varargout{2} = cell(1, length(selFile));
        else
            selFile = [];
        end

        if nargout > 0
            varargout{1} = repmat(db_template('AnatomyFile'), 1, nAnatomyFiles);
        end
        
        for iAnatomyFile = 1 : nAnatomyFiles
            sAnatomyFile = sAnatomyFiles(iAnatomyFile);
            sAnatomyFile.Subject = iSubject;
            insertedId = db_set(sqlConn, 'AnatomyFile', sAnatomyFile);

            if nargout > 0
                sAnatomyFile.Id = insertedId;
                varargout{1}(iAnatomyFile) = sAnatomyFile;

                if ~isempty(selFile)
                    iSel = find(strcmpi(sAnatomyFile.FileName, selFile));
                    if ~isempty(iSel)
                        varargout{2}(iSel) = {sAnatomyFile.Id};
                    end
                end
            end
        end

%% ==== FILES WITH STUDY ====
    % db_set('FilesWithStudy', FileType, db_template('data/timefreq/etc'), StudyID)
    % db_set('FilesWithStudy', sStudy, [selectedChannel/HeadModel])
    case 'FilesWithStudy'
        selFile = [];
        % Special case: db_set('FilesWithStudy', sStudy)
        if length(args) < 3
            sStudy = args{1};
            iStudy = sStudy.Id;
            % Note: Order important here, as potential parent files (Data, Matrix, Result)
            % should be created before potential child files (Result, Timefreq, dipoles).
            types = {'Channel', 'HeadModel', 'Data', 'Matrix', 'Result', ...
                'Stat', 'Image', 'NoiseCov', 'Dipoles', 'Timefreq'};
            % Create structure to save inserted IDs of potential parent files.
            fileIds = struct('filename', [], 'id', [], 'numChildren', 0);
            parentFiles = struct('data', repmat(fileIds, 0), ...
                'matrix', repmat(fileIds, 0), ...
                'result', repmat(fileIds, 0));
            
            % Return IDs of selected files if requested
            if length(args) > 1
                if iscell(args{2})
                    selFile = args{2};
                else
                    selFile = args(2);
                end
                varargout{1} = cell(1, length(selFile));
            end
        else
            types  = {lower(args{1})};
            sFiles = args{2};
            iStudy = args{3};
            sStudy = [];
        end

        for iType = 1:length(types)
            if ~isempty(sStudy)
                sFiles = sStudy.(types{iType});
                type = lower(types{iType});
            else
                type = types{iType};
            end
            
            % Group trials
            if ismember(type, {'data', 'matrix'})
                dataGroups = repmat(struct('name', [], 'parent', [], ...
                    'files', repmat(db_template('FunctionalFile'),0)), 0);
            end

            for iFile = 1:length(sFiles)
                functionalFile = db_template('FunctionalFile');
                functionalFile.Study = iStudy;
                functionalFile.Type = type;
                functionalFile.FileName = sFiles(iFile).FileName;
                functionalFile.Name = sFiles(iFile).Comment;
                
                % Noise and data covariances used to share their type, with
                % 1st one being noise and second one being data.
                if strcmpi(type, 'NoiseCov')
                    if iFile == 1
                        functionalFile.Type = 'noisecov';
                    else
                        functionalFile.Type = 'ndatacov';
                    end
                end

                % Extra fields
                switch type
                    case 'data'
                        functionalFile.SubType  = sFiles(iFile).DataType;
                        functionalFile.ExtraNum = sFiles(iFile).BadTrial;

                    case 'channel'
                        functionalFile.ExtraNum  = sFiles(iFile).nbChannels;
                        functionalFile.ExtraStr1 = str_join(sFiles(iFile).Modalities, ',');
                        functionalFile.ExtraStr2 = str_join(sFiles(iFile).DisplayableSensorTypes, ',');

                    case {'result', 'results'}
                        functionalFile.ExtraStr1  = sFiles(iFile).DataFile;
                        functionalFile.ExtraNum   = sFiles(iFile).isLink;
                        functionalFile.ExtraStr2  = sFiles(iFile).HeadModelType;
                        functionalFile.ParentFile = GetParent('data', sFiles(iFile).DataFile);

                    case 'timefreq'
                        functionalFile.ExtraStr1  = sFiles(iFile).DataFile;
                        functionalFile.ExtraStr2  = sFiles(iFile).DataType;
                        functionalFile.ParentFile = GetParent({'data', 'result', 'matrix'}, sFiles(iFile).DataFile);

                    case 'stat'
                        functionalFile.SubType   = sFiles(iFile).Type;
                        functionalFile.ExtraStr1 = sFiles(iFile).pThreshold;
                        functionalFile.ExtraStr2 = sFiles(iFile).DataFile;

                    case 'headmodel'
                        % Get list of methods and modalities
                        allMods = {'MEG', 'EEG', 'ECOG', 'SEEG'};
                        modalities = {};
                        methods = {};
                        for iMod = 1:length(allMods)
                            field = [allMods{iMod} 'Method'];
                            if ~isempty(sFiles(iFile).(field))
                                modalities{end + 1} = allMods{iMod};
                                methods{end + 1} = sFiles(iFile).(field);
                            end
                        end

                        functionalFile.SubType   = sFiles(iFile).HeadModelType;
                        functionalFile.ExtraStr1 = str_join(modalities, ',');
                        functionalFile.ExtraStr2 = str_join(methods, ',');
                        
                    case 'dipoles'
                        functionalFile.ExtraStr1  = sFiles(iFile).DataFile;
                        functionalFile.ParentFile = GetParent({'result', 'data'}, sFiles(iFile).DataFile);

                    case {'matrix', 'noisecov', 'image'}
                        % Nothing to add

                    otherwise
                        error('Unsupported functional file type');
                end

                % For data trials, do not insert them right away in the 
                % database since we need to group in trial groups first
                if ismember(type, {'data', 'matrix'})
                    comment = str_remove_parenth(functionalFile.Name);
                    iPos = find(strcmp(comment, {dataGroups.name}), 1);
                    if ~isempty(iPos)
                        dataGroups(iPos).files(end + 1) = functionalFile;
                    else
                        dataGroups(end + 1).name = comment;
                        dataGroups(end).files = functionalFile;
                    end
                else
                    FileId = ModifyFunctionalFile(sqlConn, 'insert', functionalFile);
                    if ~isempty(selFile)
                        iSel = find(strcmpi(functionalFile.FileName, selFile));
                        if ~isempty(iSel)
                            varargout{1}(iSel) = {FileId};
                        end
                    end
                    
                    % Save inserted ID if this is a potential parent file
                    if ~isempty(sStudy) && ismember(type, {'data', 'matrix', 'result', 'results'})
                        SaveParent(type, functionalFile.FileName, FileId);
                    end
                end
            end
            
            % Create trial groups
            if ismember(type, {'data', 'matrix'})
                for iGroup = 1:length(dataGroups)
                    nFiles = length(dataGroups(iGroup).files);
                    
                    if nFiles > 4
                        % Insert file for group
                        functionalFile = db_template('FunctionalFile');
                        functionalFile.Study = iStudy;
                        functionalFile.Type = [type 'list'];
                        functionalFile.FileName = dataGroups(iGroup).files(1).FileName;
                        functionalFile.Name = dataGroups(iGroup).name;
                        functionalFile.NumChildren = nFiles;
                        ParentId = ModifyFunctionalFile(sqlConn, 'insert', functionalFile);
                    else
                        ParentId = [];
                    end
                    
                    % Insert trials
                    for iFile = 1:nFiles
                        dataGroups(iGroup).files(iFile).ParentFile = ParentId;
                        FileId = ModifyFunctionalFile(sqlConn, 'insert', dataGroups(iGroup).files(iFile));
                        SaveParent(type, dataGroups(iGroup).files(iFile).FileName, FileId);
                    end
                end
            end
        end
        
        % Update children count of parent files
        fieldTypes = fieldnames(parentFiles);
        for iField = 1:length(fieldTypes)
            for iFile = 1:length(parentFiles.(fieldTypes{iField}))
                if parentFiles.(fieldTypes{iField})(iFile).numChildren > 0
                    ModifyFunctionalFile(sqlConn, 'update', ...
                        struct('NumChildren', parentFiles.(fieldTypes{iField})(iFile).numChildren), ...
                        struct('Id', parentFiles.(fieldTypes{iField})(iFile).id));
                end
            end
        end
        
%% ==== FUNCTIONAL FILE ====       
    % db_set('FunctionalFile', 'insert', db_template('FunctionalFile'))
    % db_set('FunctionalFile', 'update', db_template('FunctionalFile'), struct('Id', 1))
    case 'FunctionalFile'
        queryType = args{1};
        sFile = args{2};
        if length(args) > 2
            updateCondition = args{3};
        else
            updateCondition = [];
        end
        
        varargout{1} = ModifyFunctionalFile(sqlConn, queryType, sFile, updateCondition);

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

%% ==== NESTED HELPERS ====

%
function SaveParent(type, fileName, id)
    if strcmp(type, 'results')
        fieldType = 'result';
    else
        fieldType = type;
    end
    parentFiles.(fieldType)(end + 1).filename = FileStandard(fileName);
    parentFiles.(fieldType)(end).id = id;
    parentFiles.(fieldType)(end).numChildren = 0;
end

% 
function FileId = GetParent(types, fileName)
    FileId = [];
    if isempty(fileName)
        return;
    end
    if ~iscell(types)
        types = {types};
    end
    
    fileName = FileStandard(fileName);
    for iCurType = 1:length(types)
        if strcmp(types{iCurType}, 'results')
            fieldType = 'result';
        else
            fieldType = types{iCurType};
        end
        
        iFound = find(strcmp(fileName, {parentFiles.(fieldType).filename}), 1);
        if ~isempty(iFound)
            FileId = parentFiles.(fieldType)(iFound).id;
            parentFiles.(fieldType)(iFound).numChildren = parentFiles.(fieldType)(iFound).numChildren + 1;
            return;
        end
    end
end
end

%% ==== LOCAL HELPERS ====

% Concatenate strings using delimiter
function outStr = str_join(cellStr, delimiter)
    outStr = '';
    for iCell = 1:length(cellStr)
        if iCell > 1
            outStr = [outStr delimiter];
        end
        outStr = [outStr cellStr{iCell}];
    end
end

% Format FileName
function FileName = FileStandard(FileName)
    % Replace '\' with '/'
    FileName(FileName == '\') = '/';
    % Remove first slash (filenames all relative)
    if (FileName(1) == '/')
        FileName = FileName(2:end);
    end
end

% Set UNIX time when Insert or Update a FunctionalFile
function res = ModifyFunctionalFile(sqlConn, queryType, sFile, updateCondition)
    if nargin < 4
        updateCondition = [];
    end

    sFile.LastModified = bst_get('CurrentUnixTime');
    
    res = sql_query(sqlConn, queryType, 'functionalfile', sFile, updateCondition);
end

