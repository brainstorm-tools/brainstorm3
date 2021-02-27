function [out1, out2] = db_set(varargin)
% DB_SET: Set values in the protocol database from a Brainstorm structure
% This function is a newer API than bst_set

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
if isempty(varargin{1})
    sqlConn = sql_connect();
    handleConn = 1;
else
    sqlConn = varargin{1};
    handleConn = 0;
end
contextName = varargin{2};
args = varargin(3:end);
out1 = [];
out2 = [];

switch contextName
    % iAnat/iSurf = db_set('FilesWithSubject', FileType, db_template('anatomy/surface'), SubjectID, selectedAnat/Surf)
    case 'FilesWithSubject'
        type = lower(args{1});
        sFiles = args{2};
        iSubject = args{3};
        nFiles = length(sFiles);
        if length(args) > 3
            selFile = args{4};
        else
            selFile = [];
        end

        if nargout > 0
            out1 = repmat(db_template('AnatomyFile'), 1, nFiles);
        end

        for iFile = 1:nFiles
            anatomyFile = db_template('AnatomyFile');
            anatomyFile.Subject = iSubject;
            anatomyFile.Type = type;
            anatomyFile.FileName = sFiles(iFile).FileName;
            anatomyFile.Name = sFiles(iFile).Comment;

            % Extra fields
            switch type
                case 'anatomy'
                    % No extra fields
                case 'surface'
                    anatomyFile.SurfaceType = sFiles(iFile).SurfaceType;
                otherwise
                    error('Unsupported anatomy file type');
            end

            insertedId = sql_query(sqlConn, 'insert', 'anatomyfile', anatomyFile);

            if nargout > 0
                anatomyFile.Id = insertedId;
                out1(iFile) = anatomyFile;

                if ~isempty(selFile)
                    if strcmpi(anatomyFile.FileName, selFile)
                        out2 = anatomyFile.Id;
                    end
                end
            end
        end

    % db_set('FilesWithStudy', FileType, db_template('data/timefreq/etc'), StudyID)
    case 'FilesWithStudy'
        % Special case: db_set('FilesWithStudy', sStudy)
        if length(args) == 1
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
        
        out1 = ModifyFunctionalFile(sqlConn, queryType, sFile, updateCondition);

    otherwise
        error('Invalid context : "%s"', contextName);
end

% Close SQL connection if it was created
if handleConn
    sql_close(sqlConn);
end

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

function outStr = str_join(cellStr, delimiter)
    outStr = '';
    for iCell = 1:length(cellStr)
        if iCell > 1
            outStr = [outStr delimiter];
        end
        outStr = [outStr cellStr{iCell}];
    end
end

function FileName = FileStandard(FileName)
    % Replace '\' with '/'
    FileName(FileName == '\') = '/';
    % Remove first slash (filenames all relative)
    if (FileName(1) == '/')
        FileName = FileName(2:end);
    end
end

function res = ModifyFunctionalFile(sqlConn, queryType, sFile, updateCondition)
    if nargin < 4
        updateCondition = [];
    end

    sFile.LastModified = bst_get('CurrentUnixTime');
    
    res = sql_query(sqlConn, queryType, 'functionalfile', sFile, updateCondition);
end

