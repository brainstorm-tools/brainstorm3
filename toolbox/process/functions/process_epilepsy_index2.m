function varargout = process_epilepsy_index2( varargin )
% PROCESS_EPILEPSY_INDEX2: Computes maps of epileptogenicity index for SEEG/ECOG recordings.
%
% REFERENCES: 
%     This function is the Brainstorm wrapper for function IMAGIN_Epileptogenicity.m
%     https://f-tract.eu/tutorials

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
% Authors: Francois Tadel, 2017

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Epileptogenicity index (A=Baseline,B=Seizure)';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Epilepsy';
    sProcess.Index       = 750;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'presults'};
    sProcess.nInputs     = 2;
    sProcess.nMinFiles   = 1;
    sProcess.isPaired    = 1;
    sProcess.Description = 'https://f-tract.eu/tutorials';

    % === SENSOR SELECTION
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'SEEG';
    sProcess.options.sensortypes.Group   = 'input';
    % === FREQUENCY RANGE
    sProcess.options.freqband.Comment = 'Frequency band (default=[60,200]): ';
    sProcess.options.freqband.Type    = 'freqrange';
    sProcess.options.freqband.Value   = [];
    % === LATENCY
    sProcess.options.latency.Comment = 'Latency, one or multiple time points (s): ';
    sProcess.options.latency.Type    = 'text';
    sProcess.options.latency.Value   = '0:2:20';
    % === TIME CONSTANT
    sProcess.options.timeconstant.Comment = 'Time constant: ';
    sProcess.options.timeconstant.Type    = 'value';
    sProcess.options.timeconstant.Value   = {3, 's', 3};
    % === TIME RESOLUTION
    sProcess.options.timeresolution.Comment = 'Time resolution: ';
    sProcess.options.timeresolution.Type    = 'value';
    sProcess.options.timeresolution.Value   = {0.2, 's', 3};
    % === PROPAGATION THRESHOLD
    sProcess.options.thdelay.Comment = 'Propagation threshold (p-value): ';
    sProcess.options.thdelay.Type    = 'value';
    sProcess.options.thdelay.Value   = {0.05, '', 4};
    % === OUTPUT TYPE
    sProcess.options.type.Comment = {'Volume', 'Surface', 'Output type: '; ...
                                     'volume', 'surface', ''};
    sProcess.options.type.Type    = 'radio_linelabel';
    sProcess.options.type.Value   = 'volume';
    sProcess.options.type.Group   = 'output';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputsA, sInputsB) %#ok<DEFNU>
    OutputFiles = {};
    
    % ===== GET OPTIONS =====
    % Get all the options
    SensorTypes = sProcess.options.sensortypes.Value;
    OPTIONS.FreqBand       = sProcess.options.freqband.Value{1};
    OPTIONS.Latency        = eval(sProcess.options.latency.Value);
    OPTIONS.HorizonT       = sProcess.options.timeconstant.Value{1};
    OPTIONS.TimeResolution = sProcess.options.timeresolution.Value{1};
    OPTIONS.ThDelay        = sProcess.options.thdelay.Value{1};
    OPTIONS.OutputType     = sProcess.options.type.Value;
    % Verifications
    if isempty(OPTIONS.Latency)
        bst_report('Error', sProcess, sInputsB, 'Invalid latency list: no time points identified.');
        return;
    end
    if (length(sInputsA) > 1) && (~all(strcmpi(sInputsA(1).SubjectFile, {sInputsA.SubjectFile})) || ~all(strcmpi(sInputsA(1).SubjectFile, {sInputsB.SubjectFile})))
        bst_report('Error', sProcess, sInputsB, 'All the input files must be attached to the same subject.');
        return;
    end
    % Additional options, that cannot be modified from this process
    OPTIONS.AR = 0;
    OPTIONS.FileName = '';

    % ===== CHECK TIME =====
    % Load time vectors
    for i = 1:length(sInputsB)
        DataMat = in_bst_data(sInputsB(i).FileName, 'Time');
        if (min(OPTIONS.Latency) < DataMat.Time(1))
            bst_report('Error', sProcess, sInputsB, sprintf('Latency %0.3fs is outside of an input files (%0.3f-%0.3fs).', min(OPTIONS.Latency), DataMat.Time(1), DataMat.Time(end)));
            return;
        elseif (max(OPTIONS.Latency) + OPTIONS.HorizonT > DataMat.Time(end))
            bst_report('Error', sProcess, sInputsB, sprintf('Latency %0.3fs (+ sliding window %0.3fs) is outside of an input files: [%0.3f,%0.3f]s.', max(OPTIONS.Latency), OPTIONS.HorizonT, DataMat.Time(1), DataMat.Time(end)));
            return;
        end
    end
    
    % ===== READ SUBJECT MRI =====
    % Get subject structure
    SubjectName = sInputsA(1).SubjectName;
    [sSubject, iSubject] = bst_get('Subject', SubjectName);
    % Load subjet MRI
    sMri = in_mri_bst(sSubject.Anatomy(sSubject.iAnatomy).FileName);

    % ===== EXPORT INPUT FILES =====
    % Work in Brainstorm's temporary folder
    workDir = bst_fullfile(bst_get('BrainstormTmpDir'), 'ImaGIN_epileptogenicity');
    % Make sure Matlab is not currently in the work directory
    curDir = pwd;
    if strfind(pwd, workDir)
        curDir = bst_fileparts(workDir);
        cd(curDir);
    end
    % Erase if it already exists
    if file_exist(workDir)
        file_delete(workDir, 1, 3);
    end
    % Create empty work folder
    res = mkdir(workDir);
    if ~res
        bst_report('Error', sProcess, sInputsB, ['Cannot create temporary directory: "' workDir '".']);
        return;
    end
    % Export all the files
    for iInput = 1:length(sInputsB)
        % Load files
        DataMatBaseline = in_bst_data(sInputsA(iInput).FileName);
        DataMatOnset    = in_bst_data(sInputsB(iInput).FileName);
        ChannelMat      = in_bst_channel(sInputsB(iInput).ChannelFile);
        % Select channels
        if ~isempty(SensorTypes)
            % Find channel indices
            iChan = channel_find(ChannelMat.Channel, SensorTypes);
            if isempty(iChan)
                bst_report('Error', sProcess, sInputsB, ['Channels not found: "' SensorTypes '".']);
                return;
            end
            % Keep only selected channels
            DataMatBaseline.F = DataMatBaseline.F(iChan,:);
            DataMatBaseline.ChannelFlag = DataMatBaseline.ChannelFlag(iChan);
            DataMatOnset.F = DataMatOnset.F(iChan,:);
            DataMatOnset.ChannelFlag = DataMatOnset.ChannelFlag(iChan);
            ChannelMat.Channel = ChannelMat.Channel(iChan);
        else
            iChan = 1:length(ChannelMat.Channel);
        end

        % Convert channel positions to MRI coordinates (for surface export, keep in everything in SCS)
        if strcmpi(OPTIONS.OutputType, 'volume')
            Tscs2mri = inv([sMri.SCS.R, sMri.SCS.T./1000; 0 0 0 1]);
            % If there is a transformation MRI=>RAS from a .nii file 
            if isfield(sMri, 'Header') && isfield(sMri.Header, 'nifti') && isfield(sMri.Header.nifti, 'sform_code') && isfield(sMri.Header.nifti, 'qform_code')
                nifti = sMri.Header.nifti;
                if isfield(nifti, 'vox2ras') && ~isempty(nifti.vox2ras)
                    vox2ras = nifti.vox2ras;
                elseif (nifti.sform_code ~= 0) && ~isempty(nifti.sform) && ~isequal(nifti.sform(1:3,1:3),zeros(3))
                    vox2ras = nifti.sform;
                elseif (nifti.qform_code ~= 0) && ~isempty(nifti.qform) && ~isequal(nifti.qform(1:3,1:3),zeros(3))
                    vox2ras = nifti.qform;
                else
                    vox2ras = [];
                end
                if ~isempty(vox2ras)
                    % Convert millimeters=>meters
                    vox2ras(1:3,4) = vox2ras(1:3,4) ./ 1000;
                    % Add this transformation
                    Tscs2mri = vox2ras * Tscs2mri;
                end
            end
            ChannelMat = channel_apply_transf(ChannelMat, Tscs2mri, iChan, 1);
            ChannelMat = ChannelMat{1};
        end
        % File tag
        [fPath,fBase] = bst_fileparts(sInputsB(iInput).FileName);
        [fPath, fileTag] = bst_fileparts(fPath);
        fileTag = strrep(fileTag, '_bipolar_1', '');
        fileTag = strrep(fileTag, '_bipolar_2', '');
        % Export file names
        BaselineFiles{iInput} = file_unique(bst_fullfile(workDir, ['baseline_' fileTag '.mat']));
        OnsetFiles{iInput}    = file_unique(bst_fullfile(workDir, [fileTag '.mat']));
        % Export to SPM .mat/.dat format
        BaselineFiles{iInput} = export_data(DataMatBaseline, ChannelMat, BaselineFiles{iInput}, 'SPM-DAT');
        OnsetFiles{iInput}    = export_data(DataMatOnset,    ChannelMat, OnsetFiles{iInput},    'SPM-DAT');
    end
    % Convert to ImaGIN filenames
    OPTIONS.D = char(OnsetFiles{:}); 
    OPTIONS.B = char(BaselineFiles{:});
    
    % ===== EXPORT ANATOMY =====
    % Output options
    switch lower(OPTIONS.OutputType)
        case 'volume'
            % Export MRI
            MriFile = bst_fullfile(workDir, 'mri.nii');
            export_mri(sMri, MriFile);
            % Additional options
            OPTIONS.Atlas        = 'Human';
            OPTIONS.CorticalMesh = 1;
            OPTIONS.sMRI         = MriFile;
            % Output format: NII surface
            fileFormat = 'ALLMRI';
            fileExt = '.nii';
        case 'surface'
            % Compute SPM canonical surfaces if necessary
            if isempty(sSubject.iCortex)
                isOk = process_generate_canonical('Compute', iSubject);
                if ~isOk
                    bst_report('Error', sProcess, sInputsB, 'Could not compute SPM canonical surfaces...');
                    return;
                end
                sSubject = bst_get('Subject', SubjectName);
            end
            % Export cortex mesh
            MeshFile = bst_fullfile(workDir, 'cortex.gii');
            out_tess_gii(sSubject.Surface(sSubject.iCortex).FileName, MeshFile, 0);
            % Additional options
            OPTIONS.SmoothIterations = 5;
            OPTIONS.MeshFile         = MeshFile;
            % Output format: GII surface
            fileFormat = 'GII';
            fileExt = '.gii';
    end

    % ===== CALL EPILEPTOGENICITY SCRIPT =====
    % Run script
    ImaGIN_Epileptogenicity(OPTIONS);
    % Restore initial directory
    cd(curDir);
    % Close all SPM figures
    close([spm_figure('FindWin','Menu'), spm_figure('FindWin','Graphics'), spm_figure('FindWin','Interactive')]);
    
    % ===== OUTPUT FOLDER =====
    % Default condition name
    Condition = 'Epileptogenicity';
    % Get condition asked by user
    [sStudy, iStudy] = bst_get('StudyWithCondition', bst_fullfile(SubjectName, Condition));
    % Condition does not exist: create it
    if isempty(sStudy)
        % Add new folder
        iStudy = db_add_condition(SubjectName, Condition, 1);
        % Copy channel file from first file
        db_set_channel(iStudy, sInputsB(1).ChannelFile, 1, 0);
    end
    
    % ===== READ EPILEPTOGENICITY MAPS =====
    % List all the epileptogenicity maps in output
    listFiles = dir(bst_fullfile(workDir, 'SPM_*', ['spmT_0001', fileExt]));
    % Import all the stat files
    for i = 1:length(listFiles)
        % File comment = SPM folder
        [tmp, Comment] = bst_fileparts(listFiles(i).folder);
        Comment = strrep(Comment, 'SPM_', '');
        % Import file
        tmpFiles = import_sources(iStudy, [], bst_fullfile(listFiles(i).folder, listFiles(i).name), [], fileFormat, Comment);
        OutputFiles = cat(2, OutputFiles, tmpFiles);
    end
    
    % ===== READ DELAY MAPS =====
    % List all the epileptogenicity maps in output
    listFiles = dir(bst_fullfile(workDir, ['Delay_*', fileExt]));
    % Import all the stat files
    for i = 1:length(listFiles)
        % File comment = File name
        [tmp, Comment] = bst_fileparts(listFiles(i).name);
        % Import file
        tmpFiles = import_sources(iStudy, [], bst_fullfile(listFiles(i).folder, listFiles(i).name), [], fileFormat, Comment);
    end
end

    



