function [Wmat, sSrcSubj, sDestSubj, srcSurfMat, destSurfMat, isStopWarped] = tess_interp_tess2tess( srcSurfFile, destSurfFile, isInteractive, isStopWarped, isSingleHemi )
% TESS_INTERP_TESS2TESS: Compute an interpolation matrix between two cortex surfaces.

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
% Authors: Francois Tadel, 2010-2019
%          Anand Joshi, 2015

% Parse inputs
if (nargin < 5) || isempty(isSingleHemi)
    isSingleHemi = 0;
end
if (nargin < 4) || isempty(isStopWarped)
    isStopWarped = [];
end
if (nargin < 3) || isempty(isInteractive)
    isInteractive = 1;
end

% ===== GET SURFACES =====
% Load surface files
srcSurfMat  = in_tess_bst(srcSurfFile);
destSurfMat = in_tess_bst(destSurfFile);
% Get source and destination subjects
sSrcSubj  = bst_get('SurfaceFile', srcSurfFile);
sDestSubj = bst_get('SurfaceFile', destSurfFile);
% Number of vertices
nSrc  = size(srcSurfMat.Vertices, 1);
nDest = size(destSurfMat.Vertices, 1);
% Source subject and destination subject are the same
isSameSubject = file_compare(sSrcSubj.FileName, sDestSubj.FileName);
% Check if source or destination are the default anatomy
isSrcDefaultSubj  = ismember(bst_fileparts(sSrcSubj.FileName),  {bst_get('DirDefaultSubject'), bst_get('NormalizedSubjectName')});
isDestDefaultSubj = ismember(bst_fileparts(sDestSubj.FileName), {bst_get('DirDefaultSubject'), bst_get('NormalizedSubjectName')});
% Signature string for the current transformation
Signature = sprintf('%s%d=>%s%d', srcSurfFile, length(srcSurfMat.Vertices), destSurfFile, length(destSurfMat.Vertices));
% Number of neighbors to use for each vertex
%nbNeighbors = 8 * ceil(length(destSurfMat.Vertices) / length(srcSurfMat.Vertices));
nbNeighbors = 8;
sMriSrc = [];
sMriDest = [];
hFig1 = [];
hFig2 = [];

% ===== RE-USE PREVIOUS INTERPOLATION =====
% Try to get an existing valid interpolation matrix, then return
if isfield(srcSurfMat, 'tess2tess_interp') && all(isfield(srcSurfMat.tess2tess_interp, {'Signature', 'Wmat'})) && ...
        strcmpi(srcSurfMat.tess2tess_interp.Signature, Signature) && ~isempty(srcSurfMat.tess2tess_interp.Wmat)
    Wmat = srcSurfMat.tess2tess_interp.Wmat;
    return;
end
% Allocate a new empty interpolation matrix
Wmat = spalloc(nDest, nSrc, nbNeighbors * nDest);

% ===== CHECK IF WARPED =====
% If projecting a warped subject back on the original brain: NOT necessary
if isempty(Wmat) && ~isempty(strfind(srcSurfFile, '_warped')) && ~isSrcDefaultSubj && isDestDefaultSubj && (nSrc == nDest)
    % Warning message
    warnMsg = ['The source files were computed on a warped anatomy, there is' 10 ...
               'no need to re-project them on the default anatomy, you can directly' 10 ...
               'calculate average or differences across subjects.'];
    % Ask user to cancel the process
    if isempty(isStopWarped)
        if isInteractive
            isStopWarped = ~java_dialog('confirm', [warnMsg 10 10 'Project sources anyways?'], 'Project sources');
            if isStopWarped
                bst_progress('stop');
                Wmat = [];
                return;
            end
        elseif ~isInteractive
            isStopWarped = 0;
            bst_report('Warning', 'process_project_sources', [], warnMsg);
        end
    end
    % Interpolation matrix: Use an identity matrix
    Wmat = speye(nDest,nSrc);
    % Do not save this interpolation matrix, it's really not necessary
    return;
end

% ===== STRUCTURES ATLAS =====
% Split left-right
if ~isSingleHemi
    % Find structure atlases
    iStructSrc  = find(strcmpi({srcSurfMat.Atlas.Name}, 'Structures'));
    iStructDest = find(strcmpi({destSurfMat.Atlas.Name}, 'Structures'));
    % Do not accept surfaces from different generations...
    if (isempty(iStructSrc) && ~isempty(iStructDest)) || (~isempty(iStructSrc) && isempty(iStructDest))
        error('One surface has an atlas "Structures", the other does not. You need to use surfaces coming from the same software to project sources.');
    end
    % Atlases not found: Try to separate the left and right hemispheres
    if isempty(iStructSrc) && isempty(iStructDest)
        % Split hemispheres
        [rHsrc, lHsrc, isConnected(1)]  = tess_hemisplit(srcSurfMat);
        [rHdest,lHdest, isConnected(2)] = tess_hemisplit(destSurfMat);
        % If the two hemispheres are connected: Not supported anymore
        if any(isConnected)
            error('Surfaces with connected hemispheres are not supported anymore. Please use FreeSurfer, BrainSuite or BrainVISA.');
        end
        % Create scout: Source left
        sScoutLeftSrc = db_template('scout');
        sScoutLeftSrc.Label    = 'Cortex L';
        sScoutLeftSrc.Vertices = lHsrc;
        sScoutLeftSrc.Seed     = lHsrc(1);
        sScoutLeftSrc.Region   = 'LU';
        sScoutLeftSrc.Color    = [0.7451 0.7451 0.7451];
        % Create scout: Destination left
        sScoutLeftDest = sScoutLeftSrc;
        sScoutLeftDest.Vertices = lHdest;
        sScoutLeftDest.Seed     = lHdest(1);
        % Create scout: Source right
        sScoutRightSrc = sScoutLeftSrc;
        sScoutRightSrc.Label    = 'Cortex R';
        sScoutRightSrc.Region   = 'RU';
        sScoutRightSrc.Vertices = rHsrc;
        sScoutRightSrc.Seed     = rHsrc(1);
        % Create scout: Destination right
        sScoutRightDest = sScoutRightSrc;
        sScoutRightDest.Vertices = rHdest;
        sScoutRightDest.Seed     = rHdest(1);
        % Create new atlases
        iStructSrc  = length(srcSurfMat.Atlas) + 1;
        iStructDest = length(destSurfMat.Atlas) + 1;
        srcSurfMat.Atlas(iStructSrc).Name   = 'Structures';
        destSurfMat.Atlas(iStructDest).Name = 'Structures';
        % Add scouts for the two hemispheres
        srcSurfMat.Atlas(iStructSrc).Scouts   = [sScoutLeftSrc, sScoutRightSrc];
        destSurfMat.Atlas(iStructDest).Scouts = [sScoutLeftDest, sScoutRightDest];
    end
    % Get the indices of the "Cortex L" and "Cortex R" structures
    iCortexLsrc  = find(strcmpi('Cortex L', {srcSurfMat.Atlas(iStructSrc).Scouts.Label}));
    iCortexRsrc  = find(strcmpi('Cortex R', {srcSurfMat.Atlas(iStructSrc).Scouts.Label}));
    iCortexLdest = find(strcmpi('Cortex L', {destSurfMat.Atlas(iStructDest).Scouts.Label}));
    iCortexRdest = find(strcmpi('Cortex R', {destSurfMat.Atlas(iStructDest).Scouts.Label}));
    % Get the cortex scouts
    if ~isempty(iCortexLsrc) && ~isempty(iCortexRsrc) && ~isempty(iCortexLdest) && ~isempty(iCortexRdest)
        iVertLsrc  = srcSurfMat.Atlas(iStructSrc).Scouts(iCortexLsrc).Vertices;
        iVertRsrc  = srcSurfMat.Atlas(iStructSrc).Scouts(iCortexRsrc).Vertices;
        iVertLdest = destSurfMat.Atlas(iStructDest).Scouts(iCortexLdest).Vertices;
        iVertRdest = destSurfMat.Atlas(iStructDest).Scouts(iCortexRdest).Vertices;
        nCortexSrc  = length(iVertLsrc) + length(iVertRsrc);
        nCortexDest = length(iVertLdest) + length(iVertRdest);
    else
        nCortexSrc = -1;
        nCortexDest = -1;
    end
    % Return scouts
    sScoutStructSrc = srcSurfMat.Atlas(iStructSrc).Scouts;
    sScoutStructDest = destSurfMat.Atlas(iStructDest).Scouts;
else
    % Only one hemisphere
    nCortexSrc = length(srcSurfMat.Vertices);
    nCortexDest = length(destSurfMat.Vertices);
    iVertLsrc = 1:nCortexSrc;
    iVertRsrc = [];
    iVertLdest = 1:nCortexDest;
    iVertRdest = [];
    % Create a structure atlas that contains all the vertices in one region
    sScoutStructSrc = db_template('scout');
    sScoutStructSrc.Label = 'Cortex L';
    sScoutStructSrc.Vertices = iVertLsrc;
    sScoutStructDest = db_template('scout');
    sScoutStructDest.Label = 'Cortex L';
    sScoutStructDest.Vertices = iVertLdest;
end

% ===== GET FREESURFER SPHERES =====
% If the registered spheres are available in both surfaces (and have the same number of vertices as the cortex L+R)
if isfield(srcSurfMat, 'Reg')  && isfield(srcSurfMat.Reg, 'Sphere')  && isfield(srcSurfMat.Reg.Sphere, 'Vertices')  && ~isempty(srcSurfMat.Reg.Sphere.Vertices) && ...
   isfield(destSurfMat, 'Reg') && isfield(destSurfMat.Reg, 'Sphere') && isfield(destSurfMat.Reg.Sphere, 'Vertices') && ~isempty(destSurfMat.Reg.Sphere.Vertices) && ...
   (length(srcSurfMat.Reg.Sphere.Vertices) == nCortexSrc) && (length(destSurfMat.Reg.Sphere.Vertices) == nCortexDest)
    % Basic version: doesn't work because the the Reg.Sphere contains only the vertices of the cortex hemispheres, not all the surface, therefore the indices do not match
    % But rehabilitated in Sept 2018 to handle some old databases from 2015, where the order of the vertices is not preserved in the downsampling
    % Old surfaces can be identified with Cortex scouts with vertex indices that are not sorted
    if ~isSingleHemi && (length(destSurfMat.Atlas(iStructDest).Scouts) == 2) && ((~isequal(1:length(iVertLsrc), iVertLsrc) && ~isequal(1:length(iVertRsrc), iVertRsrc)) || (~isequal(1:length(iVertLdest), iVertLdest) && ~isequal(1:length(iVertRdest), iVertRdest)))
        % This old version of the code works only if there are only the two hemispheres in the cortex surface
        if (length(srcSurfMat.Reg.Sphere.Vertices) == length(srcSurfMat.Vertices)) && (length(destSurfMat.Reg.Sphere.Vertices) == length(destSurfMat.Vertices))
            vertSphLsrc = srcSurfMat.Reg.Sphere.Vertices(iVertLsrc, :);
            vertSphRsrc = srcSurfMat.Reg.Sphere.Vertices(iVertRsrc, :);
            vertSphLdest = destSurfMat.Reg.Sphere.Vertices(iVertLdest, :);
            vertSphRdest = destSurfMat.Reg.Sphere.Vertices(iVertRdest, :);
            warning('Using an old database with outdated structures: Consider updating the anatomical templates and downsampling the surfaces again.');
        else
            error('Database error: The surface you use for the interpolation must be downsampled again.');
        end
    % Correct code for new databases
    else
        % Source surface: Get the vertices of the left/right spheres
        if isSingleHemi
            vertSphLsrc = srcSurfMat.Reg.Sphere.Vertices;
        elseif (iVertLsrc(1) < iVertRsrc(1))
            vertSphLsrc = srcSurfMat.Reg.Sphere.Vertices(1:length(iVertLsrc), :);
            vertSphRsrc = srcSurfMat.Reg.Sphere.Vertices(length(iVertLsrc)+1:end, :);
        else
            vertSphRsrc = srcSurfMat.Reg.Sphere.Vertices(1:length(iVertRsrc), :);
            vertSphLsrc = srcSurfMat.Reg.Sphere.Vertices(length(iVertRsrc)+1:end, :);
        end
        % Destination surface: Get the vertices of the left/right spheres
        if isSingleHemi
            vertSphLdest = destSurfMat.Reg.Sphere.Vertices;
        elseif (iVertLdest(1) < iVertRdest(1))
            vertSphLdest = destSurfMat.Reg.Sphere.Vertices(1:length(iVertLdest), :);
            vertSphRdest = destSurfMat.Reg.Sphere.Vertices(length(iVertLdest)+1:end, :);
        else
            vertSphRdest = destSurfMat.Reg.Sphere.Vertices(1:length(iVertRdest), :);
            vertSphLdest = destSurfMat.Reg.Sphere.Vertices(length(iVertRdest)+1:end, :);
        end
    end
    isFreeSurfer = 1;
else
    isFreeSurfer = 0;
end
% Plot surfaces
% figure; 
% plot3(vertSphLsrc(:,1), vertSphLsrc(:,2), vertSphLsrc(:,3), 'Marker', '+', 'LineStyle', 'none', 'Color', [0 1 0]); hold on;
% plot3(vertSphLdest(:,1), vertSphLdest(:,2), vertSphLdest(:,3), 'Marker', '+', 'LineStyle', 'none', 'Color', [1 0 0]); axis equal; rotate3d
% plot3(vertSphRsrc(:,1), vertSphRsrc(:,2), vertSphRsrc(:,3), 'Marker', '+', 'LineStyle', 'none', 'Color', [1 0 0]); axis equal; rotate3d
% figure;
% plot3(vertSphLdest(:,1), vertSphLdest(:,2), vertSphLdest(:,3), 'Marker', '+', 'LineStyle', 'none', 'Color', [0 1 0]); hold on;
% plot3(vertSphRdest(:,1), vertSphRdest(:,2), vertSphRdest(:,3), 'Marker', '+', 'LineStyle', 'none', 'Color', [1 0 0]); axis equal; rotate3d


% ===== GET BRAINSUITE SQUARES =====
% If the registered spheres are available in both surfaces (and have the same number of vertices as the cortex L+R)
if isfield(srcSurfMat, 'Reg')  && isfield(srcSurfMat.Reg, 'Square')  && isfield(srcSurfMat.Reg.Square, 'Vertices')  && ~isempty(srcSurfMat.Reg.Square.Vertices) && ...
   isfield(destSurfMat, 'Reg') && isfield(destSurfMat.Reg, 'Square') && isfield(destSurfMat.Reg.Square, 'Vertices') && ~isempty(destSurfMat.Reg.Square.Vertices) && ...
   (length(srcSurfMat.Reg.Square.Vertices) == nCortexSrc) && (length(destSurfMat.Reg.Square.Vertices) == nCortexDest)
    % Source surface: Get the vertices of the left/right spheres
    if isSingleHemi
        vertSquareLsrc = srcSurfMat.Reg.Square.Vertices;
    elseif (iVertLsrc(1) < iVertRsrc(1))
        vertSquareLsrc = srcSurfMat.Reg.Square.Vertices(1:length(iVertLsrc), :);
        vertSquareRsrc = srcSurfMat.Reg.Square.Vertices(length(iVertLsrc)+1:end, :);
    else
        vertSquareRsrc = srcSurfMat.Reg.Square.Vertices(1:length(iVertRsrc), :);
        vertSquareLsrc = srcSurfMat.Reg.Square.Vertices(length(iVertRsrc)+1:end, :);
    end
    % Destination surface: Get the vertices of the left/right spheres
    if isSingleHemi
        vertSquareLdest = destSurfMat.Reg.Square.Vertices;
    elseif (iVertLdest(1) < iVertRdest(1))
        vertSquareLdest = destSurfMat.Reg.Square.Vertices(1:length(iVertLdest), :);
        vertSquareRdest = destSurfMat.Reg.Square.Vertices(length(iVertLdest)+1:end, :);
    else
        vertSquareRdest = destSurfMat.Reg.Square.Vertices(1:length(iVertRdest), :);
        vertSquareLdest = destSurfMat.Reg.Square.Vertices(length(iVertRdest)+1:end, :);
    end
    % Split hemispheres for the reference atlas
    iAtlasR = find(srcSurfMat.Reg.AtlasSquare.Vertices(:,1) >= 0);
    iAtlasL = find(srcSurfMat.Reg.AtlasSquare.Vertices(:,1) < 0);
    % Get BrainSuite reference atlases
    vertAtlasLsrc  = double(srcSurfMat.Reg.AtlasSquare.Vertices(iAtlasL,:));
    vertAtlasRsrc  = double(srcSurfMat.Reg.AtlasSquare.Vertices(iAtlasR,:));
    vertAtlasLdest = double(destSurfMat.Reg.AtlasSquare.Vertices(iAtlasL,:));
    vertAtlasRdest = double(destSurfMat.Reg.AtlasSquare.Vertices(iAtlasR,:));
    isBrainSuite = 1;
else
    isBrainSuite = 0;
end

% ===== WARNING IF NO ACCURATE METHOD AVAILABLE =====
% Warning for cortex interpolation
if ~isBrainSuite && ~isFreeSurfer
    strWarning = ['This projection method you are about is outdated and inaccurate.' 10 10 ...
                  'For accurate results, please consider using FreeSurfer or BrainSuite' 10 ...
                  'for the MRI segmentation, because they generate registered atlases' 10 ...
                  'we can use in Brainstorm for the the inter-subject co-registration.' 10 10 ...
                  'More information on the Brainstorm website: ' 10 ...
                  'https://neuroimage.usc.edu/brainstorm/Tutorials/CoregisterSubjects' 10];
    if isInteractive
        % Close all figures
        bst_memory('UnloadAll', 'Forced');
        % Warning: bad technique
        java_dialog('warning', strWarning);
    else
        disp(['PROJECT> Warning: ' strWarning]);
        bst_report('Warning', 'process_project_sources', [], strWarning);
    end
end
isFirstMniWarning = 1;

% ===== PROJECT: REGION BY REGION =====
for i = 1:length(sScoutStructSrc)
    % Get region in source surface
    sScoutSrc = sScoutStructSrc(i);
    % Progress bar
    if isInteractive
        bst_progress('start', 'Project sources', ['Computing interpolation: "' sScoutSrc.Label '"...']);
    end
    % Get region in destination surface
    iScoutDest = find(strcmpi(sScoutSrc.Label, {sScoutStructDest.Label}));
    if isempty(iScoutDest)
        disp(['PROJECT> Warning: Structure not found in destination surface: ' sScoutSrc.Label ]);
        continue;
    end
    sScoutDest = sScoutStructDest(iScoutDest);
    % Is it a cortex region
    isCortexL = ismember(sScoutSrc.Label, {'lh', '01_Lhemi L', 'Cortex L'});
    isCortexR = ismember(sScoutSrc.Label, {'rh', '01_Rhemi R', 'Cortex R'});
    
    % ===== USE FREESURFER SPHERES =====
    % Interpolate using the sphere and the Shepard's algorithm
    if isCortexL && isFreeSurfer
        Wmat(sScoutDest.Vertices, sScoutSrc.Vertices) = bst_shepards(vertSphLdest, vertSphLsrc, nbNeighbors, 0);
    elseif isCortexR && isFreeSurfer
        Wmat(sScoutDest.Vertices, sScoutSrc.Vertices) = bst_shepards(vertSphRdest, vertSphRsrc, nbNeighbors, 0);
        
    % ===== USE BRAINSUITE SQUARES =====
    % Interpolate using the Brainsuite squares and the Shepard's algorithm
    elseif isCortexL && isBrainSuite
        % Interpolation: Subject => BrainSuiteAtlas1
        Wsrc2atlas = bst_shepards(vertAtlasLsrc, vertSquareLsrc, nbNeighbors, 0);
        % Interpolation: BrainSuiteAtlas1 => Default anatomy
        Watlas2dest = bst_shepards(vertSquareLdest, vertAtlasLdest, nbNeighbors, 0);
        % Combined: Subject => Default anatomy
        Wmat(sScoutDest.Vertices, sScoutSrc.Vertices) = Watlas2dest * Wsrc2atlas;
    elseif isCortexR && isBrainSuite
        % Interpolation: Subject => BrainSuiteAtlas1
        Wsrc2atlas = bst_shepards(vertAtlasRsrc, vertSquareRsrc, nbNeighbors, 0);
        % Interpolation: BrainSuiteAtlas1 => Default anatomy
        Watlas2dest = bst_shepards(vertSquareRdest, vertAtlasRdest, nbNeighbors, 0);
        % Combined: Subject => Default anatomy
        Wmat(sScoutDest.Vertices, sScoutSrc.Vertices) = Watlas2dest * Wsrc2atlas;

    % ===== DEFAULT METHOD: ICP ALIGNMENT =====
    % Align surfaces using an ICP algorithm, then interpolate with the Shepard's algorithm
    else
        % === ALIGN SURFACES ===
        if ~isSameSubject
            % === CONVERT TO MNI COORDINATES ===
            % Load MRI files
            if isempty(sMriSrc) || isempty(sMriDest)
                sMriSrc  = in_mri_bst(sSrcSubj.Anatomy(sSrcSubj.iAnatomy).FileName);
                sMriDest = in_mri_bst(sDestSubj.Anatomy(sDestSubj.iAnatomy).FileName);
            end
            % Convert to MNI coordinates
            vertSrc  = cs_convert(sMriSrc,  'scs', 'mni', srcSurfMat.Vertices(sScoutSrc.Vertices, :));
            vertDest = cs_convert(sMriDest, 'scs', 'mni', destSurfMat.Vertices(sScoutDest.Vertices, :));
            if (isempty(vertSrc) || isempty(vertDest))
                if isFirstMniWarning
                    strWarning = 'For accurate results, compute the MNI transformation for both subjects before running this interpolation.';
                    if isInteractive
                        java_dialog('warning', strWarning);
                    else
                        disp(['PROJECT> Warning: ' strWarning]);
                        bst_report('Warning', 'process_project_sources', [], strWarning);
                    end
                    isFirstMniWarning = 0;
                end
                vertSrc  = srcSurfMat.Vertices(sScoutSrc.Vertices, :);
                vertDest = destSurfMat.Vertices(sScoutDest.Vertices, :);
            end

            % === SMOOTH AND ALIGN SURFACES ===
            nSmoothSrc  = round(.05 * length(vertSrc));
            nSmoothDest = round(.05 * length(vertDest));
            % Smooth surfaces
            vertSrc  = tess_smooth(vertSrc,  0.2, nSmoothSrc,  srcSurfMat.VertConn(sScoutSrc.Vertices,sScoutSrc.Vertices), 1);
            vertDest = tess_smooth(vertDest, 0.2, nSmoothDest, destSurfMat.VertConn(sScoutDest.Vertices,sScoutDest.Vertices), 1);
            % Get surface faces
            [tmp, facesSrc]  = tess_remove_vert(srcSurfMat.Vertices, srcSurfMat.Faces, setdiff(1:length(srcSurfMat.Vertices), sScoutSrc.Vertices));
            [tmp, facesDest] = tess_remove_vert(destSurfMat.Vertices, destSurfMat.Faces, setdiff(1:length(destSurfMat.Vertices), sScoutDest.Vertices));
            % Mesh fit
            [R,T,vertSrcIcp] = bst_meshfit(vertDest, facesDest, vertSrc);
        else
            vertSrcIcp = srcSurfMat.Vertices(sScoutSrc.Vertices, :);
            vertDest   = destSurfMat.Vertices(sScoutDest.Vertices, :);
        end
        
        % === COMPUTE INTERPOLATION ===
%         % ICP: Options structure
%         Options.Verbose=true;
%         Options.Registration='Affine';   % Other methods: Rigid, Size
%         Options.Optimizer = 'fminlbfgs'; % other optimizers : 'fminsearch','lsqnonmin'
%         % Run ICP transformation
%         [vertSrcIcp, transfICP] = ICP_finite(vertDest, vertSrc, Options);
        % Compute Shepard's interpolation
        Wmat(sScoutDest.Vertices, sScoutSrc.Vertices) = bst_shepards(vertDest, vertSrcIcp, nbNeighbors, 0);
       
        % === DISPLAY ALIGNMENT ===
        if isInteractive && ~isSameSubject
            % Close previous figures
            if ~isempty(hFig1) && ishandle(hFig1)
                close(hFig1);
            end
            if ~isempty(hFig2) && ishandle(hFig2)
                close(hFig2);
            end
            % Before
            [hFig1, iDS, iFig, hPatch] = view_surface_matrix(vertDest, facesDest, .4, [1 0 0]);
            set(hPatch, 'EdgeColor', 'r');
            [hFig1, iDS, iFig, hPatch] = view_surface_matrix(vertSrc, facesSrc, .4, [], hFig1);
            set(hPatch, 'EdgeColor', [.6 .6 .6]);
            set(hFig1, 'Name', [sScoutSrc.Label ' (before)']);
            % After
            [hFig2, iDS, iFig, hPatch] = view_surface_matrix(vertDest, facesDest, .4, [1 0 0]);
            set(hPatch, 'EdgeColor', 'r');
            [hFig2, iDS, iFig, hPatch] = view_surface_matrix(vertSrcIcp, facesSrc, .4, [], hFig2);
            set(hPatch, 'EdgeColor', [.6 .6 .6]);
            set(hFig2, 'Name', [sScoutSrc.Label ' (after)']);
            drawnow;
        end
    end
end


% ===== SAVE INTERPOLATION =====
% Save interpolation in surface file, for future use
s.tess2tess_interp.Wmat      = Wmat;
s.tess2tess_interp.Signature = Signature;
bst_save(file_fullpath(srcSurfFile), s, 'v7', 1);

