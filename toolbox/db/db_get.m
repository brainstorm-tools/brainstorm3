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
%    - db_get('Subject', SubjectIDs,       Fields, isRaw) : Find subject(s) by ID(s)
%    - db_get('Subject', SubjectFileNames, Fields, isRaw) : Find subject(s) by FileName(s)
%    - db_get('Subject', CondQuery,        Fields, isRaw) : Find subject(s) with a Query
%    - db_get('Subject')                                  : Get current subject in current protocol 
%    - db_get('Subjects')                                 : Get all subjects in current protocol, exclude @default_subject
%    - db_get('Subjects', 0, Fields)                      : Get all subjects in current protocol, exclude @default_subject
%    - db_get('Subjects', 1, Fields)                      : Get all subjects in current protocol, include @default_subject
%    - db_get('SubjectFromStudy', StudyID)                : Find Subject for Study with StudyID  
%    - db_get('SubjectFromFunctionalFile', FileId)        : Find Subject for FunctionalFile with FileID 
%    - db_get('SubjectFromFunctionalFile', FileName)      : Find Subject for FunctionalFile with FileID 
%
% ====== ANATOMY FILES =================================================================
%    - db_get('FilesWithSubject')  :                        :
%    - db_get('AnatomyFile', FileIDs,   Fields) : Find anatomy file(s) by ID(s) 
%    - db_get('AnatomyFile', FileNames, Fields) : Find anatomy file(s) by FileName(s)
%    - db_get('AnatomyFile', CondQuery, Fields) : Find anatomy file(s) with a Query
%
% ====== STUDIES =======================================================================
%    - db_get('StudiesFromSubject', SubjectID,   Fields, 'intra_subject', 'default_study') : Find Studies for Subject with SubjectID (with intra_subject and default_study)
%    - db_get('StudiesFromSubject', SubjectID,   Fields) : Find Studies for Subject with SubjectID (w/o intra_subject and default_study)
%    - db_get('StudiesFromSubject', SubjectName, Fields) : Find Studies for Subject with SubjectName (w/o intra_subject and default_study)
%    - db_get('DefaultStudy', iSubject, Fields)
%    - db_get('Study', StudyIDs,         Fields) : Get study(s) by ID(s)
%    - db_get('Study', StudyFileNames,   Fields) : Get study(s) by FileName(s)
%    - db_get('Study', CondQuery,        Fields) : Get study(s) with a Query
%    - db_get('Study', '@inter',         Fields) : Get @inter study
%    - db_get('Study', '@default_study', Fields) : Get @default_study study
%    - db_get('Study');                          : Get current subject in current protocol
%    - db_get('Studies')             : Get all studies in current protocol, exclude @inter and global @default_study
%    - db_get('Studies', 0, Fields)  : Get all studies in current protocol, exclude @inter and global @default_study
%    - db_get('Studies', 1, Fields)  : Get all studies in current protocol, include @inter and global @default_study
%
% ====== FUNCTIONAL FILES ==============================================================
%    - db_get('FilesWithStudy', StudyID, FunctionalFileType, Fields) Get all functional files for study with ID
%    - db_get('FunctionalFile', FileIDs,   Fields) : Get functional file(s) by ID(s) 
%    - db_get('FunctionalFile', FileNames, Fields) : Get functional file(s) by FileName(s)
%    - db_get('FunctionalFile', CondQuery, Fields) : Get functional file(s) with a Query
%    - db_get('ChannelFromStudy', StudyID) : Find current Channel for Study with StudyID  
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
                result = sql_query(sqlConn, 'select', 'subject', fields, condQuery);
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
            sSubjects = sql_query(sqlConn, 'select', 'subject', fields, condQuery(1));
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
            addQuery = ' WHERE Name <> "@default_subject"';
        end

        varargout{1} = sql_query(sqlConn, 'select', 'Subject', fields, [], addQuery);


%% ==== SUBJECTS COUNT ====
    % nSubjects = db_get('SubjectCount')
    case 'SubjectCount'
        varargout{1} = sql_query(sqlConn, 'count', 'subject', [], 'WHERE Name <> "@default_subject"');


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
                result = sql_query(sqlConn, 'select', 'anatomyfile', fields, condQuery);
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
            sFiles = sql_query(sqlConn, 'select', 'anatomyfile', fields, condQuery(1));
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
                result = sql_query(sqlConn, 'select', 'functionalfile', fields, condQuery);
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
            sFiles = sql_query(sqlConn, 'select', 'functionalfile', fields, condQuery(1));
        end
        varargout{1} = sFiles;


%% ==== SUBJECT FROM STUDY ====
    % iSubject = db_get('SubjectFromStudy', StudyID)
    case 'SubjectFromStudy'
        iStudy = args{1};
        sStudy = db_get(sqlConn, 'Study', iStudy, 'Subject');

        if ~isempty(sStudy)
            iSubject = sStudy.Subject;
        else
            iSubject = [];
        end

        varargout{1} = iSubject;


%% ==== CHANNEL FROM STUDY ====
    % iFile = db_get('ChannelFromStudy', StudyID)
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
                    sStudy = db_get(sqlConn, 'DefaultStudy', 0, {'Id', 'Subject', 'iChannel'});
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
    % sStudies = db_get('StudiesFromSubject', iSubject,    Fields)                                   % Exclude 'intra_subject' and 'default_study')
    %          = db_get('StudiesFromSubject', iSubject,    Fileds, 'intra_subject', 'default_study') % Include 'intra_subject' and 'default_study')
    %          = db_get('StudiesFromSubject', SubjectName, Fields)
    case 'StudiesFromSubject'
        iSubject = args{1};
        fields = '*';
        if length(args) >= 2 && ~strcmp('intra_subject', args{2}) && ~strcmp('default_study', args{2})
            fields = args{2};
            if ~strcmp(fields, '*')
                if ischar(fields)
                    fields = {fields};
                end
            end
        end
        
        addQuery = [];
        if length(args) < 2 || ~ismember('intra_subject', args(2:end))
            addQuery = [' AND Study.Name <> "' bst_get('DirAnalysisIntra') '"'];
        end
        if length(args) < 2 || ~ismember('default_study', args(2:end))
            addQuery = [addQuery ' AND Study.Name <> "' bst_get('DirDefaultStudy') '"'];
        end
        
        % Special case: Subject name rather than ID specified
        if ischar(iSubject)
            result = sql_query(sqlConn, ['SELECT Study.Id AS StudyId FROM Subject ' ...
                'LEFT JOIN Study ON Subject.Id = Study.Subject ' ...
                'WHERE Subject.Name = "' iSubject '"' addQuery]);
            iStudies = [];
            while result.next()
                iStudies(end + 1) = result.getInt('StudyId');
            end
            result.close();
            varargout{1} = iStudies;
        else
            sStudy = sql_query(sqlConn, 'select', 'Study', fields, struct('Subject', iSubject), addQuery);
            if isempty(sStudy)
                varargout{1} = [];
            else
                varargout{1} = sStudy;
            end
        end


%% ==== DEFAULT STUDY ====       
    % sStudy = db_get('DefaultStudy', iSubject, Fields)
    case 'DefaultStudy'
        fields = '*';
        iSubject = args{1};
        varargout{1} = [];
        if length(args) > 1
            fields = args{2};
        end
        defaultStudy = bst_get('DirDefaultStudy');
        
        % === DEFAULT SUBJECT ===
        % => Return global default study
        if iSubject == 0
            % Return Global default study
        % === NORMAL SUBJECT ===
        else
            sSubject = db_get(sqlConn, 'Subject', iSubject, 'UseDefaultChannel');
            % === GLOBAL DEFAULT STUDY ===
            if sSubject.UseDefaultChannel == 2
                % Return Global default study
                iSubject = 0;
            % === SUBJECT'S DEFAULT STUDY ===
            elseif sSubject.UseDefaultChannel == 1
                % Return subject's default study
            end
        end
        
        sStudy = db_get(sqlConn, 'Study', struct('Subject', iSubject, 'Name', defaultStudy), fields);
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
                result = sql_query(sqlConn, 'select', 'study', fields, condQuery);
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
            sStudies = sql_query(sqlConn, 'select', 'study', fields, condQuery(1));
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
            addQuery = 'WHERE Name <> "@inter" AND (Subject <> 0 OR Name <> "@default_study")';
        end
        
        varargout{1} = sql_query(sqlConn, 'select', 'Study', fields, [], addQuery);


%% ==== SUBJECT FROM FUNCTIONAL FILE ====              
    % iSubject = db_get('SubjectFromFunctionalFile', FileId)
    %          = db_get('SubjectFromFunctionalFile', FileName)
    case 'SubjectFromFunctionalFile'
        qry = ['SELECT Subject FROM FunctionalFile ' ...
            'LEFT JOIN Study ON Study.Id = FunctionalFile.Study WHERE FunctionalFile.'];
        if ischar(args{1})
            qry = [qry 'FileName = "' args{1} '"'];
        else
            qry = [qry 'Id = ' num2str(args{1})];
        end
        result = sql_query(sqlConn, qry);
        if result.next()
            varargout{1} = result.getInt('Subject');
        else
            varargout{1} = [];
        end
        result.close();


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
