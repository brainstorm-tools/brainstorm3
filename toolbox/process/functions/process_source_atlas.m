function varargout = process_source_atlas( varargin )
% PROCESS_SOURCE_ATLAS: Project a source file on an atlas (one time series per scout).

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
% Authors: Francois Tadel, 2012-2014

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % ===== PROCESS =====
    % Description the process
    sProcess.Comment     = 'Downsample to atlas';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'Sources';
    sProcess.Index       = 335;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/News#Project sources_to_an_atlas';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'results'};
    sProcess.OutputTypes = {'results'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 0;
    % === SELECT ATLAS
    sProcess.options.atlas.Comment = 'Select atlas:';
    sProcess.options.atlas.Type    = 'atlas';
    sProcess.options.atlas.Value   = [];
    % === NORM XYZ
    sProcess.options.isnorm.Comment = 'Unconstrained sources: Norm of the three orientations (x,y,z)';
    sProcess.options.isnorm.Type    = 'checkbox';
    sProcess.options.isnorm.Value   = 0;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInput) %#ok<DEFNU>
    OutputFiles = {};
    isNorm = sProcess.options.isnorm.Value;
    
    % ===== LOAD ALL INFO =====
    % Load the surface filename from results file
    ResultsMat = in_bst_results(sInput.FileName, 0);
    % Error: cannot process results from volume grids
    if ismember(ResultsMat.HeadModelType, {'volume', 'mixed'})
        bst_report('Error', sProcess, sInput, 'Atlases are not supported yet for volumic grids.');
        return;
    elseif isempty(ResultsMat.SurfaceFile)
        bst_report('Error', sProcess, sInput, 'Surface file is not defined.');
        return;
    elseif isfield(ResultsMat, 'Atlas') && ~isempty(ResultsMat.Atlas)
        bst_report('Error', sProcess, sInput, 'File is already based on an atlas.');
        return;
    end
    % Load surface
    SurfaceMat = in_tess_bst(ResultsMat.SurfaceFile);
    if isempty(SurfaceMat.Atlas) 
        bst_report('Error', sProcess, sInput, 'No atlases available in the current surface.');
        return;
    end
    % Forbid this process on mixed head models
    if (ResultsMat.nComponents == 0)
        bst_report('Error', sProcess, sInput, 'Cannot run this process on mixed source models.');
        return;
    end
    % Get the atlas to use
    iAtlas = [];
    if ~isempty(sProcess.options.atlas.Value)
        iAtlas = find(strcmpi({SurfaceMat.Atlas.Name}, sProcess.options.atlas.Value));
        if isempty(iAtlas)
            bst_report('Warning', sProcess, sInput, ['Atlas not found: "' sProcess.options.atlas.Value '"']);
        end
    end
    if isempty(iAtlas)
        iAtlas = SurfaceMat.iAtlas;
    end
    if isempty(iAtlas)
        iAtlas = 1;
    end
    % Check atlas 
    if isempty(SurfaceMat.Atlas(iAtlas).Scouts)
        bst_report('Error', sProcess, sInput, 'No available scouts in the selected atlas.');
        return;
    end
    bst_report('Info', sProcess, sInput, ['Projecting on atlas: "' SurfaceMat.Atlas(iAtlas).Name '"']);
    
    % Get all the scouts in current atlas
    sScouts = SurfaceMat.Atlas(iAtlas).Scouts;
    % Check if any scouts are set to "All"
    if any(strcmpi({sScouts.Function}, 'All'))
        bst_report('Error', sProcess, sInput, 'Scouts with function "All" are not accepted by this function.');
        return;
    end
    % If results in compact/kernel mode
    if isfield(ResultsMat, 'ImageGridAmp') && isempty(ResultsMat.ImageGridAmp) && ~isempty(ResultsMat.ImagingKernel)
        % No data file
        if isempty(ResultsMat.DataFile)
            bst_report('Error', sProcess, sInput, 'No data file defined for this inverse kernel.');
            return;
        end
        % Load data
        DataFileFull = file_fullpath(ResultsMat.DataFile);
        if file_exist(DataFileFull)
            DataMat = load(DataFileFull, 'F', 'Time');
            Time = DataMat.Time;
        else
            bst_report('Error', sProcess, sInput, 'Data file not found for this inverse kernel.');
            return;
        end
    else
        DataMat = [];
        Time = ResultsMat.Time;
    end
    
    % ===== CALCULATE SCOUTS VALUES =====
    % Initialize value
    if (ResultsMat.nComponents == 1) || isNorm
        ImageGridAmp = zeros(length(sScouts), length(Time));
    else
        ImageGridAmp = zeros(ResultsMat.nComponents * length(sScouts), length(Time));
    end
    if ~isfield(ResultsMat, 'GridAtlas')
        ResultsMat.GridAtlas = [];
    end
    % Process each scout individually
    for iScout = 1:length(sScouts)
        % === GET VERTEX INDICES ===
        % Get all the row indices involved in this scout
        iVertices = sort(unique(sScouts(iScout).Vertices));
        % Get scout orientation
        ScoutOrient = SurfaceMat.VertNormals(iVertices,:);
        % List of rows to read depends on the number of componentns per vertex
        iRows = bst_convert_indices(iVertices, ResultsMat.nComponents, ResultsMat.GridAtlas, 0);
        
        % === GET SOURCES ===
        if ~isempty(DataMat)
            Fscout = ResultsMat.ImagingKernel(iRows,:) * DataMat.F(ResultsMat.GoodChannel, :);
        else
            Fscout = ResultsMat.ImageGridAmp(iRows,:);
        end
        
        % === APPLY DYNAMIC ZSCORE ===
        if isfield(ResultsMat, 'ZScore') && ~isempty(ResultsMat.ZScore)
            ZScore = ResultsMat.ZScore;
            % Keep only the selected vertices
            if ~isempty(ZScore.mean)
                ZScore.mean = ZScore.mean(iRows,:);
                ZScore.std  = ZScore.std(iRows,:);
            end
            % Calculate mean/std
            if isempty(ZScore.mean)
                Fscout = process_zscore_dynamic('Compute', Fscout, ZScore, DataMat.Time, ResultsMat.ImagingKernel(iRows,:), DataMat.F(ResultsMat.GoodChannel,:));
            % Apply existing mean/std
            else
                Fscout = process_zscore_dynamic('Compute', Fscout, ZScore);
            end
        end
        
        % === COMPUTE SCOUT VALUES ===
        if (ResultsMat.nComponents == 1)
            isFlipSign = strcmpi(sInput.FileType, 'results') && ...
                         isempty(strfind(sInput.FileName, '_abs')) && ...
                         isempty(strfind(sInput.FileName, '_norm')) && ...
                         isempty(strfind(sInput.FileName, 'NIRS'));
            ImageGridAmp(iScout,:) = bst_scout_value(Fscout, sScouts(iScout).Function, ScoutOrient, ResultsMat.nComponents, [], isFlipSign);
        elseif isNorm
            ImageGridAmp(iScout,:) = bst_scout_value(Fscout, sScouts(iScout).Function, ScoutOrient, ResultsMat.nComponents, 'norm');
        else
            iRow = 3 * (iScout - 1) + [1 2 3];
            ImageGridAmp(iRow,:) = bst_scout_value(Fscout, sScouts(iScout).Function, ScoutOrient, ResultsMat.nComponents, 'none');
        end
    end
    
    % ===== SAVE FILE =====
    % Create returned structure 
    NewMat = ResultsMat;
    NewMat.ImageGridAmp  = ImageGridAmp;
    NewMat.ImagingKernel = [];
    % NewMat.Comment       = [NewMat.Comment, ' | atlas' num2str(length(sScouts))];
    NewMat.Comment       = [NewMat.Comment, ' | ', SurfaceMat.Atlas(iAtlas).Name];
    NewMat.Time          = Time;
    NewMat.Atlas         = SurfaceMat.Atlas(iAtlas);
    NewMat.ZScore        = [];
    % Number of components
    if (ResultsMat.nComponents == 1) || isNorm
        NewMat.nComponents = 1;
    else
        NewMat.nComponents = ResultsMat.nComponents;
    end
    % Add history entry
    NewMat = bst_history('add', NewMat, 'atlas', ['Downsample to atlas: ' SurfaceMat.Atlas(iAtlas).Name]);
    % Get data file
    if ~isempty(NewMat.DataFile)
        % Find file in database
        [sStudy, iStudy, iData] = bst_get('DataFile', NewMat.DataFile);
        % Get the short name referenced in the database
        NewMat.DataFile = sStudy.Data(iData).FileName;
    end
    % Get output study
    sStudy = bst_get('Study', sInput.iStudy);
    % File tag
    if ~isempty(strfind(sInput.FileName, '_abs_zscore'))
        fileTag = 'results_abs_zscore_atlas';
    elseif ~isempty(strfind(sInput.FileName, '_zscore'))
        fileTag = 'results_zscore_atlas';
    else
        fileTag = 'results_atlas';
    end
    % Output filename
    OutputFiles{1} = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), fileTag);
    % Save on disk
    bst_save(OutputFiles{1}, NewMat, 'v6');
    % Register in database
    db_add_data(sInput.iStudy, OutputFiles{1}, NewMat);
end



