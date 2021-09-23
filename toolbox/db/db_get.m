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
%    - db_get('Subjects', includeDefault)                 : Get all subjects in current protocol 
%    - db_get('SubjectFromStudy', StudyID)                : Find Subject for Study with StudyID  
%    - db_get('SubjectFromFunctionalFile', FileId)        : Find Subject for FunctionalFile with FileID 
%    - db_get('SubjectFromFunctionalFile', FileName)      : Find Subject for FunctionalFile with FileID 
%
% ====== STUDIES =======================================================================
%    - db_get('StudiesFromSubject', SubjectID, 'intra_subject', 'default_study') : Find Studies for Subject with SubjectID (with intra_subject and default_study)
%    - db_get('StudiesFromSubject', SubjectIDs)  : Find Studies for Subject with SubjectID (w/o intra_subject and default_study)
%    - db_get('StudiesFromSubject', SubjectName) : Find Studies for Subject with SubjectName (w/o intra_subject and default_study)
%    - db_get('DefaultStudy', iSubject)
%    - db_get('Study', StudyID) : Find Study by ID
%    - db_get('Studies', Fields) : Get all Studies in current protocol
%    - db_get('Studies')         : Get all Studies in current protocol
%
% ====== ANATOMY AND FUNCTIONAL FILES ==================================================
%    - db_get('FilesWithSubject')  :                        :
%    - db_get('FilesWithStudy')    :                       :
%    - db_get('AnatomyFile', FileIDs,   Fields) : Find anatomy file(s) by ID(s) 
%    - db_get('AnatomyFile', FileNames, Fields) : Find anatomy file(s) by FileName(s)
%    - db_get('AnatomyFile', CondQuery, Fields) : Find anatomy file(s) with a Query
%    - db_get('FunctionalFile', FileIDs,   Fields) : Find functional file(s) by ID(s) 
%    - db_get('FunctionalFile', FileNames, Fields) : Find functional file(s) by FileName(s)
%    - db_get('FunctionalFile', CondQuery, Fields) : Find functional file(s) with a Query
%    - db_get('ChannelFromStudy', StudyID) : Find current Channel for Study with StudyID  
%
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
    % sSubject = db_get('Subject', SubjectIDs,       Fields, isRaw);
    %          = db_get('Subject', SubjectFileNames, Fields, isRaw);
    %          = db_get('Subject', CondQuery,        Fields, isRaw);
    %          = db_get('Subject');
    % If isRaw is set: force to return the real brainstormsubject description
    % (ignoring whether it uses protocol's default anatomy or not)    
    case 'Subject'
        % Default parameters
        fields = '*';   
        isRaw = 0;
        templateStruct = db_template('Subject');

        % Parse first parameter
        if isempty(args)
           ProtocolInfo = bst_get('ProtocolInfo');
           iSubjects = ProtocolInfo.iSubject;
        else
           iSubjects = args{1};
        end
        % SubjectFileNames and CondQuery cases
        if ischar(iSubjects)
            iSubjects = {iSubjects};
        elseif isstruct(iSubjects)
            condQuery = args{1};           
        end

        % Parse Fields parameter
        if length(args) > 1
            fields = args{2};
            if ischar(fields)
                fields = {fields};
            end
            % Verify requested fields
            if ~all(isfield(templateStruct, fields))
                error('Invalid Fields requested in db_get()');
            else
                for i = 1 : length(fields)
                    resultStruct.(fields{i}) = templateStruct.(fields{i});
                end
            end
        else
            resultStruct = templateStruct;
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
    % sSubjects = db_get('Subjects');    % Exclude @default_subject
    %           = db_get('Subjects', 1); % Include @default_subject
    case 'Subjects'
        includeDefaultSub = ~isempty(args);
        if ~includeDefaultSub
            addQuery = ' WHERE Name <> "@default_subject"';
        else
            addQuery = '';
        end
        varargout{1} = sql_query(sqlConn, 'select', 'subject', '*', [], addQuery);

%% ==== FILES WITH SUBJECT ====
    % sAnatomyFiles = db_get('FilesWithSubject', SubjectID, AnatomyFileType)
    case 'FilesWithSubject'
        condQuery.Subject = args{1};
        if length(args) > 1 
            condQuery.Type = lower(args{2});
        end
        varargout{1} = db_get(sqlConn, 'AnatomyFile', condQuery);


%% ==== FILES WITH STUDY ====
    % sFiles = db_get('FilesWithStudy', FileType (e.g. Data), StudyID)
    case 'FilesWithStudy'
        % Special case: sStudy = db_get('FilesWithStudy', sStudy)
        % This sets the functional file fields in sStudy (e.g. Data)
        if length(args) == 1
            sStudy = args{1};
            iStudy = sStudy.Id;
            types = {'Channel', 'Data', 'HeadModel', 'Result', 'Stat', ...
                'Image', 'NoiseCov', 'Dipoles', 'Timefreq', 'Matrix'};

            for iType = 1:length(types)
                sStudy.(types{iType}) = repmat(db_template(types{iType}), 0);
            end
        elseif length(args) > 1
            types  = {lower(args{1})};
            iStudy = args{2};
            sStudy = [];
            sAnatFiles = repmat(db_template(types{1}),0);
        else
            error('Invalid call.');
        end

        if length(args) > 2
            cond = args{3};
        else
            cond = struct();
        end
        cond.Study = iStudy;
        extraQry = 'ORDER BY Id';
        if isempty(sStudy)
            % Noise and data covariance used to be merged
            if strcmpi(types{1}, 'noisecov')
                extraQry = ['AND Type IN ("noisecov", "ndatacov") ' extraQry];
            else
                cond.Type = types{1};
            end
        end

        results = sql_query(sqlConn, 'select', 'functionalfile', '*', cond, extraQry);

        for iFile = 1:length(results)
            type = results(iFile).Type;
            if ~isempty(sStudy)
                if strcmpi(type, 'ndatacov')
                    iType = find(strcmpi(types, 'noisecov'), 1);
                else
                    iType = find(strcmpi(types, type), 1);
                end
                
                if isempty(iType)
                    continue;
                end
            end

            sFile = getFunctionalFileStruct(type, results(iFile));

            if ~isempty(sStudy)
                % Special case to make sure noise and data covariances are
                % in the expected order (1. noise, 2. data)
                if strcmpi(type, 'noisecov')
                    if isempty(sStudy.NoiseCov)
                        sStudy.NoiseCov = sFile;
                    else
                        sStudy.NoiseCov(1) = sFile;
                    end
                elseif strcmpi(type, 'ndatacov')
                    if isempty(sStudy.NoiseCov)
                        sStudy.NoiseCov = repmat(db_template('NoiseCov'),1,2);
                    end
                    sStudy.NoiseCov(2) = sFile;
                else
                    if isempty(sStudy.(types{iType}))
                        sStudy.(types{iType}) = sFile;
                    else
                        sStudy.(types{iType})(end + 1) = sFile;
                    end
                end
            else
                % Special case to make sure noise and data covariances are
                % in the expected order (1. noise, 2. data)
                if strcmpi(type, 'noisecov')
                    if isempty(sAnatFiles)
                        sAnatFiles = sFile;
                    else
                        sAnatFiles(1) = sFile;
                    end
                elseif strcmpi(type, 'ndatacov')
                    if isempty(sAnatFiles)
                        sAnatFiles = repmat(db_template('NoiseCov'),1,2);
                    end
                    sAnatFiles(2) = sFile;
                else
                    sAnatFiles(end + 1) = sFile;
                end
            end
        end

        if ~isempty(sStudy)
            varargout{1} = sStudy;
        else
            varargout{1} = sAnatFiles;
        end

%% ==== ANATOMY FILE ====
    % sAnatomyFiles = db_get('AnatomyFile', FileIDs,   Fields)
    %               = db_get('AnatomyFile', FileNames, Fields)
    %               = db_get('AnatomyFile', CondQuery, Fields)
    case 'AnatomyFile'
        % Parse inputs
        iFiles = args{1};
        fields = '*';                              
        templateStruct = db_template('AnatomyFile');

        if ischar(iFiles)
            iFiles = {iFiles};
        elseif isstruct(iFiles)
            condQuery = args{1};           
        end

        if length(args) > 1
            fields = args{2};
            if ischar(fields)
                fields = {fields};
            end
            for i = 1 : length(fields)
                resultStruct.(fields{i}) = templateStruct.(fields{i});
            end
        else
            resultStruct = templateStruct;
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
    % [sFiles, sItems] = db_get('FunctionalFile', FileIDs,   Fields)
    %                  = db_get('FunctionalFile', FileNames, Fields)
    %                  = db_get('FunctionalFile', CondQuery, Fields)
    case 'FunctionalFile'
        % Parse inputs
        iFiles = args{1};
        fields = '*';                              
        templateStruct = db_template('FunctionalFile');

        if ischar(iFiles)
            iFiles = {iFiles};
        elseif isstruct(iFiles)
            condQuery = args{1};           
        end

        if length(args) > 1
            fields = args{2};
            if ischar(fields)
                fields = {fields};
            end
            for i = 1 : length(fields)
                resultStruct.(fields{i}) = templateStruct.(fields{i});
            end
        else
            resultStruct = templateStruct;
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
        sItems = [];
        
        % If output expected, all fields requested, and all sFiles are same Type     
        if nargout > 1 && isequal(fields, '*') && length(unique({sFiles(:).Type})) == 1
            nFiles = length(sFiles);
            sItems = repmat(db_template(sFiles(1).Type), 1, nFiles);
            for i = 1 : nFiles
                sItems(i) = getFunctionalFileStruct(sFiles(i).Type, sFiles(i));
            end
        end        

        varargout{1} = sFiles;
        varargout{2} = sItems;
%% ==== SUBJECT FROM STUDY ====
    % iSubject = db_get('SubjectFromStudy', StudyID)
    case 'SubjectFromStudy'
        iStudy = args{1};
        sStudy = sql_query(sqlConn, 'select', 'Study', 'Subject', struct('Id', iStudy));

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
        
        sStudy = sql_query(sqlConn, 'select', 'Study', ...
            {'Id', 'Subject', 'Name', 'iChannel'}, struct('Id', iStudy));
        if ~isempty(sStudy)
            iChanStudy = iStudy;
            % === Analysis-Inter node ===
            if strcmpi(sStudy.Name, '@inter')
                % If no channel file is defined in 'Analysis-intra' node: look in 
                if isempty(sStudy.iChannel)
                    % Get global default study
                    sStudy = sql_query(sqlConn, 'select', 'Study', ...
                        {'Id', 'Subject', 'iChannel'}, ...
                        struct('Subject', 0, 'Name', '@default_study'));
                    iChanStudy = sStudy.Id;
                end
            % === All other nodes ===
            else
                % Get subject attached to study
                sSubject = sql_query(sqlConn, 'select', 'Subject', 'UseDefaultChannel', ...
                    struct('Id', sStudy.Subject));
                % Subject uses default channel/headmodel
                if ~isempty(sSubject) && (sSubject.UseDefaultChannel ~= 0)
                    sStudy = sql_query(sqlConn, 'select', 'Study', {'Id', 'iChannel'}, ...
                        struct('Subject', sStudy.Subject, 'Name', '@default_study'));
                    if ~isempty(sStudy)
                        iChanStudy = sStudy.Id;
                    end
                end
            end

            if ~isempty(sStudy)
                % If no channel selected, find first channel in study
                if isempty(sStudy.iChannel)
                    sFile = db_get(sqlConn, 'FunctionalFile', struct('Study', sStudy.Id, 'Type', 'channel'), 'Id');
                    if ~isempty(sFile)
                        sStudy.iChannel = sFile(1).Id;
                    end
                end

                if ~isempty(sStudy.iChannel)
                    varargout{1} = sStudy.iChannel;
                    varargout{2} = iChanStudy;
                end
            end
        end
    
%% ==== STUDIES FROM SUBJECT ====        
    % iStudies = db_get('StudiesFromSubject', iSubject)                                   % Exclude 'intra_subject' and 'default_study')
    %          = db_get('StudiesFromSubject', iSubject, 'intra_subject', 'default_study') % Include 'intra_subject' and 'default_study')
    %          = db_get('StudiesFromSubject', SubjectName)
    case 'StudiesFromSubject'
        iSubject = args{1};
        
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
            sStudy = sql_query(sqlConn, 'select', 'Study', 'Id', struct('Subject', iSubject), addQuery);
            if isempty(sStudy)
                varargout{1} = [];
            else
                varargout{1} = [sStudy.Id];
            end
        end

%% ==== DEFAULT STUDY ====       
    % iStudy = db_get('DefaultStudy', iSubject)
    case 'DefaultStudy'
        iSubject = args{1};
        varargout{1} = [];
        defaultStudy = bst_get('DirDefaultStudy');
        
        % === DEFAULT SUBJECT ===
        % => Return global default study
        if iSubject == 0
            % Return Global default study
        % === NORMAL SUBJECT ===
        else
            sSubject = sql_query(sqlConn, 'select', 'Subject', 'UseDefaultChannel', struct('Id', iSubject));
            % === GLOBAL DEFAULT STUDY ===
            if sSubject.UseDefaultChannel == 2
                % Return Global default study
                iSubject = 0;
            % === SUBJECT'S DEFAULT STUDY ===
            elseif sSubject.UseDefaultChannel == 1
                % Return subject's default study
            end
        end
        
        sStudy = sql_query(sqlConn, 'select', 'Study', 'Id', struct('Subject', iSubject, 'Name', defaultStudy));
        if ~isempty(sStudy)
            varargout{1} = sStudy.Id;
        end
%% ==== STUDY ====   
    % sStudy = db_get('Study', StudyID)
    case 'Study'
        iStudy = args{1};
        varargout{1} = sql_query(sqlConn, 'select', 'Study', '*', struct('Id', iStudy));

%% ==== STUDIES ====              
    % sStudy = db_get('Studies', Fields)
    %        = db_get('Studies')
    case 'Studies'
        if length(args) > 0
            fields = args{1};
        else
            fields = '*';
        end
        
        varargout{1} = sql_query(sqlConn, 'select', 'Study', fields, [], ...
            'WHERE Name <> "@inter" AND (Subject <> 0 OR Name <> "@default_study")');

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

%% ==== LOCAL HELPERS ====

% Get a specific functional file db_template structure from the generic
% db_template('FunctionalFile') structure
function sFile = getFunctionalFileStruct(type, funcFile)
    sFile = db_template(type);
    if isempty(funcFile)
        return;
    end
    sFile.FileName = funcFile.FileName;
    sFile.Comment  = funcFile.Name;

    % Extra fields
    switch lower(type)
        case 'data'
            sFile.DataType = funcFile.SubType;
            sFile.BadTrial = funcFile.ExtraNum;

        case 'channel'
            sFile.nbChannels = funcFile.ExtraNum;
            sFile.Modalities = str_split(funcFile.ExtraStr1, ',');
            sFile.DisplayableSensorTypes = str_split(funcFile.ExtraStr2, ',');

        case {'result', 'results'}
            sFile.DataFile      = funcFile.ExtraStr1;
            sFile.isLink        = funcFile.ExtraNum;
            sFile.HeadModelType = funcFile.ExtraStr2;

        case 'timefreq'
            sFile.DataFile = funcFile.ExtraStr1;
            sFile.DataType = funcFile.ExtraStr2;

        case 'stat'
            sFile.Type       = funcFile.SubType;
            sFile.pThreshold = funcFile.ExtraStr1;
            sFile.DataFile   = funcFile.ExtraStr2;

        case 'headmodel'
            sFile.HeadModelType = funcFile.SubType;
            modalities = str_split(funcFile.ExtraStr1, ',');
            methods    = str_split(funcFile.ExtraStr2, ',');

            for iMod = 1:length(modalities)
                switch upper(modalities{iMod})
                    case 'MEG'
                        sFile.MEGMethod = methods{iMod};
                    case 'EEG'
                        sFile.EEGMethod = methods{iMod};
                    case 'ECOG'
                        sFile.ECOGMethod = methods{iMod};
                    case 'SEEG'
                        sFile.SEEGMethod = methods{iMod};
                    otherwise
                        error('Unsupported modality for head model method.');
                end
            end

        case 'dipoles'
            sFile.DataFile = funcFile.ExtraStr1;

        case {'matrix', 'noisecov', 'ndatacov', 'image'}
            % Nothing to add

        otherwise
            error('Unsupported functional file type.');
    end
end