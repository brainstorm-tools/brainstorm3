function tutorial_dba(zip_file, reports_dir)
% TUTORIAL_DBA: script that runs the Brainstorm deep brain activity (DBA) tutorial.
% https://neuroimage.usc.edu/brainstorm/Tutorials/DeepAtlas
%
% INPUTS:
%    - zip_file     : Full path to the TutorialDba.zip file
%    - reports_dir  : Directory where to save the execution report (instead of displaying it)
%
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
% Author: Raymundo Cassani, 2024

% Output folder for reports
if (nargin < 2) || isempty(reports_dir) || ~exist(reports_dir, 'dir')
    reports_dir = [];
end
% You have to specify the folder in which the tutorial dataset is unzipped
if (nargin == 0) || isempty(zip_file) || ~file_exist(zip_file)
    error('The first argument must be the full path to the dataset zip file.');
end

%% ===== MIXED MODEL PARAMETERS =====
% Cortex name
cortexComment    = 'cortex_15002V';
% Surface with subcortical segmentation (ASEG)
subCortexComment = 'aseg atlas';
% Subcortical structures to keep from ASEG
subCortexKeep    = {'Amygdala L', 'Amygdala R', 'Hippocampus L', 'Hippocampus R',  'Thalamus L', 'Thalamus R'};
% Mixed cortex name
mixedComment     = 'cortex_mixed' ;

% Mixed model structures: Cortex + Subcortical structures
% Table with structures, and their locations and orientations constraints
%  Location constraint   : 'Surface', 'Volume', 'Deep brain'*, 'Exclude'
%  Orientation constraint: 'Constrained', 'Unconstrained', 'Loose'
%  * If 'Deep brain' is used as location constraint the location and orientation constraints
%    will be set automatically according to the scout name.
%
%               'ScoutName'    , 'Location'  , 'Orientation'
mixedStructs = {'Amygdala L'   , 'Deep brain', ''; ... % Deep brain --> Volume , Unconstrained
                'Amygdala R'   , 'Deep brain', ''; ... % Deep brain --> Volume , Unconstrained
                'Hippocampus L', 'Deep brain', ''; ... % Deep brain --> Surface, Constrained
                'Hippocampus R', 'Deep brain', ''; ... % Deep brain --> Surface, Constrained
                'Thalamus L'   , 'Deep brain', ''; ... % Deep brain --> Volume,  Unconstrained
                'Thalamus R'   , 'Deep brain', ''; ... % Deep brain --> Volume,  Unconstrained
                'Cortex L'     , 'Deep brain', ''; ... % Deep brain --> Surface, Constrained
                'Cortex R'     , 'Deep brain', ''};    % Deep brain --> Surface, Constrained


%% ===== LOAD PROTOCOL =====
% Start brainstorm without the GUI
if ~brainstorm('status')
    brainstorm nogui
end
% Check Brainstorm mode
if bst_get('GuiLevel') < 0
    error('For the moment the tutorial "tutorial_dba" is not supported on Brainstorm server mode.');
end
ProtocolName = 'TutorialDba';
[~, fBase] = bst_fileparts(zip_file);
if ~strcmpi(fBase, ProtocolName)
    error('Incorrect .zip file.');
end
% Delete existing protocol
gui_brainstorm('DeleteProtocol', ProtocolName);
% Import protocol from zip file
import_protocol(zip_file);
% Start a new report
bst_report('Start');


%% ===== SELECT DEEP STRUCTURES =====
% Get Subject for Default Anatomy
sSubject = bst_get('Subject', bst_get('DirDefaultSubject'));
% Find subcortical atlas, and downsize it
iAseg = find(strcmpi(subCortexComment, {sSubject.Surface.Comment}));
newAsegFile = tess_downsize(sSubject.Surface(iAseg).FileName, 15000, 'reducepatch');
% Create atlas with only selected structures
panel_scout('SetCurrentSurface', newAsegFile);
sScouts = panel_scout('GetScouts');
[~, iScouts] = ismember(subCortexKeep, {sScouts.Label});
panel_scout('SetSelectedScouts', iScouts);
newAsegFile = panel_scout('NewSurface', 1);
% Find cortex
sSubject = bst_get('Subject', bst_get('DirDefaultSubject'));
iCortex = find(strcmpi(cortexComment, {sSubject.Surface.Comment}));
% Merge cortex with selected DBA structures
mixedFile = tess_concatenate({sSubject.Surface(iCortex).FileName, newAsegFile}, mixedComment, 'Cortex');
% Atlas with structures
atlasName = 'Structures';
% Display mixed cortex
hFigMix = view_surface(mixedFile);
[~, sSurf] = panel_scout('GetScouts');
iAtlas = find(strcmpi(atlasName, {sSurf.Atlas.Name}));
panel_scout('SetCurrentAtlas', iAtlas, 1);
panel_surface('SelectHemispheres', 'struct');
bst_report('Snapshot', hFigMix, mixedFile, 'Mix cortex: Cortex + Subcortical structures');
pause(1);
% Unload everything
bst_memory('UnloadAll', 'Forced');


%% ===== LOCATIONS AND ORIENTATIONS CONSTRAINTS =====
% Select atlas with structures
panel_scout('SetCurrentSurface', mixedFile);
[~, sSurf] = panel_scout('GetScouts');
iAtlas = find(strcmpi(atlasName, {sSurf.Atlas.Name}));
panel_scout('SetCurrentAtlas', iAtlas, 1);
% Create source model atlas
panel_scout('CreateAtlasInverse');
% Set modeling options
sScouts = panel_scout('GetScouts');
% Set location and orientation constraints
for iScout = 1 : length(sScouts)
    % Select this scout
    iRow = find(ismember(sScouts(iScout).Label, mixedStructs(:,1)));
    % Set location constraint
    panel_scout('SetLocationConstraint', iScout, mixedStructs{iRow,2});
    % Set orientation constraint
    panel_scout('SetOrientationConstraint', iScout, mixedStructs{iRow,3});
end
% Unload everything
bst_memory('UnloadAll', 'Forced');


%% ===== SOURCE ESTIMATION =====
% Find all recordings files for all Subjects, except 'Empty_Subject'
% Process: Select data files in: */*/Trial (#1)
sRecFiles = bst_process('CallProcess', 'process_select_files_data', [], [], ...
    'subjectname',   'All', ...
    'condition',     '', ...
    'tag',           '', ...
    'includebad',    0, ...
    'includeintra',  0, ...
    'includecommon', 0);
iDelete = strcmpi('Empty_Subject', {sRecFiles.SubjectName});
sRecFiles(iDelete) = [];

% Process: Compute head model
bst_process('CallProcess', 'process_headmodel', sRecFiles, [], ...
    'comment',      '', ...
    'sourcespace',  3, ...
    'meg',          3);  % Overlapping spheres

% Display surface and volume grids
sStudy = bst_get('AnyFile', sRecFiles(1).FileName);
headmodelFile = sStudy.HeadModel.FileName;
hFigSrfGrid = view_gridloc(file_fullpath(headmodelFile), 'S');
hFigVolGrid = view_gridloc(file_fullpath(headmodelFile), 'V');
figure_3d('SetStandardView', hFigSrfGrid, 'top');
figure_3d('SetStandardView', hFigVolGrid, 'top');
bst_report('Snapshot', hFigSrfGrid, headmodelFile, 'Mix head model, surface grid');
bst_report('Snapshot', hFigVolGrid, headmodelFile, 'Mix head model, volume grid');
pause(1);
close([hFigSrfGrid, hFigVolGrid]);

% Minimum norm options
InverseOptions = struct(...
    'Comment',        'MN: MEG', ...
    'InverseMethod',  'minnorm', ...
    'InverseMeasure', 'amplitude', ...
    'SourceOrient',   [], ...
    'Loose',          0.2, ...
    'UseDepth',       1, ...
    'WeightExp',      0.5, ...
    'WeightLimit',    10, ...
    'NoiseMethod',    'reg', ...
    'NoiseReg',       0.1, ...
    'SnrMethod',      'fixed', ...
    'SnrRms',         1e-6, ...
    'SnrFixed',       3, ...
    'ComputeKernel',  1, ...
    'DataTypes',      {{'MEG'}});

% Process: Compute sources [2018]
sSrcFiles = bst_process('CallProcess', 'process_inverse_2018', sRecFiles, [], ...
    'output',  1, ...  % Kernel only: one per file
    'inverse', InverseOptions);

% Display sources
hSrcFig = view_surface_data([], sSrcFiles(1).FileName);
panel_time('SetCurrentTime',  4.897);
bst_report('Snapshot', hSrcFig, sSrcFiles(1).FileName);
panel_surface('SelectHemispheres', 'struct');
bst_report('Snapshot', hSrcFig, sSrcFiles(1).FileName);
pause(1);

% Unload everything
bst_memory('UnloadAll', 'Forced');


%% ===== COMPUTE STATISTICS =====
% Process: MEAN: [all], abs
sSrcAvgFiles = bst_process('CallProcess', 'process_average_time', sSrcFiles, [], ...
    'timewindow', [], ...
    'avg_func',   'mean', ...  % Arithmetic average:  mean(x)
    'overwrite',  0, ...
    'source_abs', 1);
% Split average source files by condition
% YF = 'Eyes closed'
iYF = strcmpi('YF', {sSrcAvgFiles.Condition});
sYfSrcAvgFiles = sSrcAvgFiles(iYF);
iYO = strcmpi('YO', {sSrcAvgFiles.Condition});
sYoSrcAvgFiles = sSrcAvgFiles(iYO);
% Process: Perm t-test equal [all]          H0:(A=B), H1:(A<>B)
sTestFile = bst_process('CallProcess', 'process_test_permutation2', sYfSrcAvgFiles, sYoSrcAvgFiles, ...
    'timewindow',     [], ...
    'scoutsel',       {}, ...
    'scoutfunc',      1, ...  % Mean
    'isnorm',         0, ...
    'avgtime',        0, ...
    'iszerobad',      0, ...
    'Comment',        '', ...
    'test_type',      'ttest_equal', ...  % Student's t-test   (equal variance) t = (mean(A)-mean(B)) / (Sx * sqrt(1/nA + 1/nB))Sx = sqrt(((nA-1)*var(A) + (nB-1)*var(B)) / (nA+nB-2))
    'randomizations', 1000, ...
    'tail',           'two');  % Two-tailed

% Set display properties
StatThreshOptions = bst_get('StatThreshOptions');
StatThreshOptions.pThreshold = 0.01;
StatThreshOptions.Correction = 'fdr';
StatThreshOptions.Control    = [1 2 3];
bst_set('StatThreshOptions', StatThreshOptions);
% Display test result
hSrcFig = view_surface_data([], sTestFile.FileName);
panel_surface('SelectHemispheres', 'left');
panel_stat('UpdatePanel');
bst_report('Snapshot', hSrcFig, sTestFile.FileName);
pause(1);
% Unload everything
bst_memory('UnloadAll', 'Forced');


%% ===== VOLUME SCOUTS =====
volumeScouts = {'Amygdala L', 'Amygdala R', 'Thalamus L', 'Thalamus R'};
% Load one source file
resultsMat = in_bst_results(sSrcFiles(1).FileName);
% Get headmodel, needed to retrieve information about the source grid
headmodelMat = in_bst_headmodel(resultsMat.HeadModelFile);
% Create volume atlas
sAtlas = db_template('atlas');
sAtlas.Name = sprintf('Volume %d', size(headmodelMat.GridLoc, 1));
panel_scout('SetCurrentSurface', headmodelMat.SurfaceFile);
panel_scout('SetAtlas', [], 'Add', sAtlas);
% Create a volume scout for each volume structure
iNewScouts = zeros(1,length(volumeScouts));
for ix = 1 : length(volumeScouts)
    % Index of the structure in the Grid Atlas (in headmodel data)
    iGridScout = find(strcmpi(volumeScouts{ix}, {headmodelMat.GridAtlas.Scouts.Label}));
    % New scout
    sNewScout = db_template('Scout');
    sNewScout.Label    = headmodelMat.GridAtlas.Scouts(iGridScout).Label;
    sNewScout.Vertices = headmodelMat.GridAtlas.Scouts(iGridScout).GridRows;
    sNewScout.Region   = headmodelMat.GridAtlas.Scouts(iGridScout).Region(1);
    sNewScout          = panel_scout('SetScoutsSeed', sNewScout, headmodelMat.GridLoc);
    % Register new scout
    iNewScout = panel_scout('SetScouts', [], 'Add', sNewScout);
    iNewScouts(ix) = iNewScout;
end
% Configure scouts display
panel_scout('SetScoutsOptions', 1, 1, 1, 'all', 0.7, 1, 1, 0);
hFigScouts = view_scouts({sSrcFiles(1).FileName}, iNewScouts);
bst_report('Snapshot', hFigScouts, sSrcFiles(1).FileName, 'Volume scouts');
pause(1);
% Unload everything
bst_memory('UnloadAll', 'Forced');


%% ===== SAVE REPORT =====
% Save and display report
ReportFile = bst_report('Save', []);
if ~isempty(reports_dir) && ~isempty(ReportFile)
    bst_report('Export', ReportFile, reports_dir);
else
    bst_report('Open', ReportFile);
end


