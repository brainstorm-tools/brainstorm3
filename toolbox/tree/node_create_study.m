function numElems = node_create_study(nodeParent, nodeRoot, sStudy, iStudy, iFile, isExpandTrials, UseDefaultChannel, iSearch)
% NODE_CREATE_STUDY: Create study node from study structure.
%
% USAGE:  node_create_study(nodeStudy, sStudy, iStudy, [], isExpandTrials, UseDefaultChannel)
%
% INPUT: 
%     - nodeParent : BstNode object of the parent (either a study or a parent file)
%     - nodeRoot   : BstNode object, root of the whole database tree
%     - sStudy     : Brainstorm study structure
%     - iStudy     : indice of the study node in Brainstorm studies list
%     - iFile      : File ID if this is a parent file, otherwise empty
%     - isExpandTrials    : If 1, force the trials list to be expanded at the subtree creation
%     - UseDefaultChannel : If 1, do not display study's channels and headmodels
%     - iSearch   : ID of the active DB search, or empty/0 if none
% OUTPUT:
%    - numElems   : Number of node children elements (including self) that
%                   pass the active search filter. If 0, node should be hidden

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
% Authors: Francois Tadel, 2008-2015
%          Martin Cousineau, 2020

    
%% ===== PARSE INPUTS =====
if (nargin < 4) || isempty(isExpandTrials)
    isExpandTrials = 1;
    %TODO: Expand all
end
if (nargin < 5) || isempty(UseDefaultChannel)
    UseDefaultChannel = 0;
end
if (nargin < 6) || isempty(iSearch) || iSearch == 0
    iSearch = 0;
    % No search applied: ensure the node is added to the database
    numElems = 1;
else
    numElems = 0;
end
showParentNodes = node_show_parents(iSearch);

% Is the parent a default study node ?
if strcmpi(nodeParent.getType(), 'defaultstudy')
    isDefaultStudyNode = 1;
else
    isDefaultStudyNode = 0;
end

% Nodes considered new are less than an hour old
bstStartTime = bst_get('ProgramStartTime');
newNodeTime  = bst_get('CurrentUnixTime') - 3600;
ProtocolInfo = bst_get('ProtocolInfo');

% Query database to get all functional files
conditions = struct('Study', iStudy);
if isempty(iFile)
    additionalQry = 'AND ParentFile IS NULL';
else
    conditions.ParentFile = iFile;
    additionalQry = [];
end
sFiles = sql_query('SELECT', 'FunctionalFile', conditions, '*', additionalQry);

% Sort files by natural order
[tmp, iSort] = sort_nat({sFiles.Name});
sFiles = sFiles(iSort);

allTypes = {sFiles.Type};


%% ===== CHANNEL =====
iChannel = find(strcmp('channel', allTypes), 1);
% Display channel if : default node, or do not use default
if (~UseDefaultChannel || isDefaultStudyNode) && ~isempty(iChannel)
    CreateNode(nodeParent, 'channel', sFiles(iChannel).Name, ...
        sFiles(iChannel).FileName, sFiles(iChannel).Id, iStudy, ...
        sFiles(iChannel).NumChildren, sFiles(iChannel).LastModified);
end

%% ===== HEAD MODEL =====
if ~UseDefaultChannel || isDefaultStudyNode
    iHeadModels = find(strcmp('headmodel', allTypes));
    for i = 1:length(iHeadModels)
        iHeadModel = iHeadModels(i);
        if isempty(sFiles(iHeadModel).Name)
            sFiles(iHeadModel).Name = '';
        end
        nodeHeadModel = CreateNode(nodeParent, 'headmodel', sFiles(iHeadModel).Name, ...
            sFiles(iHeadModel).FileName, sFiles(iHeadModel).Id, iStudy, ...
            sFiles(iHeadModel).NumChildren, sFiles(iHeadModel).LastModified);
        % If current item is default one
        if ~isempty(nodeHeadModel) && ~isempty(sStudy) && ismember(sFiles(iHeadModel).Id, sStudy.iHeadModel)
            nodeHeadModel.setMarked(1);
        end
    end
end

%% ===== NOISE/DATA COV =====
iNoiseCovs = find(strcmp('noisecov', allTypes));
iDataCovs  = find(strcmp('ndatacov', allTypes));
% Display NoiseCov if : default node, or do not use default
if (~UseDefaultChannel || isDefaultStudyNode)
    % Noise covariance
    if ~isempty(iNoiseCovs)
        CreateNode(nodeParent, 'noisecov', sFiles(iNoiseCovs(1)).Name, ...
            sFiles(iNoiseCovs(1)).FileName, sFiles(iNoiseCovs(1)).Id, iStudy, ...
            sFiles(iNoiseCovs(1)).NumChildren, sFiles(iNoiseCovs(1)).LastModified);
    end
    % Data covariance
    if ~isempty(iDataCovs)
        CreateNode(nodeParent, 'noisecov', sFiles(iDataCovs(1)).Name, ...
            sFiles(iDataCovs(1)).FileName, sFiles(iDataCovs(1)).Id, iStudy, ...
            sFiles(iDataCovs(1)).NumChildren, sFiles(iDataCovs(1)).LastModified);
    end
end

%% ===== KERNELS =====
iResults = find(strcmp('result', allTypes));
for i = 1:length(iResults)
    iResult = iResults(i);
    isLink = sFiles(iResult).ExtraNum;
    DataFile = sFiles(iResult).ExtraStr1;
    
    % Only add kernels at this point
    if ~isLink && isempty(DataFile) && ~isempty(strfind(sFiles(iResult).FileName, 'KERNEL'))
        CreateNode(nodeParent, 'kernel', sFiles(iResult).Name, sFiles(iResult).FileName, ...
            sFiles(iResult).Id, iStudy, sFiles(iResult).NumChildren, sFiles(iResult).LastModified);
    end
end


%% ===== FOLDERS =====
iFolders = find(strcmp('folder', allTypes));
for i = 1:length(iFolders)
    iFolder = iFolders(i);
    CreateNode(nodeParent, 'folder', sFiles(iFolder).Name, ...
        sFiles(iFolder).FileName, sFiles(iFolder).Id, iStudy, ...
        sFiles(iFolder).NumChildren, sFiles(iFolder).LastModified);
end

%% ===== DATA LISTS =====
iDataLists = find(strcmp('datalist', allTypes));
for i = 1:length(iDataLists)
    iDataList = iDataLists(i);
    CreateNode(nodeParent, 'datalist', ...
        sprintf('%s (%d files)', sFiles(iDataList).Name, sFiles(iDataList).NumChildren), ...
        sFiles(iDataList).Name, sFiles(iDataList).Id, iStudy, ...
        sFiles(iDataList).NumChildren, sFiles(iDataList).LastModified);
end

%% ===== DATA =====
iDatas = find(strcmp('data', allTypes));
for i = 1:length(iDatas)
    iData = iDatas(i);
    % Node modifier (0=none, 1=bad trial)
    Modifier = sFiles(iData).ExtraNum;
    DataType = sFiles(iData).SubType;
    % Create node
    if strcmpi(DataType, 'raw')
        nodeType = 'rawdata';
    else
        nodeType = 'data';
    end
    
    CreateNode(nodeParent, nodeType, sFiles(iData).Name, sFiles(iData).FileName, ...
        sFiles(iData).Id, iStudy, sFiles(iData).NumChildren, ...
        sFiles(iData).LastModified, Modifier);
end

%% ===== RESULT =====
for i = 1:length(iResults)
    iResult = iResults(i);
    isLink = sFiles(iResult).ExtraNum;
    DataFile = sFiles(iResult).ExtraStr1;
    
    % Results or link
    if ~isLink
        if isempty(DataFile) && ~isempty(strfind(sFiles(iResult).FileName, 'KERNEL'))
            % Kernels already added
            continue;
        else
            nodeType = 'results';
        end
    else
        nodeType = 'link';
    end
    
    CreateNode(nodeParent, nodeType, sFiles(iResult).Name, sFiles(iResult).FileName, ...
        sFiles(iResult).Id, iStudy, sFiles(iResult).NumChildren, sFiles(iResult).LastModified);
end

%% ===== MATRIX LISTS =====
iMatrixLists = find(strcmp('matrixlist', allTypes));
for i = 1:length(iMatrixLists)
    iMatrixList = iMatrixLists(i);
    CreateNode(nodeParent, 'matrixlist', ...
        sprintf('%s (%d files)', sFiles(iMatrixList).Name, sFiles(iMatrixList).NumChildren), ...
        sFiles(iMatrixList).Name, sFiles(iMatrixList).Id, iStudy, ...
        sFiles(iMatrixList).NumChildren, sFiles(iMatrixList).LastModified);
end

%% ===== MATRIX =====
iMatrices = find(strcmp('matrix', allTypes));
for i = 1:length(iMatrices)
    iMatrix = iMatrices(i);    
    CreateNode(nodeParent, 'matrix', sFiles(iMatrix).Name, sFiles(iMatrix).FileName, ...
        sFiles(iMatrix).Id, iStudy, sFiles(iMatrix).NumChildren, sFiles(iMatrix).LastModified);
end

%% ===== TIMEFREQ =====
iTimeFreqs = find(strcmp('timefreq', allTypes));
% Display time-frequency nodes
for i = 1:length(iTimeFreqs)
    iTimeFreq = iTimeFreqs(i);
    
    % TF or PSD node
    if ~isempty(strfind(sFiles(iTimeFreq).FileName, '_psd')) || ~isempty(strfind(sFiles(iTimeFreq).FileName, '_fft'))
        nodeType = 'spectrum';
    else
        nodeType = 'timefreq';
    end
    
    CreateNode(nodeParent, nodeType, sFiles(iTimeFreq).Name, sFiles(iTimeFreq).FileName, ...
        sFiles(iTimeFreq).Id, iStudy, sFiles(iTimeFreq).NumChildren, sFiles(iTimeFreq).LastModified);
end


%% ===== DIPOLES =====
iDipoles = find(strcmp('dipole', allTypes));
% Display dipoles
for i = 1:length(iDipoles)
    iDipole = iDipoles(i);
    CreateNode(nodeParent, 'dipoles', sFiles(iDipole).Name, sFiles(iDipole).FileName, ...
        sFiles(iDipole).Id, iStudy, sFiles(iDipole).NumChildren, sFiles(iDipole).LastModified);
end


%% ===== STAT =====
iStats = find(strcmp('stat', allTypes));
% Display stat node
for i = 1:length(iStats)
    iStat = iStats(i);
    
    if isempty(sFiles(iStat).SubType)
        continue;
    end
    % Node type
    switch sFiles(iStat).SubType
        case 'data'
            nodeType = 'pdata';
        case 'results'
            nodeType = 'presults';
        case 'timefreq'
            % TF or PSD node
            if ~isempty(strfind(sFiles(iStat).FileName, '_psd')) || ~isempty(strfind(sFiles(iStat).FileName, '_fft'))
                nodeType = 'pspectrum';
            else
                nodeType = 'ptimefreq';
            end
        case 'matrix'
            nodeType = 'pmatrix';
        otherwise
            nodeType = sFiles(iStat).SubType;
    end
    
    % Create node
    CreateNode(nodeParent, nodeType, sFiles(iStat).Name, sFiles(iStat).FileName, ...
        sFiles(iStat).Id, iStudy, sFiles(iStat).NumChildren, sFiles(iStat).LastModified);
end


%% ===== IMAGES =====
iImages = find(strcmp('image', allTypes));
% Display images nodes
for i = 1:length(iImages)
    iImage = iImages(i);
    % Get file type
    fileType = file_gettype(sFiles(iImage).FileName);
    % Image node
    switch fileType
        case 'image'
            nodeType = 'image';
        case 'videolink'
            nodeType = 'video';
        otherwise
            nodeType = fileType;
    end
    
    CreateNode(nodeParent, nodeType, sFiles(iImage).Name, sFiles(iImage).FileName, ...
        sFiles(iImage).Id, iStudy, sFiles(iImage).NumChildren, sFiles(iImage).LastModified);
end

    % Create a Java object for a database node if it passes the active search
    %
    % Inputs:
    %  - parentNode: Java object of the parent node
    %  - nodeType to Modifier: See BstJava's constructor
    %
    % Outputs:
    %  - node: Newly created Java object for the node
    function node = CreateNode(parentNode, nodeType, nodeComment, ...
            nodeFileName, iItem, iStudy, numChildren, dateModified, Modifier)
        import org.brainstorm.tree.*;
        if nargin < 9
            Modifier = 0;
        end
        % Only create Java object is required
        [isCreated, filteredComment] = node_apply_search(iSearch, nodeType, nodeComment, nodeFileName, iStudy);
        if isCreated
            if ~showParentNodes && ~isempty(nodeRoot)
                parentNode = nodeRoot;
            end
            
            % Bold node if it's new (and not already bolded)
            if dateModified > newNodeTime && dateModified > bstStartTime
                % Make sure the node is not already read
                isRead = isKey(ProtocolInfo.iReadFiles, iItem);
                if isRead
                    % Check if node was modified since last read
                    isRead = ProtocolInfo.iReadFiles(iItem) == dateModified;
                end
                if ~isRead && ~strncmp(filteredComment, '<', 1)
                    filteredComment = ['<HTML><B>' filteredComment '</B>'];
                end
            end
            
            node = parentNode.add(nodeType, filteredComment, nodeFileName, iItem, iStudy, Modifier);
            node.setLastModified(dateModified);
            numElems = numElems + 1;
            
            if numChildren > 0
                % Set the node as un-processed
                node.setUserObject(0);
                % Add a "Loading" node
                node.add(BstNode('loading', 'Loading...'));
            end
        else
            node = [];
        end
    end
end

