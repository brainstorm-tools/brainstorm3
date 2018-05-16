function varargout = process_epileptogenicity( varargin )
% PROCESS_EPILEPTOGENICITY: Computes epileptogenicity maps for SEEG/ECOG ictal recordings.
%
% REFERENCES: 
%     This function is the Brainstorm wrapper for function IMAGIN_Epileptogenicity.m
%     https://f-tract.eu/tutorials

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
    sProcess.Comment     = 'Epileptogenicity maps (A=Baseline,B=Seizure)';
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

    % === HELP
    sProcess.options.help.Comment = [ ...
        'This process computes epileptogenicity maps based on<BR>' ...
        'SEEG ictal recordings. The methodology is described in:<BR>' ...
        '<FONT COLOR="#808080"><I>David O, Blauwblomme T, Job AS, Chabardès S, Hoffmann D, <BR>' ...
        'Minotti L, Kahane P. Imaging the seizure onset zone with <BR>' ...
        'stereo-electroencephalography. Brain (2011).</I></FONT><BR><BR>'];
    sProcess.options.help.Type    = 'label';
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
    sProcess.options.thdelay.Comment = 'Propagation threshold (p or T): ';
    sProcess.options.thdelay.Type    = 'value';
    sProcess.options.thdelay.Value   = {0.05, '', 5};
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
    % Initialize SPM
    bst_spm_init(0);
    
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
    if ~isempty(strfind(pwd, workDir))
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
    % Initialize file counter
    fileCounter = ones(1, max([sInputsB.iStudy]));
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

        % Convert channel positions to MRI coordinates (for surface export, keep everything in SCS)
        if strcmpi(OPTIONS.OutputType, 'volume')
            Tscs2mri = inv([sMri.SCS.R, sMri.SCS.T./1000; 0 0 0 1]);
            % Get the MRI=>RAS transformation
            if isfield(sMri, 'InitTransf') && ~isempty(sMri.InitTransf)
                iTransf = find(strcmpi(sMri.InitTransf(:,1), 'vox2ras'));
            else
                iTransf = [];
            end
            % If there is a transformation MRI=>RAS from a .nii file 
            if ~isempty(iTransf)
                vox2ras = sMri.InitTransf{iTransf,2};
                % 2nd operation: Change reference from (0,0,0) to (.5,.5,.5)
                vox2ras = vox2ras * [1 0 0 -.5; 0 1 0 -.5; 0 0 1 -.5; 0 0 0 1];
                % 1st operation: Convert from MRI(mm) to voxels
                vox2ras = vox2ras * diag(1 ./ [sMri.Voxsize, 1]);
                % Convert millimeters=>meters
                vox2ras(1:3,4) = vox2ras(1:3,4) ./ 1000;
                % Add this transformation
                Tscs2mri = vox2ras * Tscs2mri;
            end
            ChannelMat = channel_apply_transf(ChannelMat, Tscs2mri, iChan, 1);
            ChannelMat = ChannelMat{1};
        else
            Tscs2mri = [];
        end
        % File tag
        [fPath,fBase] = bst_fileparts(sInputsB(iInput).FileName);
        [fPath, fileTag] = bst_fileparts(fPath);
        fileTag = strrep(fileTag, '_bipolar_1', '');
        fileTag = strrep(fileTag, '_bipolar_2', '');
        % If this file is not the only one in this folder: Add a file number
        iStudyFile = sInputsB(iInput).iStudy;
        if (nnz(iStudyFile == [sInputsB.iStudy]) > 1)
            fileTag = [fileTag '-' num2str(fileCounter(iStudyFile))];
            fileCounter(iStudyFile) = fileCounter(iStudyFile) + 1;
        end
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
    % Compute SPM canonical surfaces if necessary
    if isempty(sSubject.iCortex)
        isOk = process_generate_canonical('Compute', iSubject, [], 4, 0);
        if ~isOk
            bst_report('Error', sProcess, sInputsB, 'Could not compute SPM canonical surfaces...');
            return;
        end
        sSubject = bst_get('Subject', SubjectName);
    end
    % Load cortex mesh
    MeshFile = bst_fullfile(workDir, 'cortex.gii');
    MeshMat = in_tess_bst(sSubject.Surface(sSubject.iCortex).FileName);
    % Apply same transformation as the sensors
    if ~isempty(Tscs2mri)
        MeshMat.Vertices = bst_bsxfun(@plus, Tscs2mri(1:3,1:3)*MeshMat.Vertices', Tscs2mri(1:3,4))';
        MeshMat.Faces    = MeshMat.Faces(:,[2 1 3]);
    end
    % Export cortex mesh
    out_tess_gii(MeshMat, MeshFile, 0);
    OPTIONS.MeshFile = MeshFile;
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
            % History output
            strHistoryOutput = [...
                '- Atlas : ' OPTIONS.Atlas, 10, ...
                '- CorticalMesh : ' num2str(OPTIONS.CorticalMesh), 10, ...
                '- sMRI : ' OPTIONS.sMRI, 10];
        case 'surface'
            % Additional options
            OPTIONS.SmoothIterations = 5;
            % Output format: GII surface
            fileFormat = 'GII';
            fileExt = '.gii';
            % History output
            strHistoryOutput = ['- SmoothIterations : ', num2str(OPTIONS.SmoothIterations), 10];
    end

    % ===== CALL EPILEPTOGENICITY SCRIPT =====
    % Run script
    ImaGIN_Epileptogenicity(OPTIONS);
    % Restore initial directory
    cd(curDir);
    % Close all SPM figures
    close([spm_figure('FindWin','Menu'), spm_figure('FindWin','Graphics'), spm_figure('FindWin','Interactive')]);
    
    % ===== OUTPUT FOLDER =====
    % Get new folder "Epileptogenicity"
    ProtocolInfo = bst_get('ProtocolInfo');
    EpiFolder = file_unique(bst_fullfile(ProtocolInfo.STUDIES, SubjectName, ['Epileptogenicity_' OPTIONS.OutputType]));
    [tmp, Condition] = bst_fileparts(EpiFolder);
    % Create new folder
    iStudy = db_add_condition(SubjectName, Condition, 1);
    % Copy channel file from first file
    db_set_channel(iStudy, sInputsB(1).ChannelFile, 1, 0);

    % ===== FILE HISTORY =====
    % Common options
    strHistory = [...
        'ImaGIN_Epileptogenicity:', 10 ...
        '- FreqBand : ' sprintf('%d - %d Hz', round(OPTIONS.FreqBand)), 10 ...
        '- Latency : ' sprintf('%1.2f ', OPTIONS.Latency), 's', 10 ...
        '- HorizonT : ' num2str(OPTIONS.HorizonT), ' s    (time constant)', 10 ...
        '- TimeResolution : ' num2str(OPTIONS.TimeResolution), ' s', 10 ...
        '- ThDelay : ' num2str(OPTIONS.ThDelay), '    (propagation threshold, p or T)',  10 ...
        '- OutputType : ' OPTIONS.OutputType, 10 ...
        '- AR : ' num2str(OPTIONS.AR), 10 ...
        '- FileName : ' OPTIONS.FileName, 10, ...
        '- MeshFile : ' OPTIONS.MeshFile, 10, ...
        strHistoryOutput];
    % List of input files
    for i = 1:length(OnsetFiles)
        strHistory = [strHistory, '- D (seizures) : ', OnsetFiles{i}, 10];
    end
    for i = 1:length(BaselineFiles)
        strHistory = [strHistory, '- B (baseline) : ', BaselineFiles{i}, 10];
    end
    
    % ===== READ EPILEPTOGENICITY MAPS =====
    % List all the epileptogenicity maps in output
    listSpmDir = dir(bst_fullfile(workDir, 'SPM_*'));
    spmFiles = {};
    for i = 1:length(listSpmDir)
        tFile = bst_fullfile(workDir, listSpmDir(i).name, ['spmT_0001', fileExt]);
        if file_exist(tFile)
            spmFiles{end+1} = tFile;
        end
    end
    strGoup = cell(1,length(spmFiles));
    fileLatency = zeros(1,length(spmFiles));
    % Get the list of groups (one group = all the latencies for a file or group)
    for i = 1:length(spmFiles)
        [tmp, strGoup{i}] = bst_fileparts(bst_fileparts(spmFiles{i}));
        iLastSep = find(strGoup{i} == '_', 1, 'last');
        fileLatency(i) = str2num(strGoup{i}(iLastSep+1:end));
        strGoup{i} = strGoup{i}(1:iLastSep-1);
    end
    strGoupUnique = unique(strGoup);
    % Import all the stat files, group by group
    for iGroup = 1:length(strGoupUnique)
        % Get file indices
        iFiles = find(strcmpi(strGoup, strGoupUnique{iGroup}));
        % Sort based on latency
        [tmp,I] = sort(fileLatency(iFiles));
        iFiles = iFiles(I);
        % File comment = SPM folder
        Comment = strrep(strGoupUnique{iGroup}, 'SPM_', '');
        % Import file
        tmpFile = import_sources(iStudy, [], spmFiles(iFiles), [], fileFormat, Comment, 't', fileLatency(iFiles));
        OutputFiles = cat(2, OutputFiles, tmpFile);
        % Remove negative values in the maps
        tmpMat = load(tmpFile);
        tmpMat.tmap(tmpMat.tmap < 0) = 0;
        tmpMat = bst_history('add', tmpMat, 'epilepto', strHistory);
        bst_save(tmpFile, tmpMat, 'v6');
    end
    
    % ===== READ DELAY MAPS =====
    % List all the epileptogenicity maps in output
    listFiles = dir(bst_fullfile(workDir, ['Delay_*', fileExt]));
    % Import all the stat files
    for i = 1:length(listFiles)
        % File comment = File name
        [tmp, Comment] = bst_fileparts(listFiles(i).name);
        % Import file
        tmpFile = import_sources(iStudy, [], bst_fullfile(workDir, listFiles(i).name), [], fileFormat, Comment, 's');
        % Add history field
        tmpFile = bst_history('add', tmpFile, 'epilepto', strHistory);
    end
    
    % ===== READ CONTACT VALUES =====
    % List all the epileptogenicity index files in output
    listFiles = dir(bst_fullfile(workDir, 'EI_*.txt'));
    strGoup = cell(1,length(listFiles));
    fileLatency = zeros(1,length(listFiles));
    % Get the list of groups (one group = all the latencies for a file or group)
    for i = 1:length(listFiles)
        [tmp, strGoup{i}] = bst_fileparts(listFiles(i).name);
        iLastSep = find(strGoup{i} == '_', 1, 'last');
        fileLatency(i) = str2num(strGoup{i}(iLastSep+1:end));
        strGoup{i} = strGoup{i}(1:iLastSep-1);
    end
    strGoupUnique = unique(strGoup);
    % Get channel file
    sStudy = bst_get('Study', iStudy);
    ChannelMat = in_bst_channel(sStudy.Channel(1).FileName);
    % Prepare options structure
    ImportOptions = db_template('ImportOptions');
    ImportOptions.DisplayMessages = 0;
    ImportOptions.ChannelReplace  = 0;
    ImportOptions.ChannelAlign    = 0;
    % Prepare ASCII import options
    ImportEegRawOptions = bst_get('ImportEegRawOptions');
    ImportEegRawOptions.BaselineDuration  = 0;
    ImportEegRawOptions.SamplingRate      = 1000;
    ImportEegRawOptions.MatrixOrientation = 'channelXtime';
    ImportEegRawOptions.VoltageUnits      = 'None';
    ImportEegRawOptions.SkipLines         = 2;
    ImportEegRawOptions.nAvg              = 1;
    ImportEegRawOptions.isChannelName     = 1;
    bst_set('ImportEegRawOptions', ImportEegRawOptions);
    % Import all the txt files, group by group
    for iGroup = 1:length(strGoupUnique)
        % Get file indices
        iFiles = find(strcmpi(strGoup, strGoupUnique{iGroup}));
        % Sort based on latency
        [tmp,I] = sort(fileLatency(iFiles));
        iFiles = iFiles(I);
        % Full file names, sorted by latency
        groupFiles = cellfun(@(c)bst_fullfile(workDir, c), {listFiles(iFiles).name}, 'UniformOutput', 0);
        % Import files
        DataMat = [];
        for i = 1:length(groupFiles)
            % Import and load file
            ImportedDataMat = in_data(groupFiles{i}, ChannelMat, 'EEG-ASCII', ImportOptions);
            fileMat = load(ImportedDataMat.FileName);
            % Concatenate with previous files
            if isempty(DataMat)
                DataMat = fileMat;
            else
                DataMat.F = [DataMat.F, fileMat.F];
            end
        end
        % Final time vector
        DataMat.Time         = fileLatency(iFiles);
        DataMat.Comment      = strGoupUnique{iGroup};
        DataMat.DataType     = 'ei';
        DataMat.DisplayUnits = 't';
        % Add history field
        DataMat = bst_history('add', DataMat, 'epilepto', strHistory);
        % Save file
        OutputFile = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), ['data_', strGoupUnique{iGroup}]);
        bst_save(OutputFile, DataMat, 'v7');
        db_add_data(iStudy, OutputFile, DataMat);
        panel_protocols('UpdateNode', 'Study', iStudy);
    end
end

    



