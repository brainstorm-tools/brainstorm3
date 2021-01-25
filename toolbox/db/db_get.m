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
    if isempty(varargin{2}) && nargin > 2
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


% Apply subfunction iteratively
varargout = {};
if iscell(contextName)
    for iVal = 1:length(contextName)
        if nargin < 3
            varargout{iVal} = db_get2(contextName{iVal}, sqlConn);
        else
            varargout{iVal} = db_get2(contextName{iVal}, sqlConn, args{iVal});
        end
    end
else
    varargout{1} = db_get2(contextName, sqlConn, args);
end

% Close SQL connection if it was created
if handleConn
    sql_close(sqlConn);
end
end

function varargout = db_get2(contextName, sqlConn, args)
    varargout = {};
    switch contextName
        case 'Subject'
            iSubject = args{1};
            varargout{1} = sql_query(sqlConn, 'select', 'subject', '*', struct('Id', iSubject));
        
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
                
                sFile = db_template(type);
                sFile.FileName = results(iFile).FileName;
                sFile.Comment  = results(iFile).Name;
                
                % Extra fields
                switch type
                    case 'data'
                        sFile.DataType = results(iFile).ExtraStr1;
                        sFile.BadTrial = results(iFile).ExtraNum;
                        
                    case 'channel'
                        sFile.nbChannels = results(iFile).ExtraNum;
                        sFile.Modalities = str_split(results(iFile).ExtraStr1, ',');
                        sFile.DisplayableSensorTypes = str_split(results(iFile).ExtraStr2, ',');

                    case {'result', 'results'}
                        sFile.DataFile      = results(iFile).ExtraStr1;
                        sFile.isLink        = results(iFile).ExtraNum;
                        sFile.HeadModelType = results(iFile).ExtraStr2;
                        
                    case 'timefreq'
                        sFile.DataFile = results(iFile).ExtraStr1;
                        sFile.DataType = results(iFile).ExtraStr2;
                        
                    case 'stat'
                        sFile.Type       = results(iFile).SubType;
                        sFile.pThreshold = results(iFile).ExtraStr1;
                        sFile.DataFile   = results(iFile).ExtraStr2;
                        
                    case 'headmodel'
                        sFile.HeadModelType = results(iFile).SubType;
                        modalities = str_split(results(iFile).ExtraStr1, ',');
                        methods    = str_split(results(iFile).ExtraStr2, ',');
                        
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
                        sFile.DataFile = results(iFile).ExtraStr1;
                        
                    case {'matrix', 'noisecov', 'image'}
                        % Nothing to add
                        
                    otherwise
                        error('Unsupported functional file type.');
                end
                
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
            
        otherwise
        error('Invalid context : "%s"', contextName);
    end
end