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
            return;
        end

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

        cond = struct('Study', iStudy);
        if isempty(sStudy)
            cond.Type = types{1};
        end

        results = sql_query(sqlConn, 'select', 'functionalfile', '*', cond, 'ORDER BY Id');

        for iFile = 1:length(results)
            type = results(iFile).Type;
            if ~isempty(sStudy)
                iType = find(strcmpi(types, type), 1);
                if isempty(iType)
                    continue;
                end
            end

            sFile = getFuncFileStruct(type, results(iFile));

            if ~isempty(sStudy)
                if isempty(sStudy.(types{iType}))
                    sStudy.(types{iType}) = sFile;
                else
                    sStudy.(types{iType})(end + 1) = sFile;
                end
            else
                sAnatFiles(end + 1) = sFile;
            end
        end

        if ~isempty(sStudy)
            varargout{1} = sStudy;
        else
            varargout{1} = sAnatFiles;
        end

    % Usage: sFiles = db_get('FunctionalFile', FileType, FileIDs)
    % Usage: sFiles = db_get('FunctionalFile', FileType, FileNames)
    case 'FunctionalFile'
        type = args{1};
        iFiles = args{2};
        if ischar(iFiles)
            iFiles = {iFiles};
        end
        nFiles = length(iFiles);
        sFiles = repmat(db_template('FunctionalFile'), 1, nFiles);
        sItems = repmat(db_template(type), 1, nFiles);

        for i = 1:nFiles
            if iscell(iFiles)
                condQuery = struct('Type', type, 'FileName', iFiles{i});
            else
                condQuery = struct('Id', iFiles(i));
            end
            sFiles(i) = sql_query(sqlConn, 'select', 'functionalfile', '*', condQuery);
            sItems(i) = getFuncFileStruct(type, sFiles(i));
        end

        varargout{1} = sItems;
        varargout{2} = sFiles;

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

    otherwise
        error('Invalid context : "%s"', contextName);
end


% Close SQL connection if it was created
if handleConn
    sql_close(sqlConn);
end
end

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