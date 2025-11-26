function varargout = process_fem_refine(varargin)
% PROCESS_FEM_TENSORS: Refine FEM mesh(es)

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
% Authors: Raymundo Cassani, Takfarinas Medani, 2025

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Refine FEM meshes';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Import anatomy'};
    sProcess.Index       = 25;
    sProcess.Description = '';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import'};
    sProcess.OutputTypes = {'import'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;
    sProcess.isSeparator = 1;
    % Subject name
    sProcess.options.subjectname.Comment = 'Subject name:';
    sProcess.options.subjectname.Type    = 'subjectname';
    sProcess.options.subjectname.Value   = '';
    % Refine using a ROI surface or selecting FEM layers

    % Options: FEM layers
    sProcess.options.femcond.Comment = {'panel_femrefine', 'Tissue conductivities: '};
    sProcess.options.femcond.Type    = 'editpref';
    sProcess.options.femcond.Value   = defFem;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    % Get options
    OPTIONS = sProcess.options.femcond.Value;
    % Compute
end

%% ===== COMPUTE =====
% Refines the FEM mesh(es)
function errMsg = Compute(FemFileName, RefineMethod, RefineMethodArg)
    if nargin < 3
        RefineMethodArg = [];
    end
    if nargin < 2
        RefineMethod = [];
    end
    % === Install/load required plugin: 'iso2mesh'
    [isInstalled, errMsg] = bst_plugin('Install', 'iso2mesh', 1);
    if ~isInstalled
        error(['Could not install or load plugin: iso2mesh' 10 errMsg]);
    end
    % === Load target FEM meshes
    bst_progress('start', 'Refine FEM mesh ','Loading the FEM mesh ');
    FemFullFile = file_fullpath(FemFileName);
    OPTIONS.FemFile = FemFullFile;
    FemMat = load(FemFullFile);
    % Hexahedral meshes not supported
    if (size(FemMat.Elements,2) > 4)
        bst_progress('stop');
        error('Hexahedral meshes are not supported.');
    end
    % === Get refine method
    if isempty(RefineMethod)
        RefineMethods = {'layer_refine', 'roi_refine'};
        [refineMode, isCancel]  = java_dialog('radio', '<HTML><B>Select the FEM refinement method:', 'Refine FEM mesh', [], ...
            {['<HTML>Refine specific tissue(s) in the FEM model <BR>' ...
              '<FONT COLOR="#707070">Select the tissue(s) to refine'], ...
             ['<HTML>Refine FEM mesh(es) within a specific ROI <BR>' ...
              '<FONT COLOR="#707070">Select or define a closed surface as ROI']}, 1);
        if isCancel || isempty(refineMode)
            bst_progress('stop');
            return
        end
        RefineMethod = RefineMethods{refineMode};
    end    
    OPTIONS.Method = RefineMethod;
    % Get file in database
    [sSubject, iSubject] = bst_get('SurfaceFile', FemFileName);
    % === Identify points to insert into the mesh {the elements centroides} for each method
    switch OPTIONS.Method
        % Refine specific FEM layer(s)
        case 'layer_refine'
            if isempty(RefineMethodArg)
                % Ask user to select the layer to refine with panel_femrefine
                LayerRefineOptions = gui_show_dialog('Refine FEM mesh', @panel_femrefine, 1, [], OPTIONS);
                if isempty(LayerRefineOptions)
                    return;
                end
            else                
                LayerRefineOptions = RefineMethodArg;
            end
            OPTIONS.LayerRefineOptions = LayerRefineOptions;
            % Get index of the element to refine
            elementsToRefine = [];
            layerToRefine = find(LayerRefineOptions.LayerRefine);
            for iRefine = 1 : length(layerToRefine)
                elementsToRefine(:,iRefine) = (FemMat.Tissue == layerToRefine(iRefine));
            end
            elementToRefineAll = find(sum(elementsToRefine,2));
            centroid = meshcentroid(FemMat.Vertices,FemMat.Elements(elementToRefineAll, :));

        % User creates ROI, all FEM meshes inside ROI will be refined
        case 'roi_refine'
            if isempty(RefineMethodArg)
                % Ask for surface and allow user to manual position the ROI
                % List of all the available surfaces in the subject database
                surfFileNames = {sSubject.Surface.FileName};
                surfComments  = {sSubject.Surface.Comment};
                % Ignore target FEM meshes
                iSurfFem = strcmpi({sSubject.Surface.SurfaceType}, 'fem');
                surfFileNames(iSurfFem) = [];
                surfComments(iSurfFem)  = [];        
                % Add geometric surfaces
                surfGeoComments = {'Sphere (radius 10 mm)', ...
                                   'Sphere (radius 25 mm)'};
                surfFileNames = [repmat({''}, 1, length(surfGeoComments)), surfFileNames];
                surfComments  = [surfGeoComments, surfComments];
                % Ask user to select the ROI area
                [surfSelectComment, isCancel] = java_dialog('combo', [...
                    'The ROI can be a geometric surface or a surface in the Subject.' 10 ...
                    '1) Edit the ROI (if needed), then' 10 ...
                    '2) Click on the [OK] button on figure toolbar.' 10 10 ...
                    'Select the ROI to apply the refinement.' 10], ...
                    'Refine FEM mesh(es) within a specific ROI', [], surfComments, surfComments{1});
                if isempty(surfSelectComment) || isCancel
                    bst_progress('stop');
                    return
                end
                % Generate geometric surface if needed
                if ismember(surfSelectComment, surfGeoComments)
                    switch surfSelectComment
                        case {'Sphere (radius 10 mm)', 'Sphere (radius 25 mm)'}
                            % Sphere with 250 vertices
                            [geo_vert, geo_faces] = tess_sphere(250);
                            % Get radius
                            r = sscanf(surfSelectComment, 'Sphere (radius %f mm');
                            geo_vert = r * geo_vert / 1000;
    
                        otherwise
                            % Geometric surface not supported
                    end
    
                    % Save geometric surface ROI
                    tag = sprintf('_%dV', size(geo_vert, 1));
                    OutputMat.Comment  = [surfSelectComment, tag];
                    OutputMat.Vertices = geo_vert;
                    OutputMat.Faces    = geo_faces;
                    % Output filename
                    OutputFile = bst_fullfile(bst_fileparts(OPTIONS.FemFile), 'tess_roi_refine.mat');
                    OutputFile = file_unique(OutputFile);
                    % Save file
                    bst_save(OutputFile, OutputMat, 'v7');
                    db_add_surface(iSubject, OutputFile, OutputMat.Comment);
                    % Add filename to surfFileNames
                    iSurf = strcmp(surfSelectComment, surfComments);
                    surfFileNames{iSurf} = file_short(OutputFile);
                end                
                % Open the GUI for ROI alignement on the FEM Mesh
                SurfaceFile = surfFileNames{strcmp(surfSelectComment, surfComments)};            
                % Get the handle of the figure and wait until closed to continue
                global gTessAlign;
                tess_align_manual(OPTIONS.FemFile, file_fullpath(SurfaceFile), 0);
                waitfor(gTessAlign.hFig)
            else
                % Name (Comment) of ROI surface was provided
                surfSelectComment = RefineMethodArg;
                surfFileNames = {sSubject.Surface.FileName};
                surfComments  = {sSubject.Surface.Comment};
                SurfaceFile = surfFileNames{strcmp(surfSelectComment, surfComments)};  
            end
            % Find all FEM mesh vertices within the ROI surface
            centroid = meshcentroid(FemMat.Vertices, FemMat.Elements);
            % Load ROI surface
            sSurf = in_tess_bst(SurfaceFile, 0);
            % Find points outside of the boundary
            iOutside = find(~inpolyhd(centroid, sSurf.Vertices, sSurf.Faces));
            % Remove the outside points
            if ~isempty(iOutside)
                centroid(iOutside,:) = [];
            end

            % % Ask the user if he wants to relabel the refined area
            % % Why this: it is possible that the ROI can be relabled and defined as
            % % different tissue such a tumor, stroke (core or penumbra)  or ablation area ...
            % [res, ~] = java_dialog('question', 'Do you want to set the selected region as a new tissue?', 'Relabel the new tissue?');
            % if strcmpi(res, 'yes')
            %     isNewTissue = 1;
            %     [NewTissueLabel, isCancel] = java_dialog('input', 'Please enter the label for the new tissue', 'Name for the new tissue');
            %     if isCancel
            %         return;
            %     end
            % end
    end
    % Remove one element to make the size different than Elements
    centroid(end, :) = [];

    % === Refine FEM mesh(es)
    bst_progress('text', 'Refining mesh ...');
    % if opt is a vector with a length that equals to that of node,
    [newnode,newelem] = meshrefine(FemMat.Vertices,[FemMat.Elements FemMat.Tissue], centroid);
    % Postprocess the mesh
    newelemOriented = meshreorient(newnode, newelem(:,1:4));
    newelemOriented = [newelemOriented newelem(:,5)];

    % === Save refined FEM mesh
    bst_progress('text', 'Saving refined mesh ...');

    FemMat.Vertices = newnode;
    FemMat.Elements = newelemOriented(:,1:4);
    % Tissue labels
    if size(newelemOriented,2) == 5
        FemMat.Tissue = newelem(:,5);
    else
        FemMat.Tissue = ones(1,size(newelemOriented,1));
    end
    % File comment
    switch OPTIONS.Method
        case 'layer_refine'
            tag = strjoin(FemMat.TissueLabels(layerToRefine), ', ');
        case 'roi_refine'
            tag = surfSelectComment;
    end
    refinedStr = ['Refined: ' num2str(length(newnode)) 'V'];
    FemMat.Comment = [FemMat.Comment ' | ' refinedStr ' - ' tag];
    % Add history
    FemMat = bst_history('add', FemMat, 'process_fem_mesh', [refinedStr, 'method = ' OPTIONS.Method ', ' tag]);
    % Save to database
    FemFile = file_unique(bst_fullfile(bst_fileparts(OPTIONS.FemFile), sprintf('tess_fem_%s_%dV.mat', OPTIONS.Method, length(FemMat.Vertices))));
    bst_save(FemFile, FemMat, 'v7');
    db_add_surface(iSubject, FemFile, FemMat.Comment);
    bst_progress('stop');
end
