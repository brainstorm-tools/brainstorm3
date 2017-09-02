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
    sSubject = bst_get('Subject', sInputsA(1).SubjectName);
    % Load subjet MRI
    sMri = in_mri_bst(sSubject.Anatomy(sSubject.iAnatomy).FileName);

    % ===== EXPORT INPUT FILES =====
    % Work in Brainstorm's temporary folder
    workDir = bst_fullfile(bst_get('BrainstormTmpDir'), 'ImaGIN_epileptogenicity');
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
        % Convert channel positions to MRI coordinates (for surface export, keep in everything in SCS)
        if strcmpi(OPTIONS.OutputType, 'volume')
            error('TODO => CONVERT TO MRI, INCLUDING VOX2RAS')
            Tscs2mri = inv([sMri.SCS.R, sMri.SCS.T./1000; 0 0 0 1]);

            ChannelMat = channel_apply_transf(ChannelMat, Transf, iChannels, isHeadPoints);
        end
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
        end
        % Export file names
        BaselineFiles{iInput} = bst_fullfile(workDir, sprintf('baseline_%03d.mat', iInput));
        OnsetFiles{iInput}    = bst_fullfile(workDir, sprintf('onset_%03d.mat',    iInput));
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
        case 'surface'
            % Load MRI structure
            sMri = in_mri_bst(sSubject.Anatomy(sSubject.iAnatomy).FileName);
            % Export cortex mesh
            MeshFile = bst_fullfile(workDir, 'cortex.gii');
            export_surfaces(sSubject.Surface(sSubject.iCortex).FileName, MeshFile, 'GII', sMri);
            % Additional options
            OPTIONS.SmoothIterations = 5;
            OPTIONS.MeshFile         = MeshFile;
    end

    % ===== CALL EPILEPTOGENICITY SCRIPT =====
    % Make sure Matlab is not currently in the work directory
    curDir = pwd;
    if strfind(pwd, workDir)
        cd(bst_fileparts(workDir));
    end
    % Run script
    ImaGIN_Epileptogenicity(OPTIONS);
    
    % Restore initial directory
    cd(curDir);
    
end

    


