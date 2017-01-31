function varargout = process_import_bids( varargin )
% PROCESS_IMPORT_BIDS: Import a dataset organized following the BIDS specficiations (http://bids.neuroimaging.io/)
%
% USAGE:           OutputFiles = process_import_bids('Run', sProcess, sInputs)
%         [RawFiles, Messages] = process_import_bids('ImportBidsDataset', BidsDir=[ask], nVertices=[ask], isInteractive=1)

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2016 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Import BIDS dataset';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Import anatomy';
    sProcess.Index       = 4;
    sProcess.Description = 'http://neuroimage.usc.edu/brainstorm/Tutorials/RestingOmega';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import'};
    sProcess.OutputTypes = {'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;
    sProcess.isSeparator = 1;
    % File selection options
    SelectOptions = {...
        '', ...                            % Filename
        '', ...                            % FileFormat
        'open', ...                        % Dialog type: {open,save}
        'Import BIDS dataset folder...', ...     % Window title
        'ImportAnat', ...                  % LastUsedDir: {ImportData,ImportChannel,ImportAnat,ExportChannel,ExportData,ExportAnat,ExportProtocol,ExportImage,ExportScript}
        'single', ...                      % Selection mode: {single,multiple}
        'dirs', ...                        % Selection mode: {files,dirs,files_and_dirs}
        {{'.folder'}, 'BIDS dataset folder', 'BIDS'}, ... % Available file formats
        []};                               % DefaultFormats: {ChannelIn,DataIn,DipolesIn,EventsIn,AnatIn,MriIn,NoiseCovIn,ResultsIn,SspIn,SurfaceIn,TimefreqIn}
    % Option: MRI file
    sProcess.options.bidsdir.Comment = 'Folder to import:';
    sProcess.options.bidsdir.Type    = 'filename';
    sProcess.options.bidsdir.Value   = SelectOptions;
    % Option: Number of vertices
    sProcess.options.nvertices.Comment = 'Number of vertices (cortex): ';
    sProcess.options.nvertices.Type    = 'value';
    sProcess.options.nvertices.Value   = {15000, '', 0};
    % Align sensors
    sProcess.options.channelalign.Comment = 'Align sensors using headpoints';
    sProcess.options.channelalign.Type    = 'checkbox';
    sProcess.options.channelalign.Value   = 1;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    % === GET OPTIONS ===
    % Get folder to import
    BidsDir = sProcess.options.bidsdir.Value{1};
    if isempty(BidsDir) || ~file_exist(bst_fullfile(BidsDir, 'dataset_description.json'))
        bst_report('Error', sProcess, [], 'Invalid BIDS dataset: missing file "dataset_description.json"');
        return
    end
    % Number of vertices
    nVertices = sProcess.options.nvertices.Value{1};
    if isempty(nVertices) || (nVertices < 50)
        bst_report('Error', sProcess, [], 'Invalid number of vertices.');
        return
    end
    % Channels align
    ChannelAlign = 2 * double(sProcess.options.channelalign.Value);
    
    % === IMPORT DATASET ===
    % Import dataset
    [OutputFiles, Messages] = ImportBidsDataset(BidsDir, nVertices, 0, ChannelAlign);
    % Handling errors
    if ~isempty(Messages)
        if isempty(OutputFiles)
            bst_report('Error', sProcess, [], Messages);
        else
            bst_report('Warning', sProcess, [], Messages);
        end
    end
end


%% ===== IMPORT BIDS DATABASE =====
% USAGE:  [RawFiles, Messages] = process_import_bids('ImportBidsDataset', BidsDir=[ask], nVertices=[ask], isInteractive=1, ChannelAlign=2)
function [RawFiles, Messages] = ImportBidsDataset(BidsDir, nVertices, isInteractive, ChannelAlign)
    % Initialize returned values
    RawFiles = {};
    Messages = [];
    
    % ===== PARSE INPUTS =====
    if (nargin < 4) || isempty(ChannelAlign)
        ChannelAlign = 2;
    end
    if (nargin < 3) || isempty(isInteractive)
        isInteractive = 1;
    end
    if (nargin < 2) || isempty(nVertices)
        nVertices = [];
    end
    if (nargin < 3) || isempty(BidsDir)
        BidsDir = [];
    end

    % ===== GET THE BIDS FOLDER =====
    % Ask the folder to the user
    if isempty(BidsDir)
        % Get default directories
        LastUsedDirs = bst_get('LastUsedDirs');
        % Pick a folder
        BidsDir = java_getfile('open', 'Import BIDS dataset folder...', LastUsedDirs.ImportAnat, 'single', 'dirs', {{'.folder'}, 'BIDS dataset folder', 'BIDS'}, 'BIDS');
        % If nothing selected
        if isempty(BidsDir)
            return;
        end
        % Save new default path
        LastUsedDirs.ImportAnat = bst_fileparts(BidsDir);
        bst_set('LastUsedDirs', LastUsedDirs);
    end
    % Check the structure of the dataset
    if ~file_exist(bst_fullfile(BidsDir, 'dataset_description.json'))
        Messages = 'Invalid BIDS dataset: missing file "dataset_description.json"';
        if isInteractive
            bst_error(Messages, 'Import BIDS dataset', 0);
        end
        return;
    end
    
    % ===== IDENTIFY SUBJECTS =====
    % List all the subject folders
    subjDir = dir(bst_fullfile(BidsDir, 'sub-*'));
    % Loop on the subjects
    SubjectNames   = {};
    SubjectDirs    = {};
    SubjectAnatRef = {};
    for iSubj = 1:length(subjDir)
        % Default subject name
        subName = subjDir(iSubj).name;
        % Checks if there are multiple sessions
        sessDir = dir(bst_fullfile(BidsDir, subName, 'ses-*'));
        % If there are multiple sessions: each session is imported as a separate subject
        if ~isempty(sessDir)
            for iSess = 1:length(sessDir)
                SubjectNames{end+1} = [subName, '_', sessDir(iSess).name];
                SubjectDirs{end+1}  = bst_fullfile(BidsDir, subName, sessDir(iSess).name);
                % For follow-up sessions, keep the reference to the session
                if (iSess >= 2)
                    SubjectAnatRef{end+1} = length(SubjectNames) - iSess + 1;
                else
                    SubjectAnatRef{end+1} = [];
                end
            end
        else
            SubjectNames{end+1}   = subName;
            SubjectDirs{end+1}    = bst_fullfile(BidsDir, subName);
            SubjectAnatRef{end+1} = [];
        end
    end
    
    % ===== FIND SUBJECT ANATOMY =====
    % Check if segmented anatomy or an MRI is available for each subject
    isSetFiducials    = zeros(1,length(SubjectNames));
    isSegmentation    = zeros(1,length(SubjectNames));
    SubjectAnatDirs   = cell(1,length(SubjectNames));
    SubjectAnatFormat = cell(1,length(SubjectNames));
    for iSubj = 1:length(SubjectNames)
        % For later sessions: get the index of the subject
        iSubjRef = SubjectAnatRef{iSubj};

        % FreeSurfer
        if file_exist(bst_fullfile(BidsDir, 'derivatives', 'freesurfer', SubjectNames{iSubj}))
            SubjectAnatDirs{iSubj}   = bst_fullfile(BidsDir, 'derivatives', 'freesurfer', SubjectNames{iSubj});
            SubjectAnatFormat{iSubj} = 'FreeSurfer';
        % BrainSuite
        elseif file_exist(bst_fullfile(BidsDir, 'derivatives', 'brainsuite', SubjectNames{iSubj}))
            SubjectAnatDirs{iSubj}   = bst_fullfile(BidsDir, 'derivatives', 'brainsuite', SubjectNames{iSubj});
            SubjectAnatFormat{iSubj} = 'BrainSuite';
        % BrainVISA
        elseif file_exist(bst_fullfile(BidsDir, 'derivatives', 'brainvisa', SubjectNames{iSubj}))
            SubjectAnatDirs{iSubj}   = bst_fullfile(BidsDir, 'derivatives', 'brainvisa', SubjectNames{iSubj});
            SubjectAnatFormat{iSubj} = 'BrainVISA';
        % CIVET
        elseif file_exist(bst_fullfile(BidsDir, 'derivatives', 'civet', SubjectNames{iSubj}))
            SubjectAnatDirs{iSubj}   = bst_fullfile(BidsDir, 'derivatives', 'civet', SubjectNames{iSubj});
            SubjectAnatFormat{iSubj} = 'CIVET';
        end
        
        % If a segmentation is available: check if there is a fiducials.m file available
        if ~isempty(SubjectAnatDirs{iSubj})
             % If fiducials are not defined: need to define them
            isSetFiducials(iSubj) = isempty(file_find(SubjectAnatDirs{iSubj}, 'fiducials.m', [], 0));
            isSegmentation(iSubj) = 1;
        % Else: Try to get an anatomical MRI
        else
            % Find .nii or .nii.gz in the anat folder
            AnatDir = bst_fullfile(SubjectDirs{iSubj}, 'anat');
            mriDir = dir(bst_fullfile(AnatDir, '*T1w.nii*'));
            if ~isempty(mriDir)
                SubjectAnatDirs{iSubj}   = bst_fullfile(AnatDir, mriDir(1).name);
                SubjectAnatFormat{iSubj} = 'Nifti1';
                isSegmentation(iSubj)    = 0;
                isSetFiducials(iSubj)    = 1;
            end
        end
        
        % For follow-up sessions, get the anatomy from the first session
        if isempty(SubjectAnatDirs{iSubj}) && ~isempty(iSubjRef) && ~isempty(SubjectAnatDirs{iSubjRef})
            SubjectAnatDirs{iSubj}   = SubjectAnatDirs{iSubjRef};
            SubjectAnatFormat{iSubj} = SubjectAnatFormat{iSubjRef};
            isSegmentation(iSubj)    = isSegmentation(iSubjRef);
            isSetFiducials(iSubj)    = isSetFiducials(iSubjRef);
        end
    end
    
    % Perform some checks
    % Cannot set the fiducials when calling from a process (non-interactive)
    if ~isInteractive && any(isSetFiducials)
        Messages = ['You need to set the fiducials interactively before running this process.' 10 ...
                    'Use the menu "File > Batch MRI fiducials" for creating fiducials.m files in the segmentation folders.' 10 ...
                    'Alternatively, run this import interactively with the menu "File > Load protocol > Import BIDS dataset"'];
        return;
    % Ask the user whether to set all the fiducials at once
    elseif isInteractive && any(isSetFiducials & isSegmentation)
        res = java_dialog('question', ...
            ['You need to set the anatomy fiducials interactively for each subject.' 10 10 ...
             'There are two ways for doing this, depending if you have write access to the dataset:' 10 ...
             '1) Batch: Set the fiducials for all the segmentation folders at once, save them in fiducials.m files, ' 10 ...
             '   and then import everything. With this option, you won''t have to wait until each subject is ' 10 ...
             '   fully processed before setting the fiducials for the next one, and the points you define will' 10 ...
             '   be permanently saved in the dataset. But you need write access to the input folder.' 10 ...
             '   This is equivalent to running the menu "File > Batch MRI fiducials" first.' 10 ...
             '2) Sequencial: For each segmentation folder, set the fiducials then import it. Longer but more flexible.' 10 10], ...
            'Import BIDS dataset', [], {'Batch', 'Sequential', 'Cancel'}, 'Sequential');
        if isempty(res) || isequal(res, 'Cancel')
            return;
        end
        % Run the setting of the fiducials in a batch
        if strcmpi(res, 'Batch')
            % Find one subject that needs to be defined
            iSetSubj = find(isSetFiducials & isSegmentation);
            % Run it for the subjects in the same folder
            bst_batch_fiducials(bst_fileparts(SubjectAnatDirs{iSetSubj(1)}));
        end
    end
    
    % ===== IMPORT FILES =====
    for iSubj = 1:length(SubjectNames)
        
        % === GET/CREATE SUBJECT ===
        % Get subject 
        [sSubject, iSubject] = bst_get('Subject', SubjectNames{iSubj});
        % Create subject is it does not exist yet
        if isempty(sSubject)
            UseDefaultAnat = isempty(SubjectAnatDirs{iSubj});
            UseDefaultChannel = 0;
            [sSubject, iSubject] = db_add_subject(SubjectNames{iSubj}, [], UseDefaultAnat, UseDefaultChannel);
        end
        if isempty(iSubject)
            Messages = [Messages, 10, 'Cannot create subject "' SubjectNames{iSubj} '".'];
            if isInteractive
                bst_error(Messages, 'Import BIDS dataset', 0);
                return;
            else
                continue;
            end
        end
        
        % === IMPORT ANATOMY ===
        if isempty(sSubject.Anatomy) && ~isempty(SubjectAnatFormat{iSubj})
            % Ask for number of vertices (so it is not asked multiple times)
            if isempty(nVertices) && ismember(SubjectAnatFormat{iSubj}, {'FreeSurfer', 'BrainSuite', 'BrainVISA', 'Nifti1'})
                nVertices = java_dialog('input', 'Number of vertices on the cortex surface:', 'Import FreeSurfer folder', [], '15000');
                if isempty(nVertices)
                    return;
                end
                nVertices = str2double(nVertices);
            end
            % Import subject anatomy
            switch (SubjectAnatFormat{iSubj})
                case 'FreeSurfer'
                    errorMsg = import_anatomy_fs(iSubject, SubjectAnatDirs{iSubj}, nVertices, isInteractive, [], 0);
                case 'BrainSuite'
                    errorMsg = import_anatomy_bs(iSubject, SubjectAnatDirs{iSubj}, nVertices, isInteractive, []);
                case 'BrainVISA'
                    errorMsg = import_anatomy_bv(iSubject, SubjectAnatDirs{iSubj}, nVertices, isInteractive, []);
                case 'CIVET'
                    errorMsg = import_anatomy_civet(iSubject, SubjectAnatDirs{iSubj}, nVertices, isInteractive, [], 0);
                case 'Nifti1'
                    % Import MRI
                    BstMriFile = import_mri(iSubject, SubjectAnatDirs{iSubj}, SubjectAnatFormat{iSubj}, isInteractive);
                    if isempty(BstMriFile)
                        errorMsg = ['Could not load MRI file: ' SubjectAnatDirs{iSubj}];
                    % Compute additional files
                    else
                        % Generate head surface
                        tess_isohead(iSubject, 10000, 0, 2);
                    end
                otherwise
                    errorMsg = ['Invalid file format: ' SubjectAnatFormat{iSubj}];
            end
            % Error handling
            if ~isempty(errorMsg)
                Messages = [Messages, 10, errorMsg];
                if isInteractive
                    bst_error(Messages, 'Import BIDS dataset', 0);
                    return;
                else
                    continue;
                end
            end
        % If the anatomy is already set: issue a warning
        elseif ~isempty(SubjectAnatFormat{iSubj})
            msgAnatSet = ['Anatomy is already set for subject "' SubjectNames{iSubj} '", not overwriting...'];
            Messages = [Messages, 10, msgAnatSet];
            disp(['BST> ' msgAnatSet]);
        end
    
        % === IMPORT MEG FILES ===
        % Import options
        ImportOptions = db_template('ImportOptions');
        ImportOptions.ChannelReplace  = 1;
        ImportOptions.ChannelAlign    = 2 * ~sSubject.UseDefaultAnat;
        ImportOptions.DisplayMessages = isInteractive;
        ImportOptions.EventsMode      = 'ignore';
        ImportOptions.EventsTrackMode = 'value';
        % Get all the files in the meg folder
        megDir = dir(bst_fullfile(SubjectDirs{iSubj}, 'meg', '*.*'));
        % Try import them all, one by one
        for iFile = 1:length(megDir)
            % Skip hidden files
            if (megDir(iFile).name(1) == '.')
                continue;
            end
            % Get file extension
            [tmp, fBase, fExt] = bst_fileparts(megDir(iFile).name);
            megFile = bst_fullfile(SubjectDirs{iSubj}, 'meg', megDir(iFile).name);
            % Import depending on this extension
            switch (fExt)
                case '.ds'
                    RawFiles = [RawFiles{:}, import_raw(megFile, 'CTF', iSubject, ImportOptions)];
                case '.fif'
                    RawFiles = [RawFiles{:}, import_raw(megFile, 'FIF', iSubject, ImportOptions)];
                case {'.json', '.tsv'}
                    % Nothing to do
                otherwise
                    disp(['BST> Skipping unsupported file: ' megFile]);
            end
        end
    end
end


