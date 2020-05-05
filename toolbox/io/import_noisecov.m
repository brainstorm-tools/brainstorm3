function Output = import_noisecov(iStudies, NoiseCovMat, ReplaceFile, isDataCov)
% IMPORT_NOISECOV: Imports a noise covariance file.
% 
% USAGE:  
%         BstNoisecovFile = import_noisecov(iStudies, NoiseCovFile=[ask], ReplaceFile=0, isDataCov=0) : Read file and save it in brainstorm database
%         BstNoisecovFile = import_noisecov(iStudies, NoiseCovMat)        : Save a NoiseCov file structure in brainstorm database
%         BstNoisecovFile = import_noisecov(iStudies, 'Identity')         : Use an identity matrix for the target studies
%             NoiseCovMat = import_noisecov([],       NoiseCovFile)       : Just read the file
%             NoiseCovMat = import_noisecov()                             : Ask file to the user, and read it
%
% INPUT:
%    - iStudies     : Indices of the studies where to import the NoiseCovFile
%    - NoiseCovFile : Full filename of the noise covariance matrix to import (format is autodetected)
%                     => if not specified : file to import is asked to the user
%    - ReplaceFile  : {[],0,1,2}
%                     0, do not replace existing files
%                     1, replace existing files
%                     2, merge with existing files
%                     Empty: Ask what to do
%    - isDataCov    : If 1, saves the result as the data covariance, if 0 saves it as the noise covariance

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
% Authors: Francois Tadel, 2009-2016


%% ===== PARSE INPUTS =====
if (nargin < 4) || isempty(isDataCov)
    isDataCov = 0;
end
if (nargin < 3) || isempty(ReplaceFile)
    ReplaceFile = [];
end
% Argument: NoiseCovMat
if (nargin < 2) || isempty(NoiseCovMat)
    NoiseCovMat = [];
    NoiseCovFile = '';
elseif isequal(NoiseCovMat, 'Identity')
    NoiseCovFile = 'Identity';
    NoiseCovMat  = 'Identity';
elseif ischar(NoiseCovMat)
    NoiseCovFile = NoiseCovMat;
    NoiseCovMat = [];
elseif isstruct(NoiseCovMat)
    NoiseCovFile = '';
end
% Argument: iStudies
if (nargin < 1)
    iStudies = [];
end
% Initialize output structure
Output = [];

% Detect file format
FileFormat = '';
if ~isempty(NoiseCovFile)
    % Get the file extenstion
    [fPath, fBase, fExt] = bst_fileparts(NoiseCovFile);
    if ~isempty(fExt)
        fExt = lower(fExt(2:end));
        % Detect file format by extension
        switch lower(fExt)
            case 'fif', FileFormat = 'FIF';
            case 'mat', FileFormat = 'BST';
            otherwise,  FileFormat = 'ASCII';
        end
        % Display assumed file format
        disp(['Default file format for this extension: ' FileFormat]);
        disp('If you want to specify the extension, please run this function without arguments.');
    end
end
% Default file tag
if isDataCov
    fileTag = 'ndatacov';
    strComment = 'Data covariance';
else
    fileTag = 'noisecov';
    strComment = 'Noise covariance';
end

%% ===== SELECT NOISECOV FILE =====
% If file to load was not defined : open a dialog box to select it
if isempty(NoiseCovFile) && isempty(NoiseCovMat)
    % Get default import directory and formats
    LastUsedDirs = bst_get('LastUsedDirs');
    DefaultFormats = bst_get('DefaultFormats');
    % Get NoiseCov file
    [NoiseCovFile, FileFormat] = java_getfile('open', ...
            'Import noise covariance...', ...         % Window title
            LastUsedDirs.ImportChannel, ...   % Last used directory
            'single', 'files', ...   % Selection mode
            {{'.fif'},      'Elekta-Neuromag (*.fif)',      'FIF'; ...
             {'_noisecov', '_ndatacov'}, ['Brainstorm (noisecov_*.mat; ndatacov_*.mat)'], 'BST'; ...
             {'*'},         'ASCII (*.*)',                'ASCII' ...
            }, DefaultFormats.NoiseCovIn);
    % If no file was selected: exit
    if isempty(NoiseCovFile)
        return
    end
    % Save default import directory
    LastUsedDirs.ImportChannel = bst_fileparts(NoiseCovFile);
    bst_set('LastUsedDirs', LastUsedDirs);
    % Save default import format
    DefaultFormats.NoiseCovIn = FileFormat;
    bst_set('DefaultFormats',  DefaultFormats);
end


%% ===== LOAD NOISECOV FILE =====
sensorsNames = [];
isProgressBar = bst_progress('isVisible');
if isempty(NoiseCovMat)
    % Progress bar
    if ~isProgressBar
        bst_progress('start', 'Import noise covariance file', ['Loading file "' NoiseCovFile '"...']);
    end
    % Get the file extenstion
    [fPath, fBase, fExt] = bst_fileparts(NoiseCovFile);
    if ~isempty(fExt)
        fExt = lower(fExt(2:end));
    end
    % Load file
    switch FileFormat
        case 'FIF'
            [NoiseCovMat.NoiseCov, sensorsNames] = in_noisecov_fif(NoiseCovFile);
            NoiseCovMat.Comment = [strComment ' (FIF)'];
            % Check that something was read
            if isempty(NoiseCovMat.NoiseCov)
                error([strComment ' matrix was not found in this FIF file.']);
            end
        case 'BST'
            NoiseCovMat = load(NoiseCovFile);     
            NoiseCovMat.Comment = strComment;
        case 'ASCII'  % (*.*)
            NoiseCovMat.NoiseCov = load(NoiseCovFile, '-ascii');
            NoiseCovMat.Comment = [strComment ' (ASCII)'];
    end
    % No data imported
    if isempty(NoiseCovMat) || isempty(NoiseCovMat.NoiseCov)
        bst_progress('stop');
        return
    end
    % History: File name
    NoiseCovMat = bst_history('add', NoiseCovMat, 'import', ['Import from: ' NoiseCovFile ' (Format: ' FileFormat ')']);
            
    % Get imported base name
    [tmp__, importedBaseName, importedExt] = bst_fileparts(NoiseCovFile);
    importedBaseName = strrep(importedBaseName, [fileTag '_'], '');
    importedBaseName = strrep(importedBaseName, ['_' fileTag], '');
    importedBaseName = strrep(importedBaseName, fileTag, '');
    % Limit number of chars
    if (length(importedBaseName) > 15)
        importedBaseName = importedBaseName(1:15);
    end
else
    importedBaseName = 'full';
    if ~isequal(NoiseCovFile, 'Identity')
        NoiseCovMat.Comment = strComment;
    end
end


%% ===== APPLY NEW NOISECOV FILE =====
if ~isempty(iStudies)
    % Get Protocol information
    ProtocolInfo = bst_get('ProtocolInfo');
    BstNoisecovFile = [];
    % Add noisecov file to all the target studies
    for i = 1:length(iStudies)
        % Get study
        iStudy = iStudies(i);
        sStudy = bst_get('Study', iStudy);
        studySubDir = bst_fileparts(sStudy.FileName);
        % Load ChannelFile
        ChannelMat = in_bst_channel(sStudy.Channel(1).FileName, 'Channel');

        % Use identity matrix
        if isequal(NoiseCovFile, 'Identity')
            % Create a new noise covariance
            NoiseCovMat = db_template('noisecovmat');
            NoiseCovMat.Comment = 'No noise modeling';
            NoiseDiag = ones(1, length(ChannelMat.Channel));
            % Get MEG/EEG sensors to set different default values
            iEeg = channel_find(ChannelMat.Channel, {'EEG','SEEG','ECOG'});
            iMeg = channel_find(ChannelMat.Channel, {'MEG', 'MEG REF'});
            NoiseDiag(iEeg) = 1e-10;   % Corresponds to a baseline value of 10 microV
            NoiseDiag(iMeg) = 1e-26;   % Corresponds to a baseline value of 100 femtoT
            % Create an identity matrix [nChannels x nChannels]
            NoiseCovMat.NoiseCov = diag(NoiseDiag);
        % If there is a Channel file defined, and we know the names of the noisecov rows
        elseif ~isempty(sStudy.Channel) && ~isempty(sensorsNames)
            % For each row of the noisecov matrix
            iRowChan = [];
            iRowCov  = [];
            for iRow = 1:length(sensorsNames)
                % Look for sensor name in channels list
                ind = find(strcmpi(sensorsNames{iRow}, {ChannelMat.Channel.Name}));
                % If channel was found, reference it in both arrays
                if ~isempty(ind)
                    iRowCov(end+1)  = iRow;
                    iRowChan(end+1) = ind;
                end
            end
            % Check that this noisecov file corresponds to the Channel file
            if isempty(iRowCov)
                error('This noise covariance file does not correspond to the channel file.');
            end
            % Fill a NoiseCov matrix corresponding to channel file
            fullNoiseCov = zeros(length(ChannelMat.Channel));
            fullNoiseCov(iRowChan,iRowChan) = NoiseCovMat.NoiseCov(iRowCov,iRowCov);
            % Replace noise covariance read from file
            NoiseCovMat.NoiseCov = fullNoiseCov;
        else
            % Check the number of sensors
            if ~isempty(sStudy.Channel) && (size(NoiseCovMat.NoiseCov,1) ~= length(ChannelMat.Channel))
                error('This noise covariance file does not correspond to the channel file.');
            end
        end
        
        % ===== DELETE PREVIOUS NOISECOV FILES =====
        % Delete all the other noisecov files in the study directory
        noisecovFiles = dir(bst_fullfile(ProtocolInfo.STUDIES, studySubDir, [fileTag '_*.mat']));
        if ~isempty(noisecovFiles)
            % If no auto-confirmation
            if isempty(ReplaceFile)
                % Ask user confirmation
                res = java_dialog('question', ['Warning: a noise covariance is already defined for this study:' 10 ...
                      bst_fullfile(studySubDir, noisecovFiles(1).name) 10 10], 'Replace noise covariance file', [], {'Replace', 'Merge', 'Cancel'}, 'Replace');
                % If user did not accept : go to next study
                if isempty(res) || strcmpi(res, 'Cancel')
                    continue;
                end
                % Replace or merge
                if strcmpi(res, 'Replace')
                    ReplaceFile = 1;
                elseif strcmpi(res, 'Merge')
                    ReplaceFile = 2;
                end
            end
            % Get full path to previous noisecov files
            noisecovFilesFull = cellfun(@(f)bst_fullfile(ProtocolInfo.STUDIES, studySubDir, f), {noisecovFiles.name}, 'UniformOutput', 0);
            % What to do with existing file
            switch (ReplaceFile)
                case 0  % KEEP
                    % Nothing to do
                    continue;
                case 1  % REPLACE
                    % Delete previous noisecov file
                    file_delete(noisecovFilesFull, 1);
                case 2  % MERGE
                    % Load existing file: use it as the base
                    PrevMat = load(noisecovFilesFull{1});
                    % Identify the channels with data
                    iChanOld = find(any(PrevMat.NoiseCov,1));
                    iChanNew = find(any(NoiseCovMat.NoiseCov,1));
                    % Add new non-zero channels to existing matrix
                    newNoiseCov = NoiseCovMat.NoiseCov;
                    NoiseCovMat.NoiseCov = PrevMat.NoiseCov;
                    NoiseCovMat.NoiseCov(iChanNew,iChanNew) = newNoiseCov(iChanNew,iChanNew);
                    % Do the same with the other fields
                    if isfield(NoiseCovMat, 'FourthMoment') && ~isempty(NoiseCovMat.FourthMoment) && isfield(PrevMat, 'FourthMoment') && ~isempty(PrevMat.FourthMoment)
                        newFourthMoment = NoiseCovMat.FourthMoment;
                        NoiseCovMat.FourthMoment = PrevMat.FourthMoment;
                        NoiseCovMat.FourthMoment(iChanNew,iChanNew) = newFourthMoment(iChanNew,iChanNew);
                    end
                    if isfield(NoiseCovMat, 'nSamples') && ~isempty(NoiseCovMat.nSamples) && isfield(PrevMat, 'nSamples') && ~isempty(PrevMat.nSamples)
                        newNSamples = NoiseCovMat.nSamples;
                        NoiseCovMat.nSamples = PrevMat.nSamples;
                        NoiseCovMat.nSamples(iChanNew,iChanNew) = newNSamples(iChanNew,iChanNew);
                    end
                    % Comment: Remove everything after ":"
                    iColon = find(NoiseCovMat.Comment == ':');
                    if ~isempty(iColon)
                        NoiseCovMat.Comment = [NoiseCovMat.Comment(1:iColon), ' '];
                    else
                        NoiseCovMat.Comment = [NoiseCovMat.Comment,' '];
                    end
                    % Comment: Add sensor types
                    allTypes = unique({ChannelMat.Channel(union(iChanOld,iChanNew)).Type});
                    if all(ismember({'MEG MAG', 'MEG GRAD'}, allTypes))
                        allTypes = setdiff(allTypes, {'MEG MAG', 'MEG GRAD'});
                        allTypes = union(allTypes, {'MEG'});
                    end
                    for iType = 1:length(allTypes)
                        NoiseCovMat.Comment = [NoiseCovMat.Comment, allTypes{iType}];
                        if (iType < length(allTypes))
                            NoiseCovMat.Comment = [NoiseCovMat.Comment, ', '];
                        end
                    end
                    % Display message
                    disp(sprintf('BST> Merged noise covariance: %d channels set (%d were already defined).', length(iChanNew), length(intersect(iChanNew, iChanOld))));
                otherwise
                    error('Invalid value for parameter ReplaceFile.');
            end
        end

        % ===== SAVE NOISECOV FILE =====
        % Produce a default noisecov filename
        BstNoisecovFile = bst_fullfile(ProtocolInfo.STUDIES, studySubDir, [fileTag '_' importedBaseName '.mat']);
        % Save new NoiseCovFile in Brainstorm format
        bst_save(BstNoisecovFile, NoiseCovMat, 'v7');

        % ===== STORE NEW NOISECOV IN DATABASE ======
        % New noisecov structure
        newNoiseCov = db_template('NoiseCov');
        newNoiseCov(1).FileName = file_short(BstNoisecovFile);
        newNoiseCov.Comment     = NoiseCovMat.Comment;

        % Add noisecov to study
        if isempty(sStudy.NoiseCov) && ~isstruct(sStudy.NoiseCov)
            sStudy.NoiseCov = repmat(newNoiseCov, 0);
        end
        if isDataCov
            sStudy.NoiseCov(2) = newNoiseCov;
        else
            sStudy.NoiseCov(1) = newNoiseCov;
        end
        % Update database
        bst_set('Study', iStudy, sStudy);  
    end

    % Update tree
    panel_protocols('UpdateNode', 'Study', iStudies);
    % Save database
    db_save();
    % Returned value
    Output = BstNoisecovFile;
else
    Output = NoiseCovMat;
end

% Progress bar
if ~isProgressBar
    bst_progress('stop');
end


