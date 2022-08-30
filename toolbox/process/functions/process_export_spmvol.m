function varargout = process_export_spmvol( varargin )
% PROCESS_EXPORT_SPMVOL: Export source files to NIFTI files readable by SPM.
%
% USAGE:     sProcess = process_export_spmvol('GetDescription')
%                       process_export_spmvol('Run', sProcess, sInputs)

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
% Authors: Francois Tadel, 2013-2021

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Export to SPM8/SPM12 (volume)';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'File';
    sProcess.Index       = 980;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/ExportSpm8';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'results', 'timefreq', 'presults'};
    sProcess.OutputTypes = {'results', 'timefreq', 'presults'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Definition of the options
    % === OUTPUT FOLDER
    % File selection options
    SelectOptions = {...
        '', ...                            % Filename
        '', ...                            % FileFormat
        'save', ...                        % Dialog type: {open,save}
        'Select output folder...', ...     % Window title
        'ExportData', ...                  % LastUsedDir: {ImportData,ImportChannel,ImportAnat,ExportChannel,ExportData,ExportAnat,ExportProtocol,ExportImage,ExportScript}
        'single', ...                      % Selection mode: {single,multiple}
        'dirs', ...                        % Selection mode: {files,dirs,files_and_dirs}
        bst_get('FileFilters', 'Source4d'), ... % Available file formats
        'SpmOut'};                         % DefaultFormats: {ChannelIn,DataIn,DipolesIn,EventsIn,AnatIn,MriIn,NoiseCovIn,ResultsIn,SspIn,SurfaceIn,TimefreqIn}
    % Option definition
    sProcess.options.outputdir.Comment = 'Output folder:';
    sProcess.options.outputdir.Type    = 'filename';
    sProcess.options.outputdir.Value   = SelectOptions;
    % === OUTPUT FILE TAG
    sProcess.options.filetag.Comment = 'Output file tag (default=Subj_Cond):';
    sProcess.options.filetag.Type    = 'text';
    sProcess.options.filetag.Value   = '';
    % === ALL OUTPUT IN ONE FILE
    sProcess.options.isconcat.Comment = 'Save all the trials in one file (time average only)';
    sProcess.options.isconcat.Type    = 'checkbox';
    sProcess.options.isconcat.Value   = 1;
    % === TIME WINDOW
    sProcess.options.labeltime.Comment = '<BR><B>Time options</B>:';
    sProcess.options.labeltime.Type    = 'label';
    sProcess.options.timewindow.Comment = 'Time window:';
    sProcess.options.timewindow.Type    = 'timewindow';
    sProcess.options.timewindow.Value   = [];
    % === TIME DOWNSAMPLE
    sProcess.options.timedownsample.Comment = 'Time downsample factor: ';
    sProcess.options.timedownsample.Type    = 'value';
    sProcess.options.timedownsample.Value   = {3,'(integer)',0};
    % === AVERAGE OVER TIME
    sProcess.options.timemethod.Comment = {'Average time (3D volume)', 'Keep time dimension (4D volume)'};
    sProcess.options.timemethod.Type    = 'radio';
    sProcess.options.timemethod.Value   = 1;
    % === FREQUENCY
    sProcess.options.labelfreq.Comment    = '<BR><B>Frequency options</B>:';
    sProcess.options.labelfreq.Type       = 'label';
    sProcess.options.labelfreq.InputTypes = {'timefreq'};
    sProcess.options.freq_export.Comment    = 'Frequency band to export:';
    sProcess.options.freq_export.Type       = 'freqsel';
    sProcess.options.freq_export.Value      = [];
    sProcess.options.freq_export.InputTypes = {'timefreq'};
    % === VOLUME DOWNSAMPLE
    sProcess.options.labelvol.Comment = '<BR><B>Volume options</B>:';
    sProcess.options.labelvol.Type    = 'label';
    sProcess.options.voldownsample.Comment = 'Volume downsample factor: ';
    sProcess.options.voldownsample.Type    = 'value';
    sProcess.options.voldownsample.Value   = {2,'(integer)',0};
    % === ABSOLUTE VALUES
    sProcess.options.isabs.Comment    = 'Use absolute values of the sources';
    sProcess.options.isabs.Type       = 'checkbox';
    sProcess.options.isabs.Value      = 1;
    sProcess.options.isabs.InputTypes = {'results'};
    % === CUT EMPTY SLICES
    sProcess.options.iscut.Comment = 'Cut empty slices <FONT color="#707070"><I>(not recommended)</I></FONT>';
    sProcess.options.iscut.Type    = 'checkbox';
    sProcess.options.iscut.Value   = 0;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    % Get output folder
    OutputDir  = sProcess.options.outputdir.Value{1};
    FileFormat = sProcess.options.outputdir.Value{2};
    if isempty(OutputDir)
        bst_report('Error', sProcess, sInputs, 'Output directory is not defined.');
        return;
    end
    % If a file was selected: take the containing folder
    if ~isdir(OutputDir)
        OutputDir = bst_fileparts(OutputDir);
    end
    % Get other options
    ForceTag   = sProcess.options.filetag.Value;
    TimeDownsample = sProcess.options.timedownsample.Value{1};
    isAvgTime      = (sProcess.options.timemethod.Value == 1);
    if isfield(sProcess.options, 'timewindow') && isfield(sProcess.options.timewindow, 'Value') && iscell(sProcess.options.timewindow.Value)
        TimeWindow = sProcess.options.timewindow.Value{1};
    else
        TimeWindow = [];
    end
    if isfield(sProcess.options, 'freq_export') && isfield(sProcess.options.freq_export, 'Value') && ~isempty(sProcess.options.freq_export.Value)
        iFreqExport = sProcess.options.freq_export.Value;
    else
        iFreqExport = 1;
    end
    if isfield(sProcess.options, 'voldownsample') && isfield(sProcess.options.voldownsample, 'Value') && iscell(sProcess.options.voldownsample.Value)
        VolDownsample = sProcess.options.voldownsample.Value{1};
    else
        VolDownsample = 1;
    end
    if isfield(sProcess.options, 'isabs') && isfield(sProcess.options.isabs, 'Value') && ~isempty(sProcess.options.isabs.Value)
        isAbsolute = sProcess.options.isabs.Value;
    else
        isAbsolute = 0;
    end
    if isfield(sProcess.options, 'isconcat') && isfield(sProcess.options.isconcat, 'Value') && ~isempty(sProcess.options.isconcat.Value)
        isConcatTrials = sProcess.options.isconcat.Value;
    else
        isConcatTrials = 0;
    end
    if isfield(sProcess.options, 'iscut') && isfield(sProcess.options.iscut, 'Value') && ~isempty(sProcess.options.iscut.Value)
        isCutEmpty = sProcess.options.iscut.Value;
    else
        isCutEmpty = 0;
    end
    
    % If there is only one trial: ignore concatenation
    if (length(sInputs) == 1)
        isConcatTrials = 0;
    end
    % Check for incompatible options
    if isConcatTrials && ~isAvgTime
        bst_report('Error', sProcess, sInputs, ['Incompatible options: "Save all the trials in one file" and "Keep time dimension".' 10 'They both need the time dimension.']);
        return;
    end
    % If all the files have the same Subject/Condition: consider it is enforced (to have it numbered)
    if isempty(ForceTag) && (length(sInputs) > 1) && all(strcmpi({sInputs.SubjectName}, sInputs(1).SubjectName)) && all(strcmpi({sInputs.Condition}, sInputs(1).Condition))
        ForceTag = [sInputs(1).SubjectName, '_', sInputs(1).Condition];
    end
    
    % Saving volume or surface?
    isVolume = ~strcmpi(FileFormat, 'GIFTI');
    % Options for LoadInputFile()
    LoadOptions.LoadFull    = 1;
    LoadOptions.IgnoreBad   = 0;
    LoadOptions.ProcessName = 'process_export_spmvol';
    % Initialize some variables
    prevGridLoc = [];
    prevInterp = [];
    prevMriFile = [];
    prevSurface = [];
    giiSurface = [];

    % ===== SAVE FILES =====
    bst_progress('start', 'Export sources', 'Saving files...', 0, length(sInputs));
    for iFile = 1:length(sInputs)
        bst_progress('inc',1);
        
        % ===== LOAD RESULTS =====
        % Load results
        sInput = bst_process('LoadInputFile', sInputs(iFile).FileName, [], TimeWindow, LoadOptions);
        if isempty(sInput.Data)
            bst_report('Error', sProcess, sInputs(iFile), 'Could load result file.');
            return;
        elseif ~isempty(sInput.RowNames) && iscell(sInput.RowNames)
            bst_report('Error', sProcess, sInputs(iFile), 'Cannot export scouts time series as volume, use full brain results instead.');
            return;
        end
        % Load additional fields
        strFreq = '';
        switch (sInputs(iFile).FileType)
            case {'results', 'presults'}
                ResultsMat = in_bst_results(sInputs(iFile).FileName, 0, 'HeadModelType', 'SurfaceFile', 'Atlas', 'GridLoc', 'GridAtlas', 'DisplayUnits');
                isVolumeGrid = ismember(ResultsMat.HeadModelType, {'volume', 'mixed'});
            case 'timefreq'
                % Check that a measure was applied to the data
                if ~all(isreal(sInput.Data))
                    bst_report('Error', sProcess, sInputs, 'You need to apply a measure to the time-frequency maps before exporting the values.');
                    return;
                end
                % Load additional fields
                ResultsMat = in_bst_timefreq(sInputs(iFile).FileName, 0, 'SurfaceFile', 'Atlas', 'GridLoc', 'GridAtlas', 'Freqs', 'DisplayUnits');
                % Guess some missing modeling properties
                isVolumeGrid = ~isempty(ResultsMat.GridLoc);
                if isVolumeGrid
                    ResultsMat.HeadModelType = 'volume';
                else
                    ResultsMat.HeadModelType = 'surface';
                end
                sInput.nComponents = 1;
                % Select one frequency band only
                sInput.Data = sInput.Data(:,:,iFreqExport);
                % Add a tag to the output filename
                if iscell(ResultsMat.Freqs)
                    strFreq = ['_' ResultsMat.Freqs{iFreqExport,1}];
                else
                    strFreq = ['_' num2str(ResultsMat.Freqs(iFreqExport)) 'hz'];
                end
        end
        % Take the absolute value of the sources
        if isAbsolute
            sInput.Data = abs(sInput.Data);
        end
        % Average in time
        if isAvgTime
            sInput.Data = mean(sInput.Data,2);
        % Reading a static file (already averaged in time)
        elseif (size(sInput.Data,2) <= 2)
            sInput.Data = sInput.Data(:,1);
        % Downsampling in time
        elseif (TimeDownsample > 1)
            sInput.Data = sInput.Data(:, 1:TimeDownsample:size(sInput.Data,2));
        end
        % Unconstrained sources: combine orientations (norm of all dimensions)
        sInput.Data = bst_source_orient([], sInput.nComponents, ResultsMat.GridAtlas, sInput.Data, 'rms');
        % If an atlas exists
        if strcmpi(ResultsMat.HeadModelType, 'surface') && isfield(ResultsMat, 'Atlas') && ~isempty(ResultsMat.Atlas) && ~isempty(ResultsMat.Atlas.Scouts)
            Atlas = ResultsMat.Atlas;
        else
            Atlas = [];
        end

        % === INTERPOLATE ON MRI VOLUME ===
        if isVolume
            % === READ ANATOMY ===
            % Get subject
            [sSubject, iSubject] = bst_get('Subject', sInputs(iFile).SubjectFile);
            % Get MRI file
            MriFile = sSubject.Anatomy(1).FileName;
            % If it is not the same MRI as the previously loaded MRI volume: load again
            if ~isequal(prevMriFile, MriFile)
                % Load file
                sMri = in_mri_bst(MriFile);
                if isempty(sMri)
                    bst_report('Error', sProcess, sInputs(iFile), 'Could load MRI file.');
                    return;
                end
                % Save as the previous volume for the next iteration
                prevMriFile = MriFile;
            end

            % ===== GET INTERPOLATION MATRIX =====
            % Surface head model
            switch (ResultsMat.HeadModelType)
                case 'surface'
                    % Compute or load interpolation matrix MRI<->Surface
                    MriInterp = tess_interp_mri(ResultsMat.SurfaceFile, sMri);
                    % Unload surface
                    bst_memory('UnloadSurface', ResultsMat.SurfaceFile);

                case {'volume', 'mixed'}
                    % Try to re-use previously computed interpolation
                    if isequal(prevGridLoc, ResultsMat.GridLoc) && isequal(prevMriFile, MriFile) && ~isempty(prevInterp)
                        MriInterp = prevInterp;
                    % Else: Compute interpolation matrix grid points => MRI voxels
                    else
                        sMri.FileName = MriFile;
                        GridSmooth = isempty(ResultsMat.DisplayUnits) || ~ismember(ResultsMat.DisplayUnits, {'s','ms','t'});
                        MriInterp = grid_interp_mri(ResultsMat.GridLoc, sMri, ResultsMat.SurfaceFile, 0, [], [], GridSmooth);
                        % Save values for next iteration
                        prevInterp  = MriInterp;
                        prevGridLoc = ResultsMat.GridLoc;
                    end
            end
        % Export surface-based files
        else
            MriInterp = [];
            % If the head model is volume-based: cannot export surface-based files
            if strcmpi(ResultsMat.HeadModelType, 'volume')
                bst_report('Error', sProcess, sInputs(iFile), 'Cannot export volume-based sources to surface-based files.');
                return;
            end
            % Try to re-use the previous surface
            if ~isequal(prevSurface, ResultsMat.SurfaceFile)
                giiSurface = bst_fullfile(OutputDir, [sInputs(iFile).SubjectName '_cortex.gii']);
                out_tess_gii(ResultsMat.SurfaceFile, giiSurface, 1);
            end
        end
        
        % ===== OPEN OUTPUT FILE =====
        % Start a new file
        if (iFile == 1) || ~isConcatTrials
            % If file tag is not defined, use "Subject_Condition"
            if ~isempty(ForceTag)
                fileTag = ForceTag;
            else
                fileTag = [sInputs(iFile).SubjectName, '_', sInputs(iFile).Condition];
            end
            fileTag = [fileTag, strFreq];
            % For non-concatenated trials: add an extension for the trial number
            if (length(sInputs) > 1) && ~isConcatTrials && ~isempty(ForceTag)
                TrialTag = ['_' num2str(iFile, '%03d')];
            else
                TrialTag = '';
            end
            % Number of entries saved in the output file: time or trials
            if isConcatTrials
                Nt = length(sInputs);
            else
                Nt = size(sInput.Data,2);
            end

            % Output filename: extension
            switch (FileFormat)
                case 'Analyze', fileExt = '.img'; dataType = 'float32';
                case 'Nifti1',  fileExt = '.nii'; dataType = 'float32';
                case 'BST',     fileExt = '.mat'; 
                case 'GIFTI',   fileExt = '.gii';
            end
            % Output filename: full path
            OutputFile = file_unique(bst_fullfile(OutputDir, [fileTag TrialTag fileExt]));
        end
        
        % ===== LOOP ON TIME POINTS =====
        for i = 1:size(sInput.Data,2)
            % === ATLAS SOURCES ===
            if ~isempty(Atlas)
                % Initialize full cortical map
                ScoutData = sInput.Data;
                sInput.Data = zeros(size(MriInterp,2),1);
                % Duplicate the value of each scout to all the vertices
                for iScout = 1:length(Atlas.Scouts)
                    sInput.Data(Atlas.Scouts(iScout).Vertices,:) = ScoutData(iScout,:);
                end
            end
            % === BUILD OUTPUT VOLUME ===
            if isVolume
                sMriOut = sMri;
                % Reset nifti field, so that the header is not reused as is
                sMriOut.Header = [];
                % Build interpolated cube
                sMriOut.Cube = tess_interp_mri_data(MriInterp, size(sMri.Cube(:,:,:,1)), sInput.Data(:,i), isVolumeGrid);
                % Downsample volume
                if (VolDownsample > 1)
                    newCubeDim = [size(sMri.Cube,1), size(sMri.Cube,2), size(sMri.Cube,3)] ./ VolDownsample;
                    newVoxsize = sMriOut.Voxsize .* VolDownsample;
                    sMriOut = mri_resample(sMriOut, newCubeDim, newVoxsize, 'linear');
                end
                % Cut the empty slices
                if isCutEmpty
                    % Detect the empty slices: only first volume
                    if (iFile == 1) && (i == 1)
                        isEmptySlice{1} = find(all(all(sMriOut.Cube == 0, 2), 3));
                        isEmptySlice{2} = find(all(all(sMriOut.Cube == 0, 1), 3));
                        isEmptySlice{3} = find(all(all(sMriOut.Cube == 0, 1), 2));
                    end
                    % Cut unused slices
                    if ~isempty(isEmptySlice{1}) || ~isempty(isEmptySlice{2}) || ~isempty(isEmptySlice{3})
                        sMriOut.Cube(isEmptySlice{1},:,:) = [];
                        sMriOut.Cube(:,isEmptySlice{2},:) = [];
                        sMriOut.Cube(:,:,isEmptySlice{3}) = [];
                        % Update the fiducial coordinates (used as the origin of the volume)
                        if isfield(sMriOut, 'SCS') 
                            for fidname = {'NAS','LPA','RPA','T','Origin'}
                                if isfield(sMriOut.SCS, fidname{1}) && ~isempty(sMriOut.SCS.(fidname{1}))
                                    sMriOut.SCS.(fidname{1}) = FixFiducials(sMriOut.Voxsize, isEmptySlice, sMriOut.SCS.(fidname{1}), VolDownsample);
                                end
                            end
                            sMriOut.SCS.T = [];
                            sMriOut.SCS.R = [];
                            sMriOut.SCS.Origin = [];
                        end
                        if isfield(sMriOut, 'NCS') 
                            for fidname = {'AC','PC','IH','T','Origin'}
                                if isfield(sMriOut.NCS, fidname{1}) && ~isempty(sMriOut.NCS.(fidname{1}))
                                    sMriOut.NCS.(fidname{1}) = FixFiducials(sMriOut.Voxsize, isEmptySlice, sMriOut.NCS.(fidname{1}), VolDownsample);
                                end
                            end
                            sMriOut.NCS.T = [];
                            sMriOut.NCS.R = [];
                            sMriOut.NCS.Origin = [];
                        end
                        % Remove the initial transformation
                        sMriOut.InitTransf = [];
                        sMriOut.Header = [];
                    end
                end
            end
            % === SAVE STEP ===
            switch (FileFormat)
                case {'Analyze', 'Nifti1'}
                    % Create file
                    if (i == 1) && ((iFile == 1) || ~isConcatTrials)
                        fid = out_mri_nii(sMriOut, OutputFile, dataType, Nt);
                    end
                    % Save volume
                    for z = 1:size(sMriOut.Cube,3)
                        fwrite(fid, sMriOut.Cube(:,:,z), dataType);
                    end
                case 'GIFTI'
                    % Create a surface data matrix
                    if (i == 1) && ((iFile == 1) || ~isConcatTrials)
                        SurfData = zeros([size(sInput.Data,1), Nt], 'single');
                        indSurf = 1;
                    end
                    % Add current volume
                    SurfData(:,indSurf) = single(sInput.Data(:,i));
                    indSurf = indSurf + 1;
                case 'BST'
                    % Create new structure
                    if (i == 1) && ((iFile == 1) || ~isConcatTrials)
                        Cube4D = zeros([size(sMriOut.Cube), Nt], 'single');
                        indCube = 1;
                    end
                    % Add current volume
                    Cube4D(:,:,:,indCube) = single(sMriOut.Cube);
                    indCube = indCube + 1;
            end
        end

        % ===== CLOSE/SAVE FILE =====
        % Close the current file
        if (iFile == length(sInputs)) || ~isConcatTrials
            switch (FileFormat)
                case {'Analyze', 'Nifti1'}
                    fclose(fid);
                case 'GIFTI'
                    out_spm_gii(giiSurface, OutputFile, SurfData);
                case 'BST'
                    sMriOut.Cube = Cube4D;
                    bst_save(OutputFile, sMriOut, 'v7');
            end
        end
    end
    % Returned files: same as input
    OutputFiles = {sInputs.FileName};
end


%% ===== FIX FIDUCIALS =====
function P = FixFiducials(Voxsize, isEmptySlice, P, VolDownsample)
    for dim = 1:3
        P(dim) = P(dim) - nnz(isEmptySlice{dim} <= P(dim) ./ Voxsize(dim)) .* Voxsize(dim) ./ VolDownsample;
    end
end



