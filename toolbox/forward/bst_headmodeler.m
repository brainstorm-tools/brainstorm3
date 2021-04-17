function [OPTIONS, errMessage] = bst_headmodeler(OPTIONS)
% BST_HEADMODELER: Solution to the MEG/EEG forward problem.
% 
% USAGE:  [OPTIONS, errMessage] = bst_headmodeler(OPTIONS);   % Compute head model
%         [OPTIONS, errMessage] = bst_headmodeler;            % Just return the default OPTIONS structure
%
% INPUTS:  OPTIONS structure with following fields
%     .HeadModelFile : Output filename or directory. Leave empty for default filename in current folder.
%     .Comment       : A character string that specifies the name of the headmodel (display only)
%                      Leave empty for default headmodel name.
%
%     ======= CHANNELS ====================================================
%     .Channel    : A full Brainstorm channel structure.
%     .MegRefCoef : Matrix of coefficients for MEG correction (CTF machine only)
%
%     ======= METHOD SELECTION ============================================
%     .MEGMethod:  Method used to compute the forward model for MEG sensors.
%         - 'meg_sphere': Spherical head model designed following the Sarvas analytical formulation (i.e.
%                         considering the true orientation of the magnetic field sensors) (see OPTIONS.HeadCenter)
%         - 'os_meg'    : MEG overlapping sphere forward model
%         - 'openmeeg'  : OpenMEEG forward model
%     .EEGMethod:  Method used to compute the forward model for EEG sensors.
%         - 'eeg_3sphereberg' : EEG forward modeling with a set of 3 concentric spheres (Scalp, Skull, Brain/CSF) 
%         - 'openmeeg'        : OpenMEEG forward model
%     .SEEGMethod:    'openmeeg' and 'duneuro'  
%     .ECOGMethod:    'openmeeg' and 'duneuro' 
%
%     ======= METHODS OPTIONS =============================================
%     OpenMEEG: see bst_openmeeg
%     DUNEuro: see bst_duneuro
%
%     ======= HEAD DEFINITION =============================================
%     .CortexFile     : Gray/white or gray/csf interface (also used as source space if source space not secified)
%     .HeadFile       : Head surface (used for volume head models with full head volume)
%     .InnerSkullFile : Surface used to estimate the overlapping spheres.
%     .HeadCenter   : [x,y,z] coordinates of the center of the spheres in the sensors coordinate system
%     .Radii        : [Rcsf, Routerskull, Rscalp], radii of the 3 spheres for EEG models (default: [.88 .93 1])
%     .Conductivity : [Ccsf, Cskull, Cscalp] conductivity of the different tissues. (default: [.33 .0042 .33])
%
%      ======= SOURCE SPACE ===============================================
%      .HeadModelType      : {'surface', 'volume'}
%      .SourceSpaceOptions : Structure of options for the selected source space type
%      .CortexFile   : File name of a Brainstorm tessellation file containing the cortex tessellation,
%                      Use it as the source space if present.
%      .GridLoc      : Nx3 matrix that contains the locations of the sources at which the forward model
%                      will be computed. Default is empty (Information taken from OPTIONS.CortexFile).
%      .GridOrient   : Nx3 matrix that describes the orientation for each source
%      .GridOptions  : Necessary information to compute the grid if the above fields are not available (see bst_sourcegrid.m)
%
% OUTPUT:
%      - Returns the OPTIONS structure with updated fields following the call to BST_HEADMODELER.  

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
% Authors: Sylvain Baillet, March 2002
%          Francois Tadel, 2009-2019

errMessage = [];

%% ===== DEFAULTS ==================================================================================
%  =================================================================================================
Def_OPTIONS = struct(...
    'Comment',            '', ...
    'HeadModelFile',      '', ...
    'HeadModelType',      'surface',...
    'Channel',            [], ...
    'MegRefCoef',         [], ...
    'MEGMethod',          'meg_sphere', ...
    'EEGMethod',          'eeg_3sphereberg', ...
    'ECOGMethod',         'openmeeg', ...
    'SEEGMethod',         'openmeeg', ...
    'HeadCenter',         [],...
    'Radii',              [.88 .93 1],...
    'Conductivity',       [.33 .0042 .33],...
    'SourceSpaceOptions', [], ...
    'CortexFile',         [], ...
    'HeadFile',           [], ...
    'InnerSkullFile',     [], ...
    'OuterSkullFile',     [], ...
    'GridOptions',        [], ... 
    'GridLoc',            [], ...
    'GridOrient',         [], ...
    'GridAtlas',          [], ...
    'Interactive',        1);

%% ===== PARSE INPUTS ==============================================================================
%  =================================================================================================
% CALL:  [OPTIONS] = bst_headmodeler;
if (nargin == 0)
    OPTIONS = Def_OPTIONS;
    return
elseif (nargin ~= 1)
    errMessage = 'Wrong number of arguments when calling head modeler';
    OPTIONS = [];
    return;
end
strHistory = [];
% Fill missing OPTIONS fields with defaults
OPTIONS = struct_copy_fields(OPTIONS, Def_OPTIONS, 0);
% Start progress bar
bst_progress('start', 'Head modeler', 'Initialization...');

% === CHECK SOME FIELDS ====
% Channel structure is mandatory
if isempty(OPTIONS.Channel)
    errMessage = 'Channel structure not defined.';
    OPTIONS = [];
    return;
end
% No sources locations specified
if strcmpi(OPTIONS.HeadModelType, 'surface') && ~isempty(OPTIONS.GridLoc) && (size(OPTIONS.GridOrient,1) ~= size(OPTIONS.GridLoc,1))
    errMessage = 'Size of GridOrient and GridLoc do not match.';
    OPTIONS = [];
    return;
end
% Check BFS
isBFS = strcmpi(OPTIONS.MEGMethod, 'meg_sphere') || strcmpi(OPTIONS.EEGMethod, 'eeg_3sphereberg');
% Computation of parameters of the best-fitting sphere --------------------------------------------------------------------------------------------------------------
if isBFS && (isempty(OPTIONS.HeadCenter) || isempty(OPTIONS.Radii) || isempty(OPTIONS.Conductivity))
    errMessage = ['Following options must be defined: HeadCenter, Radii, Conductivity.', 10, ...
                  'Please use Brainstorm GUI to compute the forward model.'];
    OPTIONS = [];
    return;
end
% Number of columns per source
Dims = 3;


%% ===== GET CHANNEL INFO ==========================================================================
%  =================================================================================================
% Get MEG and EEG channel indices
iMeg  = good_channel(OPTIONS.Channel,[],'MEG');
iRef  = good_channel(OPTIONS.Channel,[],'MEG REF');
iEeg  = good_channel(OPTIONS.Channel,[],'EEG');
iEcog = good_channel(OPTIONS.Channel,[],'ECOG');
iSeeg = good_channel(OPTIONS.Channel,[],'SEEG');
% If no channels available for one type: ignore method
if isempty(iMeg)
    OPTIONS.MEGMethod = '';
elseif isempty(OPTIONS.MEGMethod)
    iMeg = [];
    iRef = [];
end
if isempty(iEeg)
    OPTIONS.EEGMethod = '';
elseif isempty(OPTIONS.EEGMethod)
    iEeg = [];
end
if isempty(iEcog)
    OPTIONS.ECOGMethod = '';
elseif isempty(OPTIONS.ECOGMethod)
    iEcog = [];
end
if isempty(iSeeg)
    OPTIONS.SEEGMethod = '';
elseif isempty(OPTIONS.SEEGMethod)
    iSeeg = [];
end
if isempty(OPTIONS.EEGMethod) && isempty(OPTIONS.MEGMethod) && isempty(OPTIONS.ECOGMethod) && isempty(OPTIONS.SEEGMethod)
    errMessage = 'Nothing to process...';
    OPTIONS = [];
    return;
end
% IGNORE 4D REFERENCES (MAGNES SENSORS): Only CTF ref matters
if ~isempty(iRef) && ~isempty(strfind(lower(OPTIONS.Channel(iRef(1)).Comment), 'magnes'))
    iRef = [];
	% Display warning
    disp([10 '******************************************************************************************' 10 ...
          '******************************************************************************************' 10 ...
          '*** WARNING: 4D reference sensors are not taken into account in the forward model.     ***' 10 ...
          '***    Due to a bug in the 4D calibration software, the position of the reference      ***' 10 ...
          '***    are commonly wrong, we cannot compute an accurate forward model for them.       ***' 10 ...
          '***    To bypass this limitation and apply the coefficient matrix (MegRefCoef) to the  ***' 10 ... 
          '***    forward model, you can comment out the line "iRef = [];", next to this warning  ***' 10 ...
          '***    in file bst_heamodeler (lines 182-198).                                         ***' 10 ...
          '******************************************************************************************' 10 ...
          '******************************************************************************************' 10]);
end
% Get number of coils for each sensor
nCoilsPerSensor = cellfun(@(c)size(c,2), {OPTIONS.Channel.Loc});
% Include sensors indices in the OPTIONS structure (for DUNEuro and OpenMEEG)
OPTIONS.iMeg  = [iMeg iRef];
OPTIONS.iEeg  = iEeg;
OPTIONS.iEcog = iEcog;
OPTIONS.iSeeg = iSeeg;
    

%% ===== OUTPUT FILENAME ===========================================================================
%  =================================================================================================
% Get all methods
allMethods = unique({OPTIONS.MEGMethod, OPTIONS.EEGMethod, OPTIONS.ECOGMethod, OPTIONS.SEEGMethod});
allMethods(cellfun(@isempty, allMethods)) = [];
% Build default comment
if isempty(OPTIONS.Comment)
    % Grid type comment
    switch (OPTIONS.HeadModelType)
        case 'surface',  strGridType = '(cortex)';
        case 'volume',   strGridType = '(volume)';
        case 'mixed',    strGridType = '(mixed)';
    end
    % Build default comment
    OPTIONS.Comment = '';
    for im = 1:length(allMethods)
        OPTIONS.Comment = [OPTIONS.Comment ' ', allMethods{im}];
    end
    OPTIONS.Comment = [OPTIONS.Comment, strGridType];
end
% If HeadModelFile is a folder
if isdir(OPTIONS.HeadModelFile)
    OutputDir = OPTIONS.HeadModelFile;
    % Build default HeadModelFile, WITHOUT .MAT EXTENSION
    strFile = 'headmodel';
    switch (OPTIONS.HeadModelType)
        case 'surface',  strFile = [strFile, '_surf'];
        case 'volume',   strFile = [strFile, '_vol'];
        case 'mixed',    strFile = [strFile, '_mix'];
    end
    % Add a tag for each method
    for im = 1:length(allMethods)
        strFile = [strFile '_', allMethods{im}];
    end
    % Make filename unique
    OPTIONS.HeadModelFile = bst_fullfile(OutputDir, [strFile, '.mat']);
    OPTIONS.HeadModelFile = file_unique(OPTIONS.HeadModelFile);
end


%% ===== DEFINE SOURCE SPACE =======================================================================
%  =================================================================================================
GridOptions = [];
OutSurfaceFile = OPTIONS.CortexFile;
% Source space type
switch (OPTIONS.HeadModelType)
    case 'volume'
        if isempty(OPTIONS.GridLoc)
            % Volume: Get a volume grid
            if (OPTIONS.Interactive)
                sGrid = gui_show_dialog('Volume source grid', @panel_sourcegrid, 0, [], OPTIONS.CortexFile);
                if isempty(sGrid)
                    OPTIONS = [];
                    return;
                end
                OPTIONS.GridLoc = sGrid.GridLoc;
                GridOptions = sGrid.GridOptions;
                % If using the full head volume: change the surface file that is used as a reference
                if strcmpi(GridOptions.Method, 'isohead')
                    OutSurfaceFile = OPTIONS.HeadFile;
                end
            else
                if strcmpi(OPTIONS.GridOptions.Method, 'isohead')
                    OPTIONS.GridLoc = panel_sourcegrid('GetGrid', OPTIONS.GridOptions, OPTIONS.HeadFile);
                    OutSurfaceFile = OPTIONS.HeadFile;
                else
                    OPTIONS.GridLoc = panel_sourcegrid('GetGrid', OPTIONS.GridOptions, OPTIONS.CortexFile);
                end
                GridOptions = OPTIONS.GridOptions;
            end
            if isempty(OPTIONS.GridLoc)
                OPTIONS = [];
                bst_progress('stop');
                return;
            end
            % For group grids: Check if the reference was a head surface
            if strcmpi(GridOptions.Method, 'group') && ~isempty(GridOptions.FileName)
                RefGrid = in_bst_headmodel(GridOptions.FileName, 0, 'SurfaceFile');
                if ~isempty(RefGrid) && strcmpi(file_gettype(RefGrid.SurfaceFile), 'scalp')
                    OutSurfaceFile = OPTIONS.HeadFile;
                end
            end
        end
    case 'surface'
        if isempty(OPTIONS.GridLoc)
            % Read cortex file
            sCortex = bst_memory('LoadSurface', OPTIONS.CortexFile);
            % Surface: Use the cortex surface
            OPTIONS.GridLoc    = sCortex.Vertices;
            OPTIONS.GridOrient = sCortex.VertNormals;
            % Fix possible errors in the vertex normals
            iBad = find(any(isnan(OPTIONS.GridOrient),2) | any(isinf(OPTIONS.GridOrient),2) | (sqrt(sum(OPTIONS.GridOrient.^2,2)) < eps));
            if ~isempty(iBad)
                OPTIONS.GridOrient(iBad,:) = repmat([1 0 0], length(iBad), 1);
            end
        end
        
    case 'mixed'
        % Read cortex file
        sCortex = in_tess_bst(OPTIONS.CortexFile);
        isCortexModif = 0;
        % Get "Source model" atlas
        AtlasName = 'Source model';
        iAtlas = find(strcmpi({sCortex.Atlas.Name}, AtlasName));
        if isempty(iAtlas) || isempty(sCortex.Atlas(iAtlas)) || isempty(sCortex.Atlas(iAtlas).Scouts)
            errMessage = ['Atlas not found or empty: "' AtlasName '"'];
            OPTIONS = [];
            return;
        end
        sAtlas = sCortex.Atlas(iAtlas);
        % Add DBA message if required
        if any(~cellfun(@(c)isempty(strfind(c,'D')), {sAtlas.Scouts.Region}))
            bst_progress('setimage', 'logo_dba.gif');
            bst_progress('setlink', 'http://www.cenir.org');
        end
        % Initialize grid of points
        GridLoc = [];
        GridOrient = [];
        iRemoveScouts = [];
        % Process all the scouts of the atlas 'Source model'
        for is = 1:length(sAtlas.Scouts)
            % Progress bar
            bst_progress('text', ['Computing mixed models...   [' sAtlas.Scouts(is).Label ']']);
            % Get the indices for the current scout
            iVert = sAtlas.Scouts(is).Vertices;
            % Switch
            switch (sAtlas.Scouts(is).Region(2))
                % Surface
                case 'S'
                    SrcLoc = sCortex.Vertices(iVert,:);
                    % Fixed/Loose orientation
                    if isequal(sAtlas.Scouts(is).Region(3),'C') || isequal(sAtlas.Scouts(is).Region(3),'L')
                        SrcOri = sCortex.VertNormals(iVert,:);
                    % Free orientation: Fill with zeros
                    else
                        SrcOri = 0 * SrcLoc;
                    end
                % Volume
                case 'V'  
                    SrcLoc = dba_anatmodel(iVert, sAtlas.Scouts(is), sCortex, 'vol');
                    SrcOri = 0 * SrcLoc;
                % DBA
                case 'D'  
                    [SrcLoc, SrcOri, sAtlas.Scouts(is), iVertModif] = dba_get_model( sAtlas.Scouts(is), sCortex );
                    % If modifications where done on the cortex atlases: we have to update them
                    if ~isempty(iVertModif)
                        sAtlas.Scouts(is).Vertices = iVertModif;
                        sCortex.Atlas(iAtlas).Scouts(is).Vertices = iVertModif;
                        isCortexModif = 1;
                    end
                % Exclude
                case 'X'
                    SrcLoc = [];
                    SrcOri = [];
                otherwise
                    errMessage = ['Invalid atlase region "' sAtlas.Scouts(is).Region '".'];
                    OPTIONS = [];
                    return;
            end
            % Reference the processed region
            if ~isempty(SrcLoc)
                % Set the indices of the regions in the Atlas
                sAtlas.Scouts(is).GridRows = size(GridLoc,1) + (1:size(SrcLoc,1));
                % Concatenate with GridLoc and GridOrient
                GridLoc    = [GridLoc;    SrcLoc];
                GridOrient = [GridOrient; SrcOri];
                % Display number of sources for the region
                disp(sprintf('BST> %14s: %4d vertices', sAtlas.Scouts(is).Label, length(SrcLoc)));
            else
                iRemoveScouts(end+1) = is;
            end
        end
        % Remove deleted scouts
        if ~isempty(iRemoveScouts)
            sAtlas.Scouts(iRemoveScouts) = [];
        end
        % Update modified cortex atlases
        if isCortexModif
            bst_memory('UnloadSurface', OPTIONS.CortexFile, 1);
            bst_save(file_fullpath(OPTIONS.CortexFile), sCortex, 'v7');
        end
        % Compute gain matrices
        bst_progress('text', 'DBA: Computing gain matrix ...');
        OPTIONS.GridLoc    = GridLoc;
        OPTIONS.GridOrient = GridOrient;
        OPTIONS.GridAtlas  = sAtlas;
end
% Number of grid points
nv = size(OPTIONS.GridLoc,1);


%% ===== CHECK SENSORS LOCATIONS ===================================================================
%  =================================================================================================
% Load innerskull surface
if ~isempty(OPTIONS.InnerSkullFile)
    sSurfInner = bst_memory('LoadSurface', OPTIONS.InnerSkullFile);
% Create innerskull surface based on the cortex surface
else
    sSurfInner = tess_envelope(OPTIONS.CortexFile, 'convhull', 1082, .003);
    if isempty(sSurfInner)
        OPTIONS = [];
        bst_progress('stop');
        return;
    end
end
% Check for any sensor located "inside" the inner skull (that shouldn't be there)
allLoc = [OPTIONS.Channel([iMeg iEeg]).Loc];
if ~isempty(allLoc)
    iVertInside = find(inpolyhd(allLoc, sSurfInner.Vertices, sSurfInner.Faces));
    % Warning if there are some sensors inside
    if ~isempty(iVertInside)
        errMessage = ['Some EEG or MEG sensors are located inside the brain volume.' 10 ...
                      'You should check the positions of the sensors and the type of the channels.' 10 10 ...
                      'Position: Right-click on the channel file > MRI registration > Edit.' 10 ...
                      'Type: Right-click on the channel file > Edit channel file.'];
        OPTIONS = [];
        bst_progress('stop');
        return;
    end
end
% Initialize empty gain matrix
Gain = NaN * zeros(length(OPTIONS.Channel), Dims * nv);
        
        
%% ===== COMPUTE: OPENMEEG =====
if ismember('openmeeg', {OPTIONS.MEGMethod, OPTIONS.EEGMethod, OPTIONS.ECOGMethod, OPTIONS.SEEGMethod})
    % If OpenMEEG options not defined: Let user edit them
    if ~isfield(OPTIONS, 'BemFiles') || isempty(OPTIONS.BemFiles)
        errMessage = 'OpenMEEG options are not defined.';
        OPTIONS = [];
        return;
    end
    % Number of blocks
    nv = length(OPTIONS.GridLoc);
    if OPTIONS.isSplit && (OPTIONS.SplitLength < nv)
        BlockSize = OPTIONS.SplitLength;
        nBlocks = ceil(nv / BlockSize);
    else
        nBlocks = 1;
    end
    
    % Start progress bar
    bst_progress('start', 'Head modeler', 'Starting OpenMEEG...');
    % Split in blocks
    if (nBlocks > 1)      
        % Backup copy of the GridLoc field
        bakGridLoc = OPTIONS.GridLoc;
        % Call OpenMEEG: Process by blocks
        for iBlock = 1:nBlocks
            % Indices of the vertices to process
            iVert = 1 + (((iBlock-1)*BlockSize) : min(iBlock * BlockSize - 1, nv - 1));
            % Select only the current block of vertices and process it with OpenMEEG
            OPTIONS.GridLoc = bakGridLoc(iVert,:);
            % Call OpenMEEG
            [tmpGain, errMessage] = bst_openmeeg(OPTIONS);
            if isempty(tmpGain)
                break;
            end
            % Copy the leadfield of the processed vertices in the final leadfield matrix
            iCol = sort([3*iVert-2, 3*iVert-1, 3*iVert]);
            Gain_om(:,iCol) = tmpGain;
        end
        % Restore GridLoc
        OPTIONS.GridLoc = bakGridLoc;
    % Do not split
    else
        [Gain_om, errMessage] = bst_openmeeg(OPTIONS);
        if isempty(Gain_om)
            OPTIONS = [];
            bst_progress('stop');
            return;
        end
    end
    % Check if the process crashed
    if isempty(Gain_om) || all(isnan(Gain_om(:)))
        OPTIONS = [];
        if isempty(errMessage)
            errMessage = 'OpenMEEG could not run properly.';
        end
        bst_progress('stop');
        return;
    end
    % Add values to previous Gain matrix
    Gain(~isnan(Gain_om)) = Gain_om(~isnan(Gain_om));
    % Comment in history field
    for iLayer = 1:length(OPTIONS.BemNames)
        vertInfo = whos('-file', OPTIONS.BemFiles{iLayer}, 'Vertices');
        strHistory = [strHistory, ' | ', sprintf('%s %1.4f %dV', OPTIONS.BemNames{iLayer}, OPTIONS.BemCond(iLayer), vertInfo.size(1)) ];
    end
end


%% ===== COMPUTE: DUNEURO =====
if ismember('duneuro', {OPTIONS.MEGMethod, OPTIONS.EEGMethod, OPTIONS.ECOGMethod, OPTIONS.SEEGMethod})
    % Start progress bar
    bst_progress('start', 'Head modeler', 'Starting Duneuro...');
    bst_progress('setimage', 'plugins/duneuro_logo.png');
    % Run duneuro FEM computation
    [Gain_dn, errMessage] = bst_duneuro(OPTIONS);
    % Comment in history field
    strHistory = [strHistory, ' | ', sprintf('Fem head file: %s, |  Cortex file: %s, ', OPTIONS.FemFile, OPTIONS.CortexFile) ];
    if ~OPTIONS.UseTensor
        strHistory = [strHistory, ' | ', sprintf('FemCond: isotropic, %s', num2str(OPTIONS.FemCond))];
    else
        strHistory = [strHistory, ' | ', sprintf('FemCond: anisotropic, %s', 'check the tensor field within the Fem head file')];
    end
    strHistory = [strHistory, ' | ', sprintf('Fem source model: %s, type : %s, %s ', OPTIONS.SrcModel, OPTIONS.FemType, OPTIONS.SolverType) ];
    % Remove logo from progress bar
    bst_progress('removeimage');
    % If process crashed
    if isempty(Gain_dn)
        OPTIONS = [];
        if isempty(errMessage)
            errMessage = 'DUNEuro could not run properly.';
        end
        bst_progress('stop');
        return;
    end
    % Add values to previous Gain matrix
    Gain(~isnan(Gain_dn)) = Gain_dn(~isnan(Gain_dn));
end


%% ===== COMPUTE: BRAINSTORM HEADMODELS =====
if (~isempty(OPTIONS.MEGMethod) && ~ismember(OPTIONS.MEGMethod, {'openmeeg', 'duneuro'})) || ...
   (~isempty(OPTIONS.EEGMethod) && ~ismember(OPTIONS.EEGMethod, {'openmeeg', 'duneuro'}))

    % ===== DEFINE SPHERES FOR EACH SENSOR =====
    Param(1:length(OPTIONS.Channel)) = deal(struct(...
            'Center', [], ...
            'Radii',  []));
    iAllMeg = [iRef, iMeg];
    % Overlapping spheres
    if strcmpi(OPTIONS.MEGMethod, 'os_meg')
        % Start progress bar
        bst_progress('start', 'Head modeler', 'Estimating overlapping spheres...');
        % Compute all spheres parameters, using the InnerSkull surface
        if ~isfield(OPTIONS, 'Sphere') || isempty(OPTIONS.Sphere)
            OPTIONS.Sphere = bst_os(OPTIONS.Channel(iMeg), double(sSurfInner.Vertices), double(sSurfInner.Faces));
        end
        % Fill the Param structure
        [Param(iMeg).Center] = deal(OPTIONS.Sphere.Center);
        [Param(iMeg).Radii]  = deal(OPTIONS.Sphere.Radius);
        % MEG REF: same center for all reference channels
        if ~isempty(iRef)
            [Param(iRef).Center] = deal(mean([Param(iMeg).Center],2));
            [Param(iRef).Radii]  = deal(mean([Param(iMeg).Radii],2));
        end
    % Other types
    else
        [Param.Center] = deal(OPTIONS.HeadCenter);
        [Param.Radii]  = deal(OPTIONS.Radii);
    end

    % ===== COMPUTE GAIN MATRIX ======
    % Start progress bar
    BlockSize = 2000;
    bst_progress('start', 'Head modeler', 'Computing gain matrix...', 0, ceil(nv/BlockSize));
    % Loop on all blocks 
    for iBlock = 1:BlockSize:nv
        bst_progress('inc', 1);
        iSrc = (0:BlockSize-1) + iBlock;
        % If last block too long, remove unnecessary indices
        if (iSrc(end) > nv)
            iSrc = iSrc(1):nv;
        end
        % Convert into indices in the final gain matrix (size: [nchannels, 3*nsources])
        iSrcGain = (3 * (iSrc(1)-1) + 1) : 3*iSrc(end);
        % ===== MEG =====
        if ismember(OPTIONS.MEGMethod, {'meg_sphere', 'os_meg'})
            % Function os_meg can only accept calls to groups of sensors with the same number of coils
            % => Group the sensors by number of coils and call os_meg as many times as needed
            grpCoils = unique(nCoilsPerSensor(iAllMeg));
            % Loop on each group of sensors
            for iGrp = 1:length(grpCoils)
                % Get all the sensors with this amount of coils
                nCoils = grpCoils(iGrp);
                iMegGrp = iAllMeg(nCoilsPerSensor(iAllMeg) == nCoils);
                % Compute (os_meg)
                Gain(iMegGrp,iSrcGain) = bst_meg_sph(OPTIONS.GridLoc(iSrc,:)', OPTIONS.Channel(iMegGrp), Param(iMegGrp));
            end
        end
        % ===== EEG =====
        if strcmpi(OPTIONS.EEGMethod, 'eeg_3sphereberg')
            EegLoc = [OPTIONS.Channel(iEeg).Loc]';
            Gain(iEeg,iSrcGain) = bst_eeg_sph(OPTIONS.GridLoc(iSrc,:), EegLoc, OPTIONS.HeadCenter, OPTIONS.Radii, OPTIONS.Conductivity);
            strHistory = sprintf(', Cond: %1.3f %1.3f %1.3f, Radii: %1.3f %1.3f %1.3f', OPTIONS.Conductivity, OPTIONS.Radii);
        end
    end
else
    Param = [];
end    
% Check for errors: NaN values in the Gain matrix
if (nnz(isnan(Gain(iEeg,:))) > 0)  && ~isempty(OPTIONS.EEGMethod)  || ...
   (nnz(isnan(Gain(iMeg,:))) > 0)  && ~isempty(OPTIONS.MEGMethod)  || ...
   (nnz(isnan(Gain(iEcog,:))) > 0) && ~isempty(OPTIONS.ECOGMethod) || ...
   (nnz(isnan(Gain(iSeeg,:))) > 0) && ~isempty(OPTIONS.SEEGMethod)
    errMessage = ['An unknown error occurred in the computation of the head model:' 10 ...
                  'NaN values found for valid sensors in the Gain matrix'];
    OPTIONS = [];
    return;
end


%% ===== POST-PROCESSING =====
% ALL MOVED TO PROCESS_INVERSE
% % ===== EEG AVERAGE REFERENCE =====
% if ~isempty(iEeg)
%     Gain(iEeg,:) = bst_bsxfun(@minus, Gain(iEeg,:), mean(Gain(iEeg,:)));
% end
% ===== APPLY CTF COMPENSATORS =====
if ~isempty(OPTIONS.MegRefCoef) && ~isempty(iRef)
    Gain(iMeg,:) = Gain(iMeg,:) - OPTIONS.MegRefCoef * Gain(iRef,:);
end
% % ===== APPLY SSP =====
% if ~isempty(OPTIONS.Projector)
%     % Rebuild projector in the expanded form (I-UUt)
%     Projector = process_ssp2('BuildProjector', OPTIONS.Projector, [1 2]);
%     % Apply projectors
%     if ~isempty(Projector)
%         % Get all sensors for which the gain matrix was successfully comupted
%         iGainSensors = find(sum(isnan(Gain), 2) == 0);
%         % Apply projectors to gain matrix
%         Gain(iGainSensors,:) = Projector(iGainSensors,iGainSensors) * Gain(iGainSensors,:);
%     end
% end
   

%% ===== SAVE HEAD MODEL =====
% Progress bar
bst_progress('start', 'Head modeler', 'Saving headmodel file...');
% Build structure to save
SaveHeadModel = struct(...
    'MEGMethod',     OPTIONS.MEGMethod, ...
    'EEGMethod',     OPTIONS.EEGMethod, ...
    'ECOGMethod',    OPTIONS.ECOGMethod, ...
    'SEEGMethod',    OPTIONS.SEEGMethod, ...
    'Gain',          Gain, ...                   % FT 11-Jan-10: Remove "single"
    'Comment',       OPTIONS.Comment, ...
    'HeadModelType', OPTIONS.HeadModelType, ...
    'GridLoc',       OPTIONS.GridLoc, ...
    'GridOrient',    OPTIONS.GridOrient, ...
    'GridAtlas',     OPTIONS.GridAtlas, ...
    'GridOptions',   GridOptions, ...
    'SurfaceFile',   file_win2unix(OutSurfaceFile), ...
    'Param',         Param);
% History: compute head model
SaveHeadModel = bst_history('add', SaveHeadModel, 'compute', ['Compute head model: ' OPTIONS.Comment strHistory]);
% Save file
if ~isempty(OPTIONS.HeadModelFile)
    bst_save(OPTIONS.HeadModelFile, SaveHeadModel, 'v7');
else
    OPTIONS.HeadModelMat = SaveHeadModel;
end
bst_progress('stop');
bst_progress('removeimage');



