function varargout = db_get(varargin)
% DB_GET: Get a Brainstorm structure from the protocol database
% This function is a newer API than bst_get

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

% Parse inputs
contextName = varargin{1};
if nargin < 2 || isempty(varargin{2}) || ~isjava(varargin{2})
    sqlConn = sql_connect();
    handleConn = 1;
    if nargin > 2 && isempty(varargin{2})
        args = varargin(3:end);
    elseif nargin > 1
        args = varargin(2:end);
    else
        args = {};
    end
else
    sqlConn = varargin{2};
    handleConn = 0;
    if nargin > 2
        args = varargin(3:end);
    else
        args = {};
    end
end

varargout = {};
switch contextName
    case 'Subject'
        iSubject = args{1};
        varargout{1} = sql_query(sqlConn, 'select', 'subject', '*', struct('Id', iSubject));
        
    case 'Subjects'
        includeDefaultSub = length(args) > 1 && args{2};
        if ~includeDefaultSub
            addQuery = ' WHERE Name <> "@default_subject"';
        else
            addQuery = '';
        end
        varargout{1} = sql_query(sqlConn, 'select', 'subject', '*', [], addQuery);

    % Usage: sFiles = db_get('FilesWithSubject', FileType (e.g. Anatomy), SubjectID)
    case 'FilesWithSubject'
        % Special case: sSubject = db_get('FilesWithSubject', sSubject)
        % This sets the anatomy file fields in sSubject (Anatomy, Surface)
        if length(args) == 1
            sSubject = args{1};
            sSubject.Anatomy = repmat(db_template('Anatomy'), 0);
            sSubject.Surface = repmat(db_template('Surface'), 0);
            qryCondition = struct('Subject', sSubject.Id);
        else
            type = lower(args{1});
            iSubject = args{2};
            sSubject = [];
            sOutFiles = repmat(db_template(type), 0);
            qryCondition = struct('Subject', iSubject, 'Type', type);
        end
        sAnatFiles = sql_query(sqlConn, 'select', 'anatomyfile', '*', qryCondition);

        if isempty(sAnatFiles)
            if ~isempty(sSubject)
                varargout{1} = sSubject;
            else
                varargout{1} = sAnatFiles;
            end
        else

            for iFile = 1:length(sAnatFiles)
                sFile = db_template(sAnatFiles(iFile).Type);
                sFile.Comment = sAnatFiles(iFile).Name;
                sFile.FileName = sAnatFiles(iFile).FileName;

                switch sAnatFiles(iFile).Type
                    case 'anatomy'
                        if ~isempty(sSubject)
                            sSubject.Anatomy(end + 1) = sFile;
                        end
                    case 'surface'
                        sFile.SurfaceType = sAnatFiles(iFile).SurfaceType;
                        if ~isempty(sSubject)
                            sSubject.Surface(end + 1) = sFile;
                        end
                    otherwise
                        error('Unsupported anatomy file type');
                end

                if isempty(sSubject)
                    sOutFiles(end + 1) = sFile;
                end
            end

            if ~isempty(sSubject)
                varargout{1} = sSubject;
            else
                varargout{1} = sOutFiles;
            end
        end

    % Usage: sFiles = db_get('FilesWithStudy', FileType (e.g. Data), StudyID)
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

            sFile = getFuncFileStruct(type, results(iFile));

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
        
%% ==== FUNCTIONAL FILE ====
    % Usage: [sFiles, sItems] = db_get('FunctionalFile', FileIDs,   Fields)
    % Usage: [sFiles, sItems] = db_get('FunctionalFile', FileNames, Fields)
    % Usage: [sFiles, sItems] = db_get('FunctionalFile', CondQuery, Fields)
    case 'FunctionalFile'
        % Parse inputs
        iFiles = args{1};
        fields = '*';
        condQuery = struct();
        if length(args) > 1
            fields = args{2};
        end
        
        if isstruct(iFiles)
            condQuery = CondQuery;           
        end
        
        if ischar(iFiles)
            iFiles = {iFiles};
        end
        
        nFiles = length(iFiles);
        sFiles = repmat(db_template('FunctionalFile'), 1, nFiles);

        for i = 1:nFiles
            if iscell(iFiles)
                condQuery.FileName = iFiles{i};
            else
                condQuery.Id = iFiles(i);
            end
            sFiles(i) = sql_query(sqlConn, 'select', 'functionalfile', fields, condQuery);
            if i == 1
                sItems = repmat(db_template(sFiles(1).Type), 1, nFiles);
            end        
            sItems(i) = getFuncFileStruct(sFiles(i).Type, sFiles(i));
        end
 
        varargout{1} = sFiles;
        varargout{2} = sItems;

%%
    % Usage: iSubject = db_get('SubjectFromStudy', iStudy)
    case 'SubjectFromStudy'
        iStudy = args{1};
        sStudy = sql_query(sqlConn, 'select', 'Study', 'Subject', struct('Id', iStudy));

        if ~isempty(sStudy)
            iSubject = sStudy.Subject;
        else
            iSubject = [];
        end

        varargout{1} = iSubject;
        
    % Usage: iFile = db_get('ChannelFromStudy', iStudy)
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
                    sChannel = sql_query(sqlConn, 'select', 'FunctionalFile', ...
                        'Id', struct('Study', sStudy.Id, 'Type', 'channel'));
                    if ~isempty(sChannel)
                        sStudy.iChannel = sChannel(1).Id;
                    end
                end

                if ~isempty(sStudy.iChannel)
                    varargout{1} = sStudy.iChannel;
                    varargout{2} = iChanStudy;
                end
            end
        end
        
    % Usage: iStudies = db_get('StudiesFromSubject', iSubject) : WITHOUT the system studies ('intra_subject', 'default_study')
    % Usage: iStudies = db_get('StudiesFromSubject', iSubject, 'intra_subject', 'default_study') : WITH the system studies
    % Usage: iStudies = db_get('StudiesFromSubject', SubjectName)
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
        
    % Usage: iStudy = db_get('DefaultStudy', iSubject)
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
        
    case 'Study'
        iStudy = args{1};
        varargout{1} = sql_query(sqlConn, 'select', 'Study', '*', struct('Id', iStudy));
        
    % Usage: sStudy = db_get('Studies')
    % Usage: sStudy = db_get('Studies', {'Id', 'Name'})
    case 'Studies'
        if length(args) > 0
            fields = args{1};
        else
            fields = '*';
        end
        
        varargout{1} = sql_query(sqlConn, 'select', 'Study', fields, [], ...
            'WHERE Name <> "@inter" AND (Subject <> 0 OR Name <> "@default_study")');
        
    % Usage: iSubject = db_get('SubjectFromFunctionalFile', FileId/FileName)
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
        
    otherwise
        error('Invalid context : "%s"', contextName);
end


% Close SQL connection if it was created
if handleConn
    sql_close(sqlConn);
end
end

%% ==== HELPERS ====

% Get a specific functional file db_template structure from the generic
% db_template('FunctionalFile') structure.
function sFile = getFuncFileStruct(type, funcFile)
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

        case {'matrix', 'noisecov', 'image'}
            % Nothing to add

        otherwise
            error('Unsupported functional file type.');
    end
end