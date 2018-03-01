function node_create_study(nodeStudy, sStudy, iStudy, isExpandTrials, UseDefaultChannel)
% NODE_CREATE_STUDY: Create study node from study structure.
%
% USAGE:  node_create_study(nodeStudy, sStudy, iStudy, isExpandTrials, UseDefaultChannel)
%
% INPUT: 
%     - nodeStudy : BstNode object with Type 'study' => Root of the study subtree
%     - sStudy    : Brainstorm study structure
%     - iStudy    : indice of the study node in Brainstorm studies list
%     - isExpandTrials    : If 1, force the trials list to be expanded at the subtree creation
%     - UseDefaultChannel : If 1, do not display study's channels and headmodels

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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

    
%% ===== PARSE INPUTS =====
if (nargin < 4) || isempty(isExpandTrials)
    isExpandTrials = 1;
end
if (nargin < 5) || isempty(UseDefaultChannel)
    UseDefaultChannel = 0;
end
% Is the parent a default study node ?
if strcmpi(nodeStudy.getType(), 'defaultstudy')
    isDefaultStudyNode = 1;
else
    isDefaultStudyNode = 0;
end
% Protocol path
ProtocolInfo = bst_get('ProtocolInfo');


%% ===== CHANNEL =====
% Display channel if : default node, or do not use default
if (~UseDefaultChannel || isDefaultStudyNode) && ~isempty(sStudy.Channel)
    nodeStudy.add('channel', sStudy.Channel.Comment , sStudy.Channel.FileName, 1, iStudy);
end

%% ===== HEAD MODEL =====
if ~UseDefaultChannel || isDefaultStudyNode
    for iHeadModel = 1:length(sStudy.HeadModel)
        if isempty(sStudy.HeadModel(iHeadModel).Comment)
            sStudy.HeadModel(iHeadModel).Comment = '';
        end
        % If current item is default one
        if ismember(iHeadModel, sStudy.iHeadModel)
            nodeHeadModel = nodeStudy.add('headmodel', sStudy.HeadModel(iHeadModel).Comment, sStudy.HeadModel(iHeadModel).FileName, iHeadModel, iStudy);
            nodeHeadModel.setMarked(1);
        % Just create node
        else
            nodeStudy.add('headmodel', sStudy.HeadModel(iHeadModel).Comment, sStudy.HeadModel(iHeadModel).FileName, iHeadModel, iStudy);
        end
    end
end

%% ===== NOISE COV =====
% Display NoiseCov if : default node, or do not use default
if (~UseDefaultChannel || isDefaultStudyNode) && ~isempty(sStudy.NoiseCov)
    % Noise covariance
    if ~isempty(sStudy.NoiseCov(1).FileName)
        nodeStudy.add('noisecov', sStudy.NoiseCov(1).Comment , sStudy.NoiseCov(1).FileName, 1, iStudy);
    end
    % Data covariance
    if (length(sStudy.NoiseCov) >= 2) && ~isempty(sStudy.NoiseCov(2).FileName)
        nodeStudy.add('noisecov', sStudy.NoiseCov(2).Comment , sStudy.NoiseCov(2).FileName, 2, iStudy);
    end
end

%% ===== DATA LISTS =====
% Get standardized comments
listComments = cellfun(@str_remove_parenth, {sStudy.Data.Comment}, 'UniformOutput', 0);
% Remove empty matrices
iEmpty = cellfun(@isempty, listComments);
if ~isempty(iEmpty)
    listComments(iEmpty) = {''};
end
% Group comments
[uniqueComments,tmp,iData2List] = unique(listComments);
% Build list of parents
nLists = length(uniqueComments);
if (nLists > 0)
    ListsNodes = javaArray('org.brainstorm.tree.BstNode', nLists);
    % Process each data list
    for iList = 1:nLists
        % Get number of data files per data list
        nDataInList = nnz(iData2List == iList);
        % If more than a given number of data files in this study: group them
        if ((nDataInList ~= length(sStudy.Data)) && (nDataInList >= 5)) || ...
           ((nDataInList == length(sStudy.Data)) && (nDataInList >= 8))
            % Create node and add it to study
            nodeComment = sprintf('%s (%d files)', uniqueComments{iList}, nDataInList);
            ListsNodes(iList) = nodeStudy.add('datalist', nodeComment, uniqueComments{iList}, iList, iStudy);
            % If data lists are not expanded
            if ~isExpandTrials
                % Remove the reference to the list in the iData2List array
                iData2List(iData2List == iList) = 0;
            end
        % Else: display them separately
        else
            % Parent node = directly study node
            ListsNodes(iList) = nodeStudy;
        end
    end
end

%% ===== DATA =====
% Standardize data files
AllDataFiles = {sStudy.Data.FileName};
AllDataFiles = cellfun(@FileStandard, AllDataFiles, 'UniformOutput', 0);
% List of nodes
if ~isempty(AllDataFiles)
    AllDataNodes = javaArray('org.brainstorm.tree.BstNode', length(AllDataFiles));
else
    AllDataNodes = [];
end
% List of ignored data files
isIgnoredData = zeros(1, length(AllDataFiles));
isIgnoredData(iData2List == 0) = 1;
% Get the data nodes that are needed in the tree
iNeededNodes = find(~isIgnoredData);
% For each Data node to display
for i = 1:length(iNeededNodes)
    iData = iNeededNodes(i);
    % Get parent node
    nodeParent = ListsNodes(iData2List(iData));
    % If node has a potential parent in the tree
    if ~isempty(nodeParent)
        % Node comment
        if isempty(sStudy.Data(iData).Comment)
            [temp_, Comment] = bst_fileparts(sStudy.Data(iData).FileName);
        else
            Comment = sStudy.Data(iData).Comment;
        end
        % Node modifier (0=none, 1=bad)
        Modifier = sStudy.Data(iData).BadTrial;
        % Create node
        if strcmpi(sStudy.Data(iData).DataType, 'raw')
            nodeType = 'rawdata';
        else
            nodeType = 'data';
        end
        % Add data file to hash table
        if ~isempty(sStudy.Result) || ~isempty(sStudy.Timefreq) || ~isempty(sStudy.Dipoles)
            AllDataNodes(iData) = nodeParent.add(nodeType, Comment, sStudy.Data(iData).FileName, iData, iStudy, Modifier);
        % Just create the node
        else
            nodeParent.add(nodeType, Comment, sStudy.Data(iData).FileName, iData, iStudy, Modifier);
        end
    end
end



%% ===== RESULT =====
% Standardize data files
AllResultFiles = {sStudy.Result.FileName};
AllResultFiles = cellfun(@FileStandard, AllResultFiles, 'UniformOutput', 0);
% List of nodes
if ~isempty(AllResultFiles)
    AllResultNodes = javaArray('org.brainstorm.tree.BstNode', length(AllResultFiles));
else
    AllResultFiles = [];
end
% List of ignored result files
isIgnoredResult = zeros(1,length(AllResultFiles));
% For each Results node to display
for iResult = 1:length(AllResultFiles)
    % If non-valid node: skip it
    if isempty(AllResultFiles{iResult})
        continue;
    end
    % Results or link
    if isempty(sStudy.Result(iResult).isLink) || ~sStudy.Result(iResult).isLink
        if isempty(sStudy.Result(iResult).DataFile) && ~isempty(strfind(AllResultFiles{iResult}, 'KERNEL'))
            nodeType = 'kernel';
        else
            nodeType = 'results';
        end
    else
        nodeType = 'link';
    end
    Modifier = 0;
    % If stand-alone result (not associated with a data file) => DISPLAY
    if isempty(sStudy.Result(iResult).DataFile)
        % Add results node to study node
        nodeParent = nodeStudy;
    % Dependent result node (child of a data node)
    else
        % Get the name of the data file that was used to calculate the result file
        DataFile = FileStandard(sStudy.Result(iResult).DataFile);
        % Try to find the data filename in the hashtable
        iDataFile = find(strcmp(AllDataFiles, DataFile));
        % Data file not found: Could be in a different study, use the study folder
        if isempty(iDataFile)
            % Use the study folder
            nodeParent = nodeStudy;
            % Try to find file in a different study: it is not, display warning and add warning icon
            if ~exist([ProtocolInfo.STUDIES, filesep, sStudy.Result(iResult).DataFile], 'file')
                disp(['BST> Warning: Results file "' sStudy.Result(iResult).FileName '" misses its data file: "' DataFile '"']);
                Modifier = 1;
            end
        % If data node is ignored: ignore results node as well
        elseif isIgnoredData(iDataFile)
            isIgnoredResult(iResult) = 1;
            continue;
        % Is data node displayed (either stand-alone results file, or children of a data node)
        elseif ~isempty(AllDataNodes(iDataFile))
            nodeParent = AllDataNodes(iDataFile);
        % Error: Skip node
        else
            disp(['BST> Weird error for results file "' sStudy.Result(iResult).FileName '".']);
            continue;
        end
    end
    % If node should be created
    if ~isempty(nodeParent) 
        % Add node to nodes hashtable (so that it is possible to associate a Timefreq map to a results file)
        if ~isempty(sStudy.Timefreq) || ~isempty(sStudy.Dipoles)
            AllResultNodes(iResult) = nodeParent.add(nodeType, sStudy.Result(iResult).Comment, sStudy.Result(iResult).FileName, iResult, iStudy, Modifier);
        else
            nodeParent.add(nodeType, sStudy.Result(iResult).Comment, sStudy.Result(iResult).FileName, iResult, iStudy, Modifier);
        end
    end
end   


%% ===== MATRIX LISTS =====
% Get standardized comments
listComments = cellfun(@str_remove_parenth, {sStudy.Matrix.Comment}, 'UniformOutput', 0);
% Remove empty matrices
iEmpty = cellfun(@isempty, listComments);
if ~isempty(iEmpty)
    listComments(iEmpty) = {''};
end
% Group comments
[uniqueComments,tmp,iMatrix2List] = unique(listComments);
% Build list of parents
nLists = length(uniqueComments);
if (nLists > 0)
    ListsNodes = javaArray('org.brainstorm.tree.BstNode', nLists);
    % Process each data list
    for iList = 1:nLists
        % Get number of data files per data list
        nMatrixInList = nnz(iMatrix2List == iList);
        % If more than a given number of data files in this study: group them
        if ((nMatrixInList ~= length(sStudy.Matrix)) && (nMatrixInList >= 5)) || ...
           ((nMatrixInList == length(sStudy.Matrix)) && (nMatrixInList >= 8))
            % Create node and add it to study
            nodeComment = sprintf('%s (%d files)', uniqueComments{iList}, nMatrixInList);
            ListsNodes(iList) = nodeStudy.add('matrixlist', nodeComment, uniqueComments{iList}, iList, iStudy);
            % If data lists are not expanded
            if ~isExpandTrials
                % Remove the reference to the list in the iMatrix2List array
                iMatrix2List(iMatrix2List == iList) = 0;
            end
        % Else: display them separately
        else
            % Parent node = directly study node
            ListsNodes(iList) = nodeStudy;
        end
    end
end


%% ===== MATRIX =====
% Standardize matrix files
AllMatrixFiles = {sStudy.Matrix.FileName};
AllMatrixFiles = cellfun(@FileStandard, AllMatrixFiles, 'UniformOutput', 0);
% List of nodes
if ~isempty(AllMatrixFiles)
    AllMatrixNodes = javaArray('org.brainstorm.tree.BstNode', length(AllMatrixFiles));
else
    AllMatrixNodes = [];
end
% List of ignored matrix files
isIgnoredMatrix = zeros(1, length(AllMatrixFiles));
isIgnoredMatrix(iMatrix2List == 0) = 1;
% Get the matrix nodes that are needed in the tree
iNeededNodes = find(~isIgnoredMatrix);
% For each Data node to display
for i = 1:length(iNeededNodes)
    iMatrix = iNeededNodes(i);
    % Get parent node
    nodeParent = ListsNodes(iMatrix2List(iMatrix));
    % If node has a potential parent in the tree
    if ~isempty(nodeParent)
        % Node comment
        if isempty(sStudy.Matrix(iMatrix).Comment)
            [temp_, Comment] = bst_fileparts(sStudy.Matrix(iMatrix).FileName);
        else
            Comment = sStudy.Matrix(iMatrix).Comment;
        end
        % Add matrix file to hash table
        if ~isempty(sStudy.Result) || ~isempty(sStudy.Timefreq)
            AllMatrixNodes(iMatrix) = nodeParent.add('matrix', Comment, sStudy.Matrix(iMatrix).FileName, iMatrix, iStudy);
        % Just create the node
        else
            nodeParent.add('matrix', Comment, sStudy.Matrix(iMatrix).FileName, iMatrix, iStudy);
        end
    end
end


%% ===== TIMEFREQ =====
% Display time-frequency nodes
for i = 1:length(sStudy.Timefreq)
    Modifier = 0;
    nodeParent = [];
    % If stand-alone file (not associated with a data file) => DISPLAY
    if isempty(sStudy.Timefreq(i).DataFile)
        % Add node to study node
        nodeParent = nodeStudy;
    % Dependent node (child of another data/results node)
    else   
        % Get the name of the data file that was used to calculate the file
        DataFile = FileStandard(sStudy.Timefreq(i).DataFile);
        % Get file type
        fileType = file_gettype(DataFile);
        % Try to find the data filename in the three filenames lists
        switch (fileType)
            case {'data', 'raw'}
                iDataFile = find(strcmp(AllDataFiles, DataFile));
                % Data file not found: display in study node, add warning icon
                if isempty(iDataFile)
                    disp(['BST> Warning: Time-freq file "' sStudy.Timefreq(i).FileName '" misses its data file: "' DataFile '"']);
                    nodeParent = nodeStudy;
                    Modifier = 1;
                % If data node is ignored: ignore results node as well
                elseif isIgnoredData(iDataFile)
                    continue;
                % Is data node displayed (either stand-alone results file, or children of a data node)
                else
                    nodeParent = AllDataNodes(iDataFile);
                end
            case {'link', 'results'}
                iDataFile = find(strcmp(AllResultFiles, DataFile));
                % Results file not found: display in study node, add warning icon
                if isempty(iDataFile)
                    disp(['BST> Warning: Time-freq file "' sStudy.Timefreq(i).FileName '" misses its result file: "' DataFile '"']);
                    nodeParent = nodeStudy;
                    Modifier = 1;
                % If data node is ignored: ignore results node as well
                elseif isIgnoredResult(iDataFile)
                    continue;
                % Is data node displayed (either stand-alone results file, or children of a data node)
                else
                    nodeParent = AllResultNodes(iDataFile);
                end
            case 'matrix'
                iDataFile = find(strcmp(AllMatrixFiles, DataFile));
                if isempty(iDataFile)
                    disp(['BST> Warning: Time-freq file "' sStudy.Timefreq(i).FileName '" misses its matrix file: "' DataFile '"']);
                    continue;
                else
                    nodeParent = AllMatrixNodes(iDataFile);
                end
        end
    end
    % If node should be created
    if ~isempty(nodeParent)
        % TF or PSD node
        if ~isempty(strfind(sStudy.Timefreq(i).FileName, '_psd')) || ~isempty(strfind(sStudy.Timefreq(i).FileName, '_fft'))
            nodeType = 'spectrum';
        else
            nodeType = 'timefreq';
        end
        % Add node to parent node
        nodeParent.add(nodeType, sStudy.Timefreq(i).Comment, sStudy.Timefreq(i).FileName, i, iStudy, Modifier);
    end
end


%% ===== DIPOLES =====
% Display dipoles
for i = 1:length(sStudy.Dipoles)
    % If stand-alone file (not associated with a data file) => DISPLAY
    if isempty(sStudy.Dipoles(i).DataFile)
        % Add node to study node
        nodeParent = nodeStudy;
    else
        % Get the name of the results file that was used to calculate the file
        DataFile = FileStandard(sStudy.Dipoles(i).DataFile);
        
        % === DEPENDS ON RESULTS ===
        % Try to locate parent file as a results file
        iResFile = find(strcmp(AllResultFiles, DataFile));
        if ~isempty(iResFile)
            if isIgnoredResult(iResFile)
                continue;
            else
                nodeParent = AllResultNodes(iResFile);
            end
        % Try to locate parent file as a data file
        else
            iDataFile = find(strcmp(AllDataFiles, DataFile));
            if ~isempty(iDataFile)
                if isIgnoredData(iDataFile)
                    continue;
                else
                    nodeParent = AllDataNodes(iDataFile);
                end
            end
        end
        % Parent file not found: display in study node
        if isempty(nodeParent)
            disp(['BST> Warning: Dipole file "' sStudy.Dipoles(i).FileName '" misses its parent file: "' DataFile '"']);
            nodeParent = nodeStudy;
        end
    end
    % If node should be created
    if ~isempty(nodeParent)
        % Add node to parent node
        nodeParent.add('dipoles', sStudy.Dipoles(i).Comment, sStudy.Dipoles(i).FileName, i, iStudy);
    end
end


%% ===== STAT =====
% Display stat node
if isfield(sStudy, 'Stat')
    for iStat = 1:length(sStudy.Stat)
        % Get node infor
        nodeComment = sStudy.Stat(iStat).Comment;
        statType    = sStudy.Stat(iStat).Type;
        if isempty(statType)
            continue;
        end
        % Node type
        switch (statType)
            case 'data'
                nodeType = 'pdata';
            case 'results'
                nodeType = 'presults';
            case 'timefreq'
                % TF or PSD node
                if ~isempty(strfind(sStudy.Stat(iStat).FileName, '_psd')) || ~isempty(strfind(sStudy.Stat(iStat).FileName, '_fft'))
                    nodeType = 'pspectrum';
                else
                    nodeType = 'ptimefreq';
                end
            case 'matrix'
                nodeType = 'pmatrix';
            otherwise
                nodeType = statType;
        end
        % Create node
        nodeStudy.add(nodeType, nodeComment , sStudy.Stat(iStat).FileName, iStat, iStudy);
    end
end


%% ===== IMAGES =====
% Display images nodes
for iImage = 1:length(sStudy.Image)
    % Get file type
    fileType = file_gettype(sStudy.Image(iImage).FileName);
    % Image node
    if strcmpi(fileType, 'image')
        nodeStudy.add('image', sStudy.Image(iImage).Comment, sStudy.Image(iImage).FileName, iImage, iStudy);
    elseif strcmpi(fileType, 'videolink')
        nodeStudy.add('video', sStudy.Image(iImage).Comment, sStudy.Image(iImage).FileName, iImage, iStudy);
    end
end

end



%% =================================================================================================
%  ====== SUPPORT FUNCTIONS ========================================================================
%  =================================================================================================
function FileName = FileStandard(FileName)
    % Replace '\' with '/'
    FileName(FileName == '\') = '/';
    % Remove first slash (filenames all relative)
    if (FileName(1) == '/')
        FileName = FileName(2:end);
    end
end

