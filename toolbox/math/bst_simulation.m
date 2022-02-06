function newDataFile = bst_simulation(ResultsFile, iVertices, Comment, isVolumeAtlas)
% BST_SIMULATION:  Create a pseudo-recordings file by multiplying the forward model with the sources.
%
% USAGE:  newDataFile = bst_simulation(ResultsFile, iVertices, Comment='', isVolumeAtlas=0)
%         newDataFile = bst_simulation(ResultsFile, iVertices)  : Use only the selected vertices
%         newDataFile = bst_simulation(ResultsFile)             : Use all the vertices
%
% INPUT:
%     - ResultsFile : Full or relative path to a brainstorm sources file
%     - iVertices   : Indices of the sources to use to simulate the recordings
%     - Comment     : Comment inserted in the created file
% OUTPUT:
%     - newDataFile : Full path to the simulated recordings file created and saved in the database

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c) University of Southern California & McGill University
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
% Authors: Francois Tadel, 2009-2015

%% ===== PARSE INPUTS =====
global GlobalData;
% Is iVertices obtained on a volume atlas
if (nargin < 4) || isempty(isVolumeAtlas)
    isVolumeAtlas = 0;
end
% No comment
if (nargin < 3)
    Comment = '';
end
% No vertices specified, take them all
if (nargin < 2)
    iVertices = [];
end
% Get the protocol folders
ProtocolInfo = bst_get('ProtocolInfo');


%% ===== LOAD SOURCES =====
bst_progress('start', 'Simulation', 'Loading sources...');
% Load results matrix
[iDS, iResult] = bst_memory('LoadResultsFileFull', ResultsFile);
if isempty(iDS)
    return
end
% Load the method used for estimating these sources
ResultsMat = in_bst_results(ResultsFile, 0,  'HeadModelFile', 'Function', 'DataFile');
% Check the type of results file
if ~isempty(GlobalData.DataSet(iDS).Results(iResult).Atlas)
    bst_error('Cannot process sources that have been downsampled based on an atlas.', 'bst_simulation', 0);
    return;
elseif ~ismember(ResultsMat.Function, {'wmne', 'mn'})
    bst_error('The simulation of recordings is only available for current density maps (minimum norm without normalization).', 'bst_simulation', 0);
    return;
end
% Get associated data file
if ~isempty(ResultsMat.DataFile)
    DataFile = file_short(ResultsMat.DataFile);
else
    DataFile = [];
end
% Get some of the loaded values
nComponents = GlobalData.DataSet(iDS).Results(iResult).nComponents;
GridAtlas   = GlobalData.DataSet(iDS).Results(iResult).GridAtlas;
% Get number of grid points that this inverse model uses
if (nComponents == 0)
    % Error if the grid atlas is not available
    if isempty(GridAtlas)
        bst_error('The field GridAtlas is necessary for mixed head models.', 'bst_simulation', 0);
        return;
    end
    % Count the number of head model dipoles needed for each
    nLocResults = length([GridAtlas.Scouts.GridRows]);
else
    nSrc = max(size(GlobalData.DataSet(iDS).Results(iResult).ImagingKernel,1), size(GlobalData.DataSet(iDS).Results(iResult).ImageGridAmp,1));
    nLocResults = round(nSrc ./ nComponents);
end
% If some vertices are specified: Convert their indices
if ~isempty(iVertices)
    % Make sure vertices are sorted and unique
    iVertices = sort(unique(iVertices));
    % Convert to indices from surface index to source matrix
    [iSourceRows, iRegionScouts] = bst_convert_indices(iVertices, nComponents, GridAtlas, ~isVolumeAtlas);
    % Handle scout selection error
    if (nComponents == 0)
        % Select vertices are not part of the source model 
        if isempty(iRegionScouts)
            bst_error(['The selected scout is not included in the source model.'  10 'If you use this region as a volume, create a volume scout instead (menu Atlas > New atlas > Volume scouts).'], 'bst_simulation', 0);
            return;
        % Do not accept scouts that span over multiple regions
        elseif (length(iRegionScouts) > 1)
            bst_error('The selected scout spans over multiple regions of the "Source model" atlas.', 'bst_simulation', 0);
            return;
        end
    end
else
    iSourceRows = [];
end


% ===== LOAD GAIN MATRIX =====
bst_progress('text', 'Loading head model...');
% Get study
[sStudy, iStudy] = bst_get('ResultsFile', ResultsFile);
% Get default headmodel for this study
sHeadModel = bst_get('HeadModelForStudy', iStudy);
if isempty(sHeadModel)
    bst_error('No headmodel available for this study.', 'bst_simulation', 0);
    return;
end
HeadModelFile = sHeadModel.FileName;
% Load HeadModel file
HeadModelMat = in_bst_headmodel(HeadModelFile, 0, 'Gain', 'GridLoc', 'GridOrient', 'GridAtlas');
% Number of dipoles in headmodel
nLocHeadmodel = size(HeadModelMat.GridLoc, 1);

% If the head model doesn't match the number of vertices: try loading the head model pointed by the results file
if (nLocHeadmodel ~= nLocResults)
    % Get headmodel file from ResultsFile
    HeadModelFile = ResultsMat.HeadModelFile;
    % Load HeadModel file
    HeadModelMat = in_bst_headmodel(HeadModelFile, 0, 'Gain', 'GridLoc', 'GridOrient', 'GridAtlas');
    % Number of dipoles in headmodel
    nLocHeadmodel = size(HeadModelMat.GridLoc, 1);
    % Check again the number of vertices
    if (nLocHeadmodel ~= nLocResults)
        bst_error(sprintf('Number of dipoles in the head model (%d) and the inverse model (%d) do not match.', nLocHeadmodel, nLocResults), 'bst_simulation', 0);
        return;
    end
end
% If no orientations: error
if (nComponents ~= 3) && isempty(HeadModelMat.GridOrient)
    bst_error('No source orientations available in this head model.', 'bst_simulation', 0);
    return;
% Check if inverse and forward models share the same atlas (mixed head models only)
elseif ~isempty(GridAtlas) && ~isempty(HeadModelMat.GridAtlas) && ~isequal(HeadModelMat.GridAtlas.Scouts, GridAtlas.Scouts)
    bst_error('For mixed head models: head model and inverse model must be calculated using the same atlas.', 'bst_simulation', 0);
    return;
end
% Display mesasge to illustrate the 
disp(['BST> Simulation: Using head model file "' HeadModelFile '"']);
% Constrain head model to match the source model (normal to the cortex or mixed)
switch (nComponents)
    case 0,   HeadModelMat.Gain = bst_gain_orient(HeadModelMat.Gain, HeadModelMat.GridOrient, GridAtlas);
    case 1,   HeadModelMat.Gain = bst_gain_orient(HeadModelMat.Gain, HeadModelMat.GridOrient);
end      


%% ===== SIMULATION LOOP =====
% Get time vector
TimeVector = bst_memory('GetTimeVector', iDS, iResult, 'UserTimeWindow');
% Maximum number of time points to process at once
blockSize = 100;
% Compute number of blocks
nBlocks = ceil(length(TimeVector) / blockSize);
% Initialize simulated matrix
nTime = length(TimeVector);
F = zeros(size(HeadModelMat.Gain,1), nTime);
% Progress bar
bst_progress('start', 'Simulation', 'Simulating recordings...', 0, nBlocks);
% Process each time block
for iBlock = 1:nBlocks
    bst_progress('inc', 1);
    % Get time indices
    iTime = ((iBlock-1)*blockSize+1) : min(iBlock * blockSize, nTime);
    % Get sources matrix
    ResultsValues = bst_memory('GetResultsValues', iDS, iResult, iVertices, iTime, 0, isVolumeAtlas);    
    % Simulate recordings: Gain * Sources
    if ~isempty(iVertices)
        F(:,iTime) = HeadModelMat.Gain(:,iSourceRows) * ResultsValues;
    else
        F(:,iTime) = HeadModelMat.Gain * ResultsValues;
    end
end
% Remove NaN values
F(isnan(F)) = 0;


%% ===== BUILD SIMULATED DATA FILE =====
% Progress bar
bst_progress('start', 'Simulation', 'Saving simulated recordings...');
% Get a string to represent time
c = clock;
strTime = sprintf('%02.0f%02.0f%02.0f_%02.0f%02.0f', c(1)-2000, c(2:5));
% Build comment
DataComment = ['Simulation: ' Comment ' ' GlobalData.DataSet(iDS).Results(iResult).Comment ' (' strTime ')'];
% Build data file
DataMat = db_template('DataMat');
DataMat.Comment     = DataComment;
DataMat.Time        = TimeVector;
DataMat.F           = F;
DataMat.ChannelFlag = GlobalData.DataSet(iDS).Results(iResult).ChannelFlag;
DataMat.DataType    = 'recordings';
% History
DataMat = bst_history('add', DataMat, 'simulation', 'File simulated: Headmodel * Results');
DataMat = bst_history('add', DataMat, 'simulation', [' - Head model file: ' HeadModelFile]);
DataMat = bst_history('add', DataMat, 'simulation', [' - Results file file: ' ResultsFile]);


%% ===== SAVE FILE =====
% Output file
if isempty(DataFile)
    outputFolder = bst_fileparts(GlobalData.DataSet(iDS).StudyFile);
    newDataFile = bst_fullfile(ProtocolInfo.STUDIES, outputFolder, ['data_simulation_', strTime, '.mat']);
else
    newDataFile = bst_fullfile(ProtocolInfo.STUDIES, strrep(DataFile, '.mat', '_simulation.mat'));
end
newDataFile = file_unique(newDataFile);
% Save file
bst_save(newDataFile, DataMat, 'v6');

% ===== UPDATE DATABASE =====
% Unloading dataset
bst_memory('UnloadDataSets', iDS);
% Get study
[sStudy, iStudy, iResult] = bst_get('ResultsFile', ResultsFile);
% Add to database
[sStudy, iNewData] = db_add_data(iStudy, newDataFile, DataMat);
% Update links
db_links('Study', iStudy);
% Update display
panel_protocols('UpdateNode', 'Study', iStudy);
% Select node
%panel_protocols('SelectStudyNode', iStudy);
panel_protocols('SelectNode', [], 'data', iStudy, iNewData);
% Hide progress bar 
bst_progress('stop');



