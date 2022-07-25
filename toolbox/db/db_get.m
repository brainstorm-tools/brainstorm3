function varargout = db_get(varargin)
% DB_GET: Get a Brainstorm structure from the protocol database
% This function is a newer API than bst_get
% 
% USAGE :
%    - db_get(contextName) or 
%    - db_get(sqlConn, contextName)
%
% ====== PROTOCOLS =====================================================================
%
%
% ====== SUBJECTS ======================================================================
%    - db_get('Subject', SubjectIDs,         Fields, isRaw) : Get Subject(s) by ID(s)
%    - db_get('Subject', SubjectFileNames,   Fields, isRaw) : Get Subject(s) by FileName(s)
%    - db_get('Subject', CondQuery,          Fields, isRaw) : Get Subject(s) with a Query struct
%    - db_get('Subject', '@default_subject', Fields)        : Get default Subject
%    - db_get('Subject')                                    : Get current Subject in current protocol
%    - db_get('Subjects')                                   : Get all Subjects in current protocol, exclude @default_subject
%    - db_get('Subjects', 0, Fields)                        : Get all Subjects in current protocol, exclude @default_subject
%    - db_get('Subjects', 1, Fields)                        : Get all Subjects in current protocol, include @default_subject
%    - db_get('SubjectCount')                               : Get number of subjects in current protocol, exclude @default_subject
%    - db_get('SubjectFromStudy', StudyID, SubjectFields)       : Find SubjectID for StudyID
%    - db_get('SubjectFromStudy', StudyFileName, SubjectFields) : Find SubjectID for StudyFileName
%    - db_get('SubjectFromFunctionalFile', FileId, SubjectFields)   : Find Subject for FunctionalFile with FileID
%    - db_get('SubjectFromFunctionalFile', FileName, SubjectFields) : Find Subject for FunctionalFile with FileName
%
% ====== ANATOMY FILES =================================================================
%    - db_get('FilesWithSubject', SubjectID, AnatomyFileType, Fields) : Get AnatomyFiles for SubjectID
%    - db_get('AnatomyFile', FileIDs,   Fields) : Find AnatomyFile(s) by ID(s)
%    - db_get('AnatomyFile', FileNames, Fields) : Find AnatomyFile(s) by FileName(s)
%    - db_get('AnatomyFile', CondQuery, Fields) : Find AnatomyFile(s) with a Query
%
% ====== STUDIES =======================================================================
%    - db_get('StudiesFromSubject', SubjectID,   Fields, 'intra_subject', 'default_study') : Find Studies for Subject with SubjectID (with intra_subject and default_study)
%    - db_get('StudiesFromSubject', SubjectID,   Fields)     : Find Studies for Subject with SubjectID (w/o intra_subject study and default_study)
%    - db_get('StudiesFromSubject', SubjectFileName, Fields) : Find Studies for Subject with SubjectFileName (w/o intra_subject study and default_study)
%    - db_get('StudiesFromSubject', SubjectName, Fields)     : Find Studies for Subject with SubjectName (w/o intra_subject study and default_study)
%    - db_get('DefaultStudy', SubjectID,       Fields) : Get default study for SubjectID
%    - db_get('DefaultStudy', SubjectFileName, Fields) : Get default study for SubjectFileName
%    - db_get('DefaultStudy', CondQuery,       Fields) : Get default study for CondQuery
%    - db_get('Study', StudyIDs,         Fields) : Get study(s) by ID(s)
%    - db_get('Study', StudyFileNames,   Fields) : Get study(s) by FileName(s)
%    - db_get('Study', CondQuery,        Fields) : Get study(s) with a Query
%    - db_get('Study', '@inter',         Fields) : Get @inter study
%    - db_get('Study', '@default_study', Fields) : Get global @default_study study
%    - db_get('Study');                          : Get current study in current protocol
%    - db_get('Studies')             : Get all studies in current protocol, exclude @inter and global @default_study
%    - db_get('Studies', 0, Fields)  : Get all studies in current protocol, exclude @inter and global @default_study
%    - db_get('Studies', 1, Fields)  : Get all studies in current protocol, include @inter and global @default_study
%
% ====== FUNCTIONAL FILES ==============================================================
%    - db_get('FilesWithStudy', StudyID, FunctionalFileType, Fields) : Get FunctionalFiles for StudyID
%    - db_get('FunctionalFile', FileIDs,   Fields) : Get FunctionalFile(s) by ID(s)
%    - db_get('FunctionalFile', FileNames, Fields) : Get FunctionalFile(s) by FileName(s)
%    - db_get('FunctionalFile', CondQuery, Fields) : Get FunctionalFile(s) with a Query
%    - db_get('ChannelFromStudy', StudyID)       : Find current Channel for StudyID
%    - db_get('ChannelFromStudy', StudyFileName) : Find current Channel for StudyFileName
%    - db_get('ChannelFromStudy', CondQuery)     : Find current Channel for Query struct
%
% SEE ALSO db_set
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
global GlobalData;
if (nargin > 1) && isjava(varargin{1})
    sqlConn = varargin{1};
    varargin(1) = [];
    handleConn = 0;
elseif (nargin >= 1) && ischar(varargin{1}) 
    sqlConn = sql_connect();
    handleConn = 1;
else
    error(['Usage : db_get(contextName) ' 10 '        db_get(sqlConn, contextName)']);
end

try
contextName = varargin{1};
args = {};
if length(varargin) > 1
    args = varargin(2:end);
end
varargout = {};
    
% Get required context structure
switch contextName
%% ==== SUBJECT ====
    % sSubject = db_get('Subject', SubjectIDs,         Fields, isRaw);
    %          = db_get('Subject', SubjectFileNames,   Fields, isRaw);
    %          = db_get('Subject', CondQuery,          Fields, isRaw);
    %          = db_get('Subject', '@default_subject', Fields);    
    %          = db_get('Subject');
    % If isRaw is set: force to return the real brainstormsubject description
    % (ignoring whether it uses protocol's default anatomy or not)    
    case 'Subject'
        % Default parameters
        fields = '*';   
        isRaw = 0;
        templateStruct = db_template('Subject');     
        resultStruct = templateStruct; 

        % Parse first parameter
        if isempty(args)
           ProtocolInfo = bst_get('ProtocolInfo');
           iSubjects = ProtocolInfo.iSubject;
        else
           iSubjects = args{1};
        end
        % SubjectFileNames and CondQuery cases
        if ischar(iSubjects)
            if strcmp(iSubjects, '@default_subject')
                iSubjects = struct('Name', iSubjects);
                condQuery = iSubjects;           
            else
                iSubjects = {iSubjects};
            end
        elseif isstruct(iSubjects)
            condQuery = args{1};           
        end
        
        % Parse Fields parameter
        if length(args) > 1
            fields = args{2};
            if ~strcmp(fields, '*')
                if ischar(fields)
                    fields = {fields};
                end
                % Verify requested fields
                if ~all(isfield(templateStruct, fields))
                    error('Invalid Fields requested in db_get()');
                else
                    resultStruct = [];
                    for i = 1 : length(fields)
                        resultStruct.(fields{i}) = templateStruct.(fields{i});
                    end
                end
            end
        end            
        
        % isRaw parameter
        if length(args) > 2
            isRaw = args{3};
        end
        
        % Input is SubjectIDs or SubjectFileNames
        if ~isstruct(iSubjects)
            nSubjects = length(iSubjects);
            sSubjects = repmat(resultStruct, 1, nSubjects);
            for i = 1:nSubjects
                if iscell(iSubjects)
                    condQuery.FileName = iSubjects{i};
                else
                    condQuery.Id = iSubjects(i);
                end
                result = sql_query(sqlConn, 'SELECT', 'Subject', condQuery, fields);
                if isempty(result)
                    if isfield(condQuery, 'FileName')
                        entryStr = ['FileName "', iSubjects{i}, '"'];
                    else
                        entryStr = ['Id "', num2str(iSubjects(i)), '"'];
                    end
                    error(['Subject with ', entryStr, ' was not found in database.']);
                end
                sSubjects(i) = result;
            end
        else % Input is struct query
            sSubjects = sql_query(sqlConn, 'SELECT', 'Subject', condQuery(1), fields);
        end

        % Retrieve default subject if needed
        if ~isRaw && isequal(fields, '*') && any(find([sSubjects.UseDefaultAnat]))
            iDefaultSubject = find(ismember({sSubjects.Name}, '@default_subject'));
            if iDefaultSubject
                sDefaultSubject = sSubjects(iDefaultSubject);
            else
                sDefaultSubject = db_get(sqlConn, 'Subject', struct('Name', '@default_subject'));
            end
            % Update fields in Subjects using default Anatomy
            if ~isempty(sDefaultSubject)
                for i = 1:length(sSubjects)
                    if sSubjects(i).UseDefaultAnat 
                        tmp = sDefaultSubject;
                        tmp.Id                = sSubjects(i).Id;
                        tmp.Name              = sSubjects(i).Name;
                        tmp.UseDefaultAnat    = sSubjects(i).UseDefaultAnat;
                        tmp.UseDefaultChannel = sSubjects(i).UseDefaultChannel;
                        sSubjects(i) = tmp;                   
                    end    
                end
            end
        end

        varargout{1} = sSubjects;   
        

%% ==== SUBJECTS ====
    % sSubjects = db_get('Subjects');            % Exclude @default_subject
    %           = db_get('Subjects', 0, Fields); % Include @default_subject
    %           = db_get('Subjects', 1, Fields); % Include @default_subject
    case 'Subjects'
        includeDefaultSub = [];
        fields = '*';
        % Parse arguments
        if length(args) > 0
            includeDefaultSub = args{1};
            if length(args) > 1
                fields = args{2};
            end
        end

        % Exclude global studies if indicated
        addQuery = '';
        if isempty(includeDefaultSub) || (includeDefaultSub == 0)
            addQuery = 'AND Name <> "@default_subject"';
        end

        varargout{1} = sql_query(sqlConn, 'SELECT', 'Subject', [], fields, addQuery);


%% ==== SUBJECTS COUNT ====
    % nSubjects = db_get('SubjectCount')
    case 'SubjectCount'
        varargout{1} = sql_query(sqlConn, 'COUNT', 'Subject', [], [], 'AND Name <> "@default_subject"');


%% ==== FILES WITH SUBJECT ====
    % sAnatomyFiles = db_get('FilesWithSubject', SubjectID, AnatomyFileType, Fields)
    %               = db_get('FilesWithSubject', SubjectID, AnatomyFileType)
    %               = db_get('FilesWithSubject', SubjectID)
    case 'FilesWithSubject'
        condQuery.Subject = args{1};
        fields = '*';
        if length(args) > 1 
            condQuery.Type = lower(args{2});
            if length(args) > 2
                fields = args{3};
            end
        end
        varargout{1} = db_get(sqlConn, 'AnatomyFile', condQuery, fields);


%% ==== FILES WITH STUDY ====
    % sFunctionalFiles = db_get('FilesWithStudy', StudyID, FunctionalFileType, Fields)
    %                  = db_get('FilesWithStudy', StudyID, FunctionalFileType)
    %                  = db_get('FilesWithStudy', StudyID)
    case 'FilesWithStudy'
        condQuery.Study = args{1};
        fields = '*';
        if length(args) > 1
            condQuery.Type = lower(args{2});
            if length(args) > 2
                fields = args{3};
            end
        end
        varargout{1} = db_get(sqlConn, 'FunctionalFile', condQuery, fields);


%% ==== ANATOMY FILE ====
    % sAnatomyFiles = db_get('AnatomyFile', FileIDs,   Fields)
    %               = db_get('AnatomyFile', FileNames, Fields)
    %               = db_get('AnatomyFile', CondQuery, Fields)
    case 'AnatomyFile'
        % Parse inputs
        iFiles = args{1};
        fields = '*';                              
        templateStruct = db_template('AnatomyFile');
        resultStruct = templateStruct; 
        
        if ischar(iFiles)
            iFiles = {iFiles};
        elseif isstruct(iFiles)
            condQuery = args{1};           
        end

        % Parse Fields parameter
        if length(args) > 1
            fields = args{2};
            if ~strcmp(fields, '*')
                if ischar(fields)
                    fields = {fields};
                end
                % Verify requested fields
                if ~all(isfield(templateStruct, fields))
                    error('Invalid Fields requested in db_get()');
                else
                    resultStruct = [];
                    for i = 1 : length(fields)
                        resultStruct.(fields{i}) = templateStruct.(fields{i});
                    end
                end
            end
        end         

        % Input is FileIDs and FileNames
        if ~isstruct(iFiles)
            nFiles = length(iFiles);
            sFiles = repmat(resultStruct, 1, nFiles);
            for i = 1:nFiles
                if iscell(iFiles)
                    condQuery.FileName = iFiles{i};
                else
                    condQuery.Id = iFiles(i);
                end
                result = sql_query(sqlConn, 'SELECT', 'AnatomyFile', condQuery, fields);
                if isempty(result)
                    if isfield(condQuery, 'FileName')
                        entryStr = ['FileName "', iFiles{i}, '"'];
                    else
                        entryStr = ['Id "', num2str(iFiles(i)), '"'];
                    end
                    error(['AnatomyFile with ', entryStr, ' was not found in database.']);
                end
                sFiles(i) = result;            
            end
        else % Input is struct query
            sFiles = sql_query(sqlConn, 'SELECT', 'AnatomyFile', condQuery(1), fields);
        end   
        varargout{1} = sFiles;
          
        
%% ==== FUNCTIONAL FILE ====
    % sFunctionalFiles = db_get('FunctionalFile', FileIDs,   Fields)
    %                  = db_get('FunctionalFile', FileNames, Fields)
    %                  = db_get('FunctionalFile', CondQuery, Fields)
    case 'FunctionalFile'
        % Parse inputs
        iFiles = args{1};
        fields = '*';                              
        templateStruct = db_template('FunctionalFile');
        resultStruct = templateStruct;

        if ischar(iFiles)
            iFiles = {iFiles};
        elseif isstruct(iFiles)
            condQuery = args{1};           
        end

        % Parse Fields parameter
        if length(args) > 1
            fields = args{2};
            if ~strcmp(fields, '*')
                if ischar(fields)
                    fields = {fields};
                end
                % Verify requested fields
                if ~all(isfield(templateStruct, fields))
                    error('Invalid Fields requested in db_get()');
                else
                    resultStruct = [];
                    for i = 1 : length(fields)
                        resultStruct.(fields{i}) = templateStruct.(fields{i});
                    end
                end
            end
        end         

        % Input is FileIDs and FileNames
        if ~isstruct(iFiles)
            nFiles = length(iFiles);
            sFiles = repmat(resultStruct, 1, nFiles);
            for i = 1:nFiles
                if iscell(iFiles)
                    condQuery.FileName = iFiles{i};
                else
                    condQuery.Id = iFiles(i);
                end
                result = sql_query(sqlConn, 'SELECT', 'FunctionalFile', condQuery, fields);
                if isempty(result)
                    if isfield(condQuery, 'FileName')
                        entryStr = ['FileName "', iFiles{i}, '"'];
                    else
                        entryStr = ['Id "', num2str(iFiles(i)), '"'];
                    end
                    error(['FunctionalFile with ', entryStr, ' was not found in database.']);
                end
                sFiles(i) = result;  
            end
        else % Input is struct query
            sFiles = sql_query(sqlConn, 'SELECT', 'FunctionalFile', condQuery(1), fields);
        end
        varargout{1} = sFiles;


%% ==== SUBJECT FROM STUDY ====
    % sSubject = db_get('SubjectFromStudy', StudyID,       SubjectFields)
    %          = db_get('SubjectFromStudy', StudyFileName, SubjectFields)
    case 'SubjectFromStudy'
        fields = '*';
        varargout{1} = [];
        if length(args) > 1
            fields = args{2};
        end
        if ischar(fields), fields = {fields}; end
        % Prepend 'Subject.' to requested fields
        if ~strcmp('*', fields{1})
            fields = cellfun(@(x) ['Subject.' x], fields, 'UniformOutput', 0);
        end
        % Join query
        joinQry = 'Subject LEFT JOIN Study ON Subject.Id = Study.Subject';
        % Add query
        addQuery = 'AND Study.';
        % Complete query with FileName of FileID
        if ischar(args{1})
            addQuery = [addQuery 'FileName = "' args{1} '"'];
        else
            addQuery = [addQuery 'Id = ' num2str(args{1})];
        end
        % Select query
        varargout{1} = sql_query(sqlConn, 'SELECT', joinQry, [], fields, addQuery);


%% ==== CHANNEL FROM STUDY ====
    % [iFile, iStudy] = db_get('ChannelFromStudy', StudyID)
    %                 = db_get('ChannelFromStudy', StudyFileName)
    %                 = db_get('ChannelFromStudy', CondQuery)
    case 'ChannelFromStudy'
        iStudy = args{1};
        varargout{1} = [];
        varargout{2} = [];
        
        sStudy = db_get(sqlConn, 'Study', iStudy, {'Id', 'Subject', 'Name', 'iChannel'});
        if ~isempty(sStudy)
            iChanStudy = iStudy;
            % === Analysis-Inter node ===
            if strcmpi(sStudy.Name, '@inter')
                % If no channel file is defined in 'Analysis-intra' node: look in 
                if isempty(sStudy.iChannel)
                    % Get global default study
                    sStudy = db_get(sqlConn, 'DefaultStudy', '@default_subject', {'Id', 'Subject', 'iChannel'});
                    iChanStudy = sStudy.Id;
                end
            % === All other nodes ===
            else
                % Get subject attached to study
                sSubject = db_get(sqlConn, 'Subject', sStudy.Subject, 'UseDefaultChannel');
                % Subject uses default channel/headmodel
                if ~isempty(sSubject) && (sSubject.UseDefaultChannel ~= 0)
                    sStudy = db_get(sqlConn, 'DefaultStudy', sStudy.Subject, {'Id', 'iChannel'});
                    if ~isempty(sStudy)
                        iChanStudy = sStudy.Id;
                    end
                end
            end

            if ~isempty(sStudy)
                % If no channel selected, find first channel in study
                if isempty(sStudy.iChannel)
                    sFuncFile = db_get(sqlConn, 'FunctionalFile', struct('Study', sStudy.Id, 'Type', 'channel'), 'Id');
                    if ~isempty(sFuncFile)
                        sStudy.iChannel = sFuncFile(1).Id;
                    end
                end

                if ~isempty(sStudy.iChannel)
                    varargout{1} = sStudy.iChannel;
                    varargout{2} = iChanStudy;
                end
            end
        end


%% ==== STUDIES FROM SUBJECT ====        
    % sStudies = db_get('StudiesFromSubject', iSubject,        Fields)                                   % Exclude 'intra_subject' study and 'default_study')
    %          = db_get('StudiesFromSubject', iSubject,        Fields, 'intra_subject', 'default_study') % Include 'intra_subject' study and 'default_study')
    %          = db_get('StudiesFromSubject', SubjectFileName, Fields)
    %          = db_get('StudiesFromSubject', SubjectName,     Fields)
    case 'StudiesFromSubject'
        fields = '*';
        varargout{1} = [];
        if length(args) > 1
            fields = args{2};
        end
        if ischar(fields), fields = {fields}; end
        % Prepend 'Study.' to requested fields
        if ~strcmp('*', fields{1})
            fields = cellfun(@(x) ['Study.' x], fields, 'UniformOutput', 0);
        end
        % Join query
        joinQry = 'Study LEFT JOIN Subject On Study.Subject = Subject.Id';
        % Add query
        addQuery = 'AND Subject.';
        % Complete query with FileName of FileID
        if ischar(args{1})
            [~, ~, fExt] = bst_fileparts(args{1});
            % Argument is not a Matlab .mat filename, assume it is a directory
            if ~strcmpi(fExt, '.mat')
                args{1} = bst_fullfile(file_standardize(args{1}), 'brainstormsubject.mat');
            end
            addQuery = [addQuery 'FileName = "' args{1} '"'];
        else
            addQuery = [addQuery 'Id = ' num2str(args{1})];
        end
        % Complete query with studies ("intra_subject" and "default_study") to exclude
        if length(args) < 2 || ~ismember('intra_subject', args(2:end))
            addQuery = [addQuery ' AND Study.Name <> "' bst_get('DirAnalysisIntra') '"'];
        end
        if length(args) < 2 || ~ismember('default_study', args(2:end))
            addQuery = [addQuery ' AND Study.Name <> "' bst_get('DirDefaultStudy') '"'];
        end
        % Select query
        varargout{1} = sql_query(sqlConn, 'SELECT', joinQry, [], fields, addQuery);


%% ==== DEFAULT STUDY ====       
    % sStudy = db_get('DefaultStudy', SubjectID,       Fields)
    %        = db_get('DefaultStudy', SubjectFileName, Fields)
    %        = db_get('DefaultStudy', CondQuery,       Fields)
    case 'DefaultStudy'
        fields = '*';
        iSubject = args{1};
        varargout{1} = [];
        if length(args) > 1
            fields = args{2};
        end
        defaultStudy = bst_get('DirDefaultStudy');
        % Get Subject
        sSubject = db_get(sqlConn, 'Subject', iSubject, {'Id', 'UseDefaultChannel'});
        % If UseDefaultChannel get default Subject
        if sSubject.UseDefaultChannel == 1
            sSubject = db_get('Subject', '@default_subject', 'Id');
        end
        sStudy = db_get(sqlConn, 'Study', struct('Subject', sSubject.Id, 'Name', defaultStudy), fields);
        if ~isempty(sStudy)
            varargout{1} = sStudy;
        end


%% ==== STUDY ====   
    % sStudy = db_get('Study', StudyIDs,         Fields);
    %        = db_get('Study', StudyFileNames,   Fields);
    %        = db_get('Study', CondQuery,        Fields);
    %        = db_get('Study', '@inter',         Fields);
    %        = db_get('Study', '@default_study', Fields);
    %        = db_get('Study');
    case 'Study'
        % Default parameters
        fields = '*';
        templateStruct = db_template('Study');
        resultStruct = templateStruct;

        % Parse first parameter
        if isempty(args)
           ProtocolInfo = bst_get('ProtocolInfo');
           iStudies = ProtocolInfo.iStudy;
        else
           iStudies = args{1};
        end
        % StudyFileNames and CondQuery cases
        if ischar(iStudies)
            if strcmp(iStudies, '@inter')
                iStudies = struct('Name', iStudies);
                condQuery = iStudies;
            elseif strcmp(iStudies, '@default_study')
                sSubject = db_get(sqlConn, 'Subject', '@default_subject', 'Id');
                iStudies = struct('Name', iStudies, 'Subject', sSubject.Id);
                condQuery = iStudies;
            else
                iStudies = {iStudies};
            end
        elseif isstruct(iStudies)
            condQuery = args{1};
        end

        % Parse Fields parameter
        if length(args) > 1
            fields = args{2};
            if ~strcmp(fields, '*')
                if ischar(fields)
                    fields = {fields};
                end
                % Verify requested fields
                if ~all(isfield(templateStruct, fields))
                    error('Invalid Fields requested in db_get()');
                else
                    resultStruct = [];
                    for i = 1 : length(fields)
                        resultStruct.(fields{i}) = templateStruct.(fields{i});
                    end
                end
            end
        end

        % Input is StudyIDs or StudyFileNames
        if ~isstruct(iStudies)
            sStudies = repmat(resultStruct, 0);
            for i = 1:length(iStudies)
                if iscell(iStudies)
                    condQuery.FileName = iStudies{i};
                else
                    condQuery.Id = iStudies(i);
                end
                result = sql_query(sqlConn, 'SELECT', 'Study', condQuery, fields);
                if isempty(result)
                    if isfield(condQuery, 'FileName')
                        entryStr = ['FileName "', iStudies{i}, '"'];
                    else
                        entryStr = ['Id "', num2str(iStudies(i)), '"'];
                    end
                    warning(['Study with ', entryStr, ' was not found in database.']);
                else
                    sStudies(i) = result;
                end
            end
        else % Input is struct query
            sStudies = sql_query(sqlConn, 'SELECT', 'Study', condQuery(1), fields);
        end
        varargout{1} = sStudies;


%% ==== STUDIES ====              
    % sStudy = db_get('Studies')             % Exclude @inter and global @default_study
    %        = db_get('Studies', 0, Fields)  % Exclude @inter and global @default_study
    %        = db_get('Studies', 1, Fields)  % Include @inter and global @default_study
    case 'Studies'
        includeGlobalStudies  = [];
        fields = '*';
        % Parse arguments
        if length(args) > 0
            includeGlobalStudies = args{1};
            if length(args) > 1
                fields = args{2};
            end
        end
        % Exclude global studies if indicated
        addQuery = '';
        if isempty(includeGlobalStudies) || (includeGlobalStudies == 0)
            addQuery = 'AND Name <> "@inter" AND (Subject <> 0 OR Name <> "@default_study")';
        end
        
        varargout{1} = sql_query(sqlConn, 'SELECT', 'Study', [], fields, addQuery);


%% ==== SUBJECT FROM FUNCTIONAL FILE ====              
    % sSubject = db_get('SubjectFromFunctionalFile', FileId,   SubjectFields)
    %          = db_get('SubjectFromFunctionalFile', FileName, SubjectFields)
    case 'SubjectFromFunctionalFile'
        fields = '*';
        varargout{1} = [];
        if length(args) > 1
            fields = args{2};
        end
        if ischar(fields), fields = {fields}; end
        % Prepend 'Subject.' to requested fields
        if ~strcmp('*', fields{1})
            fields = cellfun(@(x) ['Subject.' x], fields, 'UniformOutput', 0);
        end
        % Join query
        joinQry = ['Subject LEFT JOIN Study ON Subject.Id = Study.Subject ' ...
                   'LEFT JOIN FunctionalFile ON Study.Id = FunctionalFile.Study'];
        % Add query
        addQuery = 'AND FunctionalFile.';
        % Complete query with FileName of FileID
        if ischar(args{1})
            addQuery = [addQuery 'FileName = "' args{1} '"'];
        else
            addQuery = [addQuery 'Id = ' num2str(args{1})];
        end
        % Select query
        varargout{1} = sql_query(sqlConn, 'SELECT', joinQry, [], fields, addQuery);


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
