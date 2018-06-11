function varargout = process_convert_to_bst( varargin )
% process_convert_to_bst_Nas: Convert the raw signals to .bst files with a
% user defined sampling rate. It needs to be a subsample of the original Fs
% or even the original Fs.

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
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
% Author: Konstantinos Nasiotis 2018

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Convert to .bst';
    sProcess.Category    = 'custom';
    sProcess.SubGroup    = 'Electrophysiology';
    sProcess.Index       = 1803;
    sProcess.Description = 'www.in.gr';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw'};
    sProcess.OutputTypes = {'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    sProcess.processDim  = 1;    % Process channel by channel

    sProcess.options.paral.Comment     = 'Parallel processing';
    sProcess.options.paral.Type        = 'checkbox';
    sProcess.options.paral.Value       = 1;
    
    sProcess.options.binsize.Comment = 'Memory to use for demultiplexing';
    sProcess.options.binsize.Type    = 'value';
    sProcess.options.binsize.Value   = {40, 'GB', 1}; % This is used in case the electrodes are not separated yet (no spike sorting done), ot the temp folder was emptied 
    
    sProcess.options.sampling.Comment = 'New sampling rate';
    sProcess.options.sampling.Type    = 'value';
    sProcess.options.sampling.Value   = {10000, 'Hz', 1}; % This is used in case the electrodes are not separated yet (no spike sorting done), or the temp folder was emptied 
    
    sProcess.options.samplingHelp.Comment = '<I><FONT color="#777777">The new Fs should be the same or a submultiple of the original Fs</FONT></I>';
    sProcess.options.samplingHelp.Type    = 'label';
end



%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs, method) %#ok<DEFNU>
    
    for iInput = 1:length(sInputs)
        sInput = sInputs(iInput);
        %% Parameters
        % Output frequency
        NewFreq = sProcess.options.sampling.Value{1}(1);


        % Get method name
        if (nargin < 3)
            method = [];
        end

        
        % Prepare parallel pool, if requested
        if sProcess.options.paral.Value
            try
                poolobj = gcp('nocreate');
                if isempty(poolobj)
                    parpool;
                end
            catch
                sProcess.options.paral.Value = 0;
                poolobj = [];
            end
        else
            poolobj = [];
        end



        %% Initialize

        % Prepare output file
        ProtocolInfo = bst_get('ProtocolInfo');
        ProcessOptions = bst_get('ProcessOptions');
        newCondition = [sInput.Condition, '_converted'];
        sMat = in_bst(sInput.FileName, [], 0);
        Fs = 1 / diff(sMat.Time(1:2)); % This is the original sampling rate

        if mod(Fs,NewFreq) ~= 0 && mod(Fs,NewFreq)>10^(-5)
            % This would create a problematic downsampling
            error(['The downsampling will not be accurate. Make sure the new sampling rate is a submultiple of the original sampling rate. This process downsamples from ' num2str(Fs) ' to ' num2str(NewFreq) ' Hz'])
        end

        % Get new condition name
        newStudyPath = file_unique(bst_fullfile(ProtocolInfo.STUDIES, sInput.SubjectName, newCondition));
        % Output file name derives from the condition name
        [tmp, rawBaseOut] = bst_fileparts(newStudyPath);
        rawBaseOut = strrep(rawBaseOut, '@raw', '');
        % Full output filename
        RawFileOut = bst_fullfile(newStudyPath, [rawBaseOut '.bst']); % ***
        RawFileFormat = 'BST-BIN'; % ***
        ChannelMat = in_bst_channel(sInput.ChannelFile); % ***
        nChannels = length(ChannelMat.Channel);
        % Get input study (to copy the creation date)
        sInputStudy = bst_get('AnyFile', sInput.FileName);

        sStudy = bst_get('ChannelFile', sInput.ChannelFile);
        [tmp, iSubject] = bst_get('Subject', sStudy.BrainStormSubject, 1);

        % Get new condition name
        [tmp, ConditionName] = bst_fileparts(newStudyPath, 1);
        % Create output condition
        iOutputStudy = db_add_condition(sInput.SubjectName, ConditionName, [], sInputStudy.DateOfStudy);

        ChannelMatOut = ChannelMat;
        sFileTemplate = sMat.F;

        %% Get the transformed channelnames that were used on the signal data naming. This is used in the derive lfp function in order to find the spike events label
        % New channelNames - Without any special characters.
        cleanChannelNames = str_remove_spec_chars({ChannelMat.Channel.Name});

        %% Update fields before initializing the header on the binary file
        sFileTemplate.prop.samples = floor(sFileTemplate.prop.times * NewFreq);  % Check if FLOOR IS NEEDED HERE
        sFileTemplate.prop.sfreq = NewFreq;
        sFileTemplate.header.sfreq = NewFreq;
        sFileTemplate.header.nsamples = diff(sFileTemplate.prop.samples)+1;

        % Update file
        sFileTemplate.CommentTag     = sprintf('resample(%dHz)', round(NewFreq));
        sFileTemplate.HistoryComment = sprintf('Resample from %0.2f Hz to %0.2f Hz (%s)', Fs, NewFreq, method);

        % Convert events to new sampling rate
        newTimeVector = linspace(sFileTemplate.prop.times(1),sFileTemplate.prop.times(2),sFileTemplate.prop.samples(2)+1);
        sFileTemplate.events = panel_record('ChangeTimeVector', sFileTemplate.events, Fs, newTimeVector);

        %% Create an empty Brainstorm-binary file and assign the correct samples-times
        % The sFileOut is what will be the final 
        [sFileOut, errMsg] = out_fopen(RawFileOut, RawFileFormat, sFileTemplate, ChannelMat);


        %% Check if the files are separated per channel. If not do it now.
        % These files will be converted to LFP right after
        sFiles_temp_mat = in_spikesorting_rawelectrodes(sInput, sProcess.options.binsize.Value{1}(1) * 1e9, sProcess.options.paral.Value);

        %% Filter and derive LFP
        LFP = zeros(length(sFiles_temp_mat), length(downsample(sMat.Time,round(Fs/NewFreq)))); % This shouldn't create a memory problem
        bst_progress('start', 'Spike-sorting', 'Converting RAW signal to .bst file...', 0, (sProcess.options.paral.Value == 0) * nChannels);

        
        if sProcess.options.paral.Value
            parfor iChannel = 1:nChannels
                LFP(iChannel,:) = filter_and_downsample(sFiles_temp_mat{iChannel}, Fs, NewFreq);
            end
        else
            for iChannel = 1:nChannels
                LFP(iChannel,:) = filter_and_downsample(sFiles_temp_mat{iChannel}, Fs, NewFreq);
                bst_progress('inc', 1);
            end
        end
        
        % WRITE OUT
        sFileOut = out_fwrite(sFileOut, ChannelMatOut, [], [], [], LFP);

        % Import the RAW file in the database viewer and open it immediately
        OutputFiles = import_raw({sFileOut.filename}, 'BST-BIN', iSubject);
    end
end


function data = filter_and_downsample(inputFilename, Fs, NewFreq)
    sMat = load(inputFilename); % Make sure that a variable named data is loaded here. This file is saved as an output from the separator 
    data = downsample(sMat.data, round(Fs/NewFreq))';  % The file now has a different sampling rate (fs/30) = 1000Hz.
end

