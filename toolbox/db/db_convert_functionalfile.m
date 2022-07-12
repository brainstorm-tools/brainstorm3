function outStructs = db_convert_functionalfile(inStructs, type)
% Bidirectional conversion between Old and New structures
%
% New to Old
% sChannel / sData / sDipoles / sHeadmodel / ...
% sResults / sResult  / sStat / sTimefreq / ...
% sImage / sMatrix / sNoiseCov / sNdataCov  = db_convert_functionalfile(FunctionalFile)
% 
% Old to New
% sFunctionalFile = db_convert_functionalfile(sChannel,   'channel')
% sFunctionalFile = db_convert_functionalfile(sData,      'data')
% sFunctionalFile = db_convert_functionalfile(sDipoles,   'dipoles')
% sFunctionalFile = db_convert_functionalfile(sHeadModel, 'headmodel')
% sFunctionalFile = db_convert_functionalfile(sResults,   'results')
% sFunctionalFile = db_convert_functionalfile(sResult,    'result')
% sFunctionalFile = db_convert_functionalfile(sStat,      'stat')
% sFunctionalFile = db_convert_functionalfile(sTimefreq,  'timefreq')
% sFunctionalFile = db_convert_functionalfile(sImage,     'image')
% sFunctionalFile = db_convert_functionalfile(sMatrix,    'matrix')
% sFunctionalFile = db_convert_functionalfile(sNoiseCov,  'noisecov')
% sFunctionalFile = db_convert_functionalfile(sNdataCov,  'ndatacov')
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
% Authors: Raymundo Cassani, 2021-2022

% Validate 'type' argument
if (nargin < 2) || isempty(type)
    type = '';
end

% Output
outStructs = [];

nStructs = length(inStructs);
if nStructs < 1
    return
end 

% Verify the sense of the conversion
% New to old
if all(isfield(inStructs(1), {'Id', 'Type'}))
    % Old structures should be of the same type 
    if length(unique({inStructs.Type})) == 1
        outStructs = repmat(db_template(inStructs(1).Type), 1, nStructs);
        for iStruct = 1 : nStructs 
            % Common fields
            outStructs(iStruct).FileName = inStructs(iStruct).FileName;
            outStructs(iStruct).Comment  = inStructs(iStruct).Name;
            % Extra fields
            switch lower(inStructs(iStruct).Type)
                case 'channel'
                    outStructs(iStruct).nbChannels = inStructs(iStruct).ExtraNum;
                    outStructs(iStruct).Modalities = str_split(inStructs(iStruct).ExtraStr1, ',');
                    outStructs(iStruct).DisplayableSensorTypes = str_split(inStructs(iStruct).ExtraStr2, ',');
                case 'data'
                    outStructs(iStruct).DataType = inStructs(iStruct).SubType;
                    outStructs(iStruct).BadTrial = inStructs(iStruct).ExtraNum;
                case 'dipoles'
                    outStructs(iStruct).DataFile = inStructs(iStruct).ExtraStr1;
                case 'headmodel'
                    outStructs(iStruct).HeadModelType = inStructs(iStruct).SubType;
                    modalities = str_split(inStructs(iStruct).ExtraStr1, ',');
                    methods    = str_split(inStructs(iStruct).ExtraStr2, ',');
                    for iMod = 1:length(modalities)
                        switch upper(modalities{iMod})
                            case 'MEG'
                                outStructs(iStruct).MEGMethod = methods{iMod};
                            case 'EEG'
                                outStructs(iStruct).EEGMethod = methods{iMod};
                            case 'ECOG'
                                outStructs(iStruct).ECOGMethod = methods{iMod};
                            case 'SEEG'
                                outStructs(iStruct).SEEGMethod = methods{iMod};
                            otherwise
                                error('Unsupported modality for head model method.');
                        end
                    end                       
                case {'result', 'results'}
                    outStructs(iStruct).DataFile      = inStructs(iStruct).ExtraStr1;
                    outStructs(iStruct).isLink        = inStructs(iStruct).ExtraNum;
                    outStructs(iStruct).HeadModelType = inStructs(iStruct).ExtraStr2;                                                          
                case 'stat'
                    outStructs(iStruct).Type       = inStructs(iStruct).SubType;
                    outStructs(iStruct).pThreshold = inStructs(iStruct).ExtraStr1;
                    outStructs(iStruct).DataFile   = inStructs(iStruct).ExtraStr2;                
                case 'timefreq'
                    outStructs(iStruct).DataFile = inStructs(iStruct).ExtraStr1;
                    outStructs(iStruct).DataType = inStructs(iStruct).ExtraStr2;
                case {'image', 'matrix', 'noisecov', 'ndatacov'}
                    % Nothing to add
                otherwise
                    error('Unsupported functional file type.');
            end
        end
    end
    
% Old to new    
else 
    outStructs = repmat(db_template('FunctionalFile'), 1, nStructs);
    for iStruct = 1 : nStructs
        % Common fields
        outStructs(iStruct).FileName = inStructs(iStruct).FileName;
        outStructs(iStruct).Name     = inStructs(iStruct).Comment;
        outStructs(iStruct).Type     = type;
        % Extra fileds
        switch lower(type)
            case 'channel'
                outStructs(iStruct).ExtraNum  = inStructs(iStruct).nbChannels;
                outStructs(iStruct).ExtraStr1 = str_join(inStructs(iStruct).Modalities, ',');
                outStructs(iStruct).ExtraStr2 = str_join(inStructs(iStruct).DisplayableSensorTypes, ',');
            case 'data'
                outStructs(iStruct).SubType  = inStructs(iStruct).DataType;
                outStructs(iStruct).ExtraNum = inStructs(iStruct).BadTrial;
            case 'dipoles'                                        
                outStructs(iStruct).ExtraStr1  = inStructs(iStruct).DataFile;
            case 'headmodel'
                allMods = {'MEG', 'EEG', 'ECOG', 'SEEG'};
                modalities = {};
                methods = {};
                for iMod = 1:length(allMods)
                    field = [allMods{iMod} 'Method'];
                    if ~isempty(inStructs(iStruct).(field))
                        modalities{end + 1} = allMods{iMod};
                        methods{end + 1} = inStructs(iStruct).(field);
                    end
                end
                outStructs(iStruct).SubType   = inStructs(iStruct).HeadModelType;
                outStructs(iStruct).ExtraStr1 = str_join(modalities, ',');
                outStructs(iStruct).ExtraStr2 = str_join(methods, ',');                
            case {'result', 'results'}
                outStructs(iStruct).ExtraNum   = inStructs(iStruct).isLink;
                outStructs(iStruct).ExtraStr1  = inStructs(iStruct).DataFile;
                outStructs(iStruct).ExtraStr2  = inStructs(iStruct).HeadModelType;
            case 'stat'
                outStructs(iStruct).SubType   = inStructs(iStruct).Type;
                outStructs(iStruct).ExtraStr1 = inStructs(iStruct).pThreshold;
                outStructs(iStruct).ExtraStr2 = inStructs(iStruct).DataFile;
            case 'timefreq'
                outStructs(iStruct).ExtraStr1  = inStructs(iStruct).DataFile;
                outStructs(iStruct).ExtraStr2  = inStructs(iStruct).DataType;
            case {'image', 'matrix', 'noisecov', 'ndatacov'}
                % Nothing to add
            otherwise
                error('Unsupported functional file type.');
        end
    end
end
end

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