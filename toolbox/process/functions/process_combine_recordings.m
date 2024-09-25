function varargout = process_combine_recordings(varargin)
% process_combine_recordings: Combine multiple synchronized signals into
% one recording (resampling the signals to the highest sampling frequency)

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
% Authors: Edouard Delaire, 2024
%          Raymundo Cassani, 2024

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription()
    % Description the process
    sProcess.Comment     = 'Combine files';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Synchronize';
    sProcess.Index       = 682;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = { 'raw'};
    sProcess.OutputTypes = { 'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 2;
    
    % Option: Condition
    sProcess.options.condition.Comment = 'Condition name:';
    sProcess.options.condition.Type    = 'text';
    sProcess.options.condition.Value   = '';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs)
    OutputFiles = {};

    % === Sync event management === %
    nInputs        = length(sInputs);
    fs             = zeros(1, nInputs);
    sOldTiming     = cell(1, nInputs);
    sIdxChAn       = cell(1, nInputs);

    bst_progress('start', 'Combining files', 'Loading data...', 0, 3*nInputs);

    % Get Time vector, events and sampling frequency for each file
    for iInput = 1:nInputs

        sDataRaw = in_bst_data(sInputs(iInput).FileName, 'Time', 'F');
        sOldTiming{iInput}.Time   = sDataRaw.Time;
        sOldTiming{iInput}.Events = sDataRaw.F.events;
        
        fs(iInput) = 1/(sOldTiming{iInput}.Time(2) -  sOldTiming{iInput}.Time(1)); % in Hz
    end

    bst_progress('inc', nInputs);
    bst_progress('text', 'Synchronizing...');

    % First Input is the one wiht highest sampling frequency
    [~, im] = max(fs);
    sInputs([1, im])    = sInputs([im, 1]);
    sOldTiming([1, im]) = sOldTiming([im, 1]);
    fs([1, im])         = fs([im, 1]);

    % Compute shifiting between file i and first file
    new_times     = sOldTiming{1}.Time;

    iNewStudy = db_add_condition(sInputs(iInput).SubjectName,  ['@raw' sProcess.options.condition.Value]);
    sNewStudy = bst_get('Study', iNewStudy);


    % Save channel definition
    bst_progress('text', 'Combining channels files...');

    NewChannelMat   = in_bst_channel(sInputs(1).ChannelFile);
    sIdxChAn{1}     = 1:length(NewChannelMat.Channel);

    % Sync videos
    sOldStudy = bst_get('Study', sInputs(1).iStudy);
    if isfield(sOldStudy,'Image') && ~isempty(sOldStudy.Image)
        for iOldVideo = 1 : length(sOldStudy.Image)
            sOldVideo = load(file_fullpath(sOldStudy.Image(iOldVideo).FileName));
            if isempty(sOldVideo.VideoStart)
                sOldVideo.VideoStart = 0;
            end
            iNewVideo = import_video(iNewStudy, sOldVideo.LinkTo);
            sNewStudy = bst_get('Study', iNewStudy);
            figure_video('SetVideoStart', file_fullpath(sNewStudy.Image(iNewVideo).FileName), sprintf('%.3f', sOldVideo.VideoStart));
        end
    end

    % Save sync data to file
    for iInput = 2:nInputs
        % Sync videos
        sOldStudy = bst_get('Study', sInputs(iInput).iStudy);
        if isfield(sOldStudy,'Image') && ~isempty(sOldStudy.Image)
            for iOldVideo = 1 : length(sOldStudy.Image)
                sOldVideo = load(file_fullpath(sOldStudy.Image(iOldVideo).FileName));
                if isempty(sOldVideo.VideoStart)
                    sOldVideo.VideoStart = 0;
                end
                iNewVideo = import_video(iNewStudy, sOldVideo.LinkTo);
                sNewStudy = bst_get('Study', iNewStudy);
                figure_video('SetVideoStart', file_fullpath(sNewStudy.Image(iNewVideo).FileName), sprintf('%.3f', sOldVideo.VideoStart));
            end
        end

        ChannelMat = in_bst_channel(sInputs(iInput).ChannelFile);
        
        sIdxChAn{iInput} = length(NewChannelMat.Channel) +  (1:length(ChannelMat.Channel));
        NewChannelMat.Channel = [ NewChannelMat.Channel , ChannelMat.Channel  ];


        if isfield(ChannelMat,'Nirs') && isfield(NewChannelMat,'Nirs')
            NewChannelMat.Nirs = sort( union(ChannelMat.Nirs, NewChannelMat.Nirs));
        elseif isfield(ChannelMat,'Nirs')  && ~isfield(NewChannelMat,'Nirs')
            NewChannelMat.Nirs = ChannelMat.Nirs;
        end
    end

    [~, iChannelStudy] = bst_get('ChannelForStudy', iNewStudy);
    db_set_channel(iChannelStudy, NewChannelMat, 0, 0);
    newStudyPath = bst_fileparts(file_fullpath(sNewStudy.FileName));

    % Link to raw file
    OutputFile = bst_process('GetNewFilename', bst_fileparts(sNewStudy.FileName), 'data_0raw_combned');

    % Raw file
    [~, rawBaseOut, rawBaseExt] = bst_fileparts(newStudyPath);
    rawBaseOut = strrep([rawBaseOut rawBaseExt], '@raw', '');
    RawFileOut = bst_fullfile(newStudyPath, [rawBaseOut '.bst']);

    bst_progress('inc', nInputs);
    bst_progress('text', 'Saving files...');


    % Set Output sFile structure
    sDataRawSync = in_bst_data(sInputs(1).FileName, 'F');
    sFileIn = sDataRawSync.F;
    sFileIn.header.nsamples = length(new_times);
    sFileIn.prop.times      = [ new_times(1), new_times(end)];
    sFileIn.channelflag     = ones(1,length(NewChannelMat.Channel));
    sFileOut = out_fopen(RawFileOut, 'BST-BIN', sFileIn, NewChannelMat);

    
    sDataSync        = in_bst(sInputs(1).FileName, [], 1, 1, 'no');
    sOutMat          = rmfield(sDataSync, 'F');
    sOutMat.format   = 'BST-BIN';
    sOutMat.DataType = 'raw';
    sOutMat.F        = sFileOut;
    sOutMat.ChannelFlag = ones(1,length(NewChannelMat.Channel));
    sOutMat.Comment  = [sDataSync.Comment ' | Combined'];
    
    bst_save(OutputFile, sOutMat, 'v6');

    % Save sync data to file
    for iInput = 1:nInputs
        % Load raw data
        sDataSync        = in_bst(sInputs(iInput).FileName, [], 1, 1, 'no');

        % Update raw data
        if iInput > 1
            sDataSync.F      = interp1(sDataSync.Time, sDataSync.F', new_times)';
        end
        % Write block
        out_fwrite(sFileOut, NewChannelMat, 1, [], sIdxChAn{iInput}, sDataSync.F);

        bst_progress('inc', 1);
    end
    
    % Register in BST database
    db_add_data(iNewStudy, OutputFile, sOutMat);
    OutputFiles{iInput} = OutputFile;

    bst_progress('stop');
end

