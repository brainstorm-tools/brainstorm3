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
            types = {'Channel', 'Data', 'HeadModel', 'Result', 'Stat', ...
                'Image', 'NoiseCov', 'Dipoles', 'Timefreq', 'Matrix'};
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

            for iFile = 1:length(sFiles)
                functionalFile = db_template('FunctionalFile');
                functionalFile.Study = iStudy;
                functionalFile.Type = type;
                functionalFile.FileName = sFiles(iFile).FileName;
                functionalFile.Name = sFiles(iFile).Comment;

                % Extra fields
                switch type
                    case 'data'
                        functionalFile.ExtraStr1 = sFiles(iFile).DataType;
                        functionalFile.ExtraNum  = sFiles(iFile).BadTrial;

                    case 'channel'
                        functionalFile.ExtraNum  = sFiles(iFile).nbChannels;
                        functionalFile.ExtraStr1 = str_join(sFiles(iFile).Modalities, ',');
                        functionalFile.ExtraStr2 = str_join(sFiles(iFile).DisplayableSensorTypes, ',');

                    case {'result', 'results'}
                        functionalFile.ExtraStr1 = sFiles(iFile).DataFile;
                        functionalFile.ExtraNum  = sFiles(iFile).isLink;
                        functionalFile.ExtraStr2 = sFiles(iFile).HeadModelType;

                    case 'timefreq'
                        functionalFile.ExtraStr1 = sFiles(iFile).DataFile;
                        functionalFile.ExtraStr2 = sFiles(iFile).DataType;

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

                    case {'matrix', 'noisecov', 'image'}
                        % Nothing to add

                    otherwise
                        error('Unsupported functional file type');
                end

                sql_query(sqlConn, 'insert', 'functionalfile', functionalFile);
            end
        end

    otherwise
        error('Invalid context : "%s"', contextName);
end

% Close SQL connection if it was created
if handleConn
    sql_close(sqlConn);
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