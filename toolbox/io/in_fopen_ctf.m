function [sFile, ChannelMat] = in_fopen_ctf(ds_directory)
% IN_FOPEN_CTF: Open a CTF file, and get all the data and channel information.
%
% USAGE:  [sFile, ChannelMat] = in_fopen_ctf(ds_directory)

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
% Authors: Francois Tadel, 2009-2018


%% ===== READ HEADER =====
% Import .DS directory, not single file
if ~isdir(ds_directory)
    ds_directory = bst_fileparts(ds_directory);
end
% Get dataset name and file paths
[DataSetName, meg4_files, res4_file, marker_file, pos_file, hc_file] = ctf_get_files( ds_directory );
% Read header file
[header, ChannelMat] = ctf_read_res4(res4_file);
if isempty(header)
    error('Cannot read header file.');
end

%% ===== MULTIPLE .MEG4 =====
% For each meg4 file, compute how many trials it contains
% (given that each file contains an integer number of trials, and all trials have the same size)
% Save list of MEG4 files
header.meg4_files = meg4_files;
% Size in bytes of each trial (always saved in int32)
bytes_per_trial = 4 * header.gSetUp.no_samples * header.gSetUp.no_channels;
% Initialize list of epochs
header.meg4_epochs = cell(1, length(meg4_files));
nTotal = 0;
% Loop on each file
for iFile = 1:length(meg4_files)
    % Get file size
    fileDir = dir(meg4_files{iFile});
    if isempty(fileDir)
        error(['File not found: ' meg4_files{iFile}]);
    end
    % Divide by trial size to get the number of trials
    nTrials = round((fileDir.bytes - 8) / bytes_per_trial);
    % Check that file is full (there is an integer number of trials in it)
    if (nTrials * bytes_per_trial ~= fileDir.bytes - 8)
        disp(['CTF> WARNING: ' meg4_files{iFile} ' does not contain an integer number of trials']);
    end
    % Record all the trials contained in this meg4 file
    header.meg4_epochs{iFile} = (1:nTrials) + nTotal;
    nTotal = header.meg4_epochs{iFile}(end);
end


%% ===== FILL STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.filename   = meg4_files{1};
sFile.format     = 'CTF';
sFile.device     = header.acq_system;
sFile.comment    = deblank(header.RunTitle);
sFile.byteorder  = 's';
sFile.header     = header;
% Time and samples indices
sFile.prop.sfreq   = double(header.gSetUp.sample_rate);
sFile.prop.samples = ([0, header.gSetUp.no_samples - 1] - header.gSetUp.preTrigPts);
sFile.prop.times   = sFile.prop.samples ./ header.gSetUp.sample_rate;
% Acquisition date
sFile.acq_date = str_date(header.res4.data_date);

% Get number of epochs
nEpochs = header.gSetUp.no_trials;
% Get number of averaged trials
nAvg = header.res4.no_trials_avgd;
if (nAvg == 0)
    nAvg = 1;
end
% === EPOCHS FILE ===
if (nEpochs > 1)
    % Build epochs structure
    for i = 1:nEpochs
        if (length(DataSetName) < 15)
            sFile.epochs(i).label = sprintf('%s (#%d)', DataSetName, i);
        else
            sFile.epochs(i).label = sprintf('Trial (#%d)', i);
        end
        sFile.epochs(i).samples = sFile.prop.samples;
        sFile.epochs(i).times   = sFile.prop.times;
        sFile.epochs(i).nAvg    = nAvg;
        sFile.epochs(i).select  = 1;
        sFile.epochs(i).bad         = 0;
        sFile.epochs(i).channelflag = [];
    end
elseif (nEpochs == 1)
    sFile.prop.nAvg = nAvg;
end


%% ===== READ BAD CHANNELS =====
ChannelFlag = ones(length(ChannelMat.Channel), 1);
% Look for a badchannel file if exists
badchannel_file = bst_fullfile(ds_directory,'BadChannels');
if file_exist(badchannel_file)
    % Function 'textread' not recommended after Matb 2014b: replaced with textscan
    %badchan_name = textread(badchannel_file,'%s');
    % Read bad channels file
    fid = fopen(badchannel_file, 'r');
    if (fid < 0)
        disp('CTF> Cannot open BacChannels file.');
    end
    badchan_name = textscan(fid,'%s');
    fclose(fid);
    % If some bad channels are indicated in the .ds folder
    if ~isempty(badchan_name) && ~isempty(badchan_name{1})
        % Get indices of bad channels
        [tmp I] = intersect({ChannelMat.Channel.Name}, badchan_name{1});
        ChannelFlag(I) = -1;
    end
end
sFile.channelflag = ChannelFlag;


%% ===== CTF COMPENSATION =====
if ~isempty(ChannelMat.MegRefCoef)
    % Get current level of compensation
    currentComp = header.grad_order_no;
    % If not all the same value: error
    if ~all(currentComp == currentComp(1))
        error('CTF compensation is not set equally on all MEG channels');
    end
    % Current compensation order
    sFile.prop.currCtfComp = currentComp(1);
    % Destination compensation order (keep compensation order, unless it is 0)
    if (currentComp(1) == 0)
        sFile.prop.destCtfComp = 3;
    else
        sFile.prop.destCtfComp = currentComp(1);
    end
else
    sFile.prop.currCtfComp = 3;
end


%% ===== READ EVENTS =====
% Read markers file
if ~isempty(marker_file)
    sFile.events = in_events_ctf(sFile, marker_file);
end


%% ===== READ POLHEMUS FILE =====
if ~isempty(pos_file)
    % Read file
    HeadMat = in_channel_pos(pos_file);
    % Copy head points
    ChannelMat.HeadPoints = HeadMat.HeadPoints;
    % Force re-alignment on the new set of NAS/LPA/RPA (switch from CTF coil-based to SCS anatomical-based coordinate system)
    ChannelMat = channel_detect_type(ChannelMat, 1, 0);
end

%% ===== READ HC FILE =====
if ~isempty(hc_file)
    % Open ascii file
    fid = fopen(hc_file, 'r');
    if (fid < 0)
        error('Cannot open .hc file.');
    end
    % Read file
    strAll = char(fread(fid, Inf, 'char')');
    % Close file
    fclose(fid);
    % Split in lines
    strLines = strtrim(str_split(strAll, 10));
    % Find the three coils relative to dewar
    iNas = find(strcmpi(strLines, 'measured nasion coil position relative to dewar (cm):'));
    iLpa = find(strcmpi(strLines, 'measured left ear coil position relative to dewar (cm):'));
    iRpa = find(strcmpi(strLines, 'measured right ear coil position relative to dewar (cm):'));
    % If the three coils are available: get the X,Y,Z coordinates
    if ~isempty(iNas) && ~isempty(iLpa) && ~isempty(iRpa)
        hc.SCS.NAS = [str2num(strLines{iNas+1}(4:end)), str2num(strLines{iNas+2}(4:end)), str2num(strLines{iNas+3}(4:end))] ./ 100;
        hc.SCS.LPA = [str2num(strLines{iLpa+1}(4:end)), str2num(strLines{iLpa+2}(4:end)), str2num(strLines{iLpa+3}(4:end))] ./ 100;
        hc.SCS.RPA = [str2num(strLines{iRpa+1}(4:end)), str2num(strLines{iRpa+2}(4:end)), str2num(strLines{iRpa+3}(4:end))] ./ 100;
        % If all the coordinates of all the coils can be read: compute the "Dewar=>Native" coordinates
        if (length(hc.SCS.NAS) == 3) && (length(hc.SCS.LPA) == 3) && (length(hc.SCS.RPA) == 3)
            % Save positions in the header
            sFile.header.hc = hc;
            % Compute Dewar=>Native transformation
            transf = cs_compute(hc, 'scs');
            % Copy to the ChannelMat structure
            if ~isempty(transf) && ~isempty(transf.R) && ~isempty(transf.T)
                transf = [transf.R, transf.T; 0 0 0 1];
                tlabel = 'Dewar=>Native';
                % MEG transformation
                if isempty(ChannelMat.TransfMeg)
                    ChannelMat.TransfMeg = {transf};
                    ChannelMat.TransfMegLabels = {tlabel};
                else
                    ChannelMat.TransfMeg = cat(2, {transf}, ChannelMat.TransfMeg);
                    ChannelMat.TransfMegLabels = cat(2, {tlabel}, ChannelMat.TransfMegLabels);
                end
            end
        end
    end
end


%% ===== OPEN DATA FILE =====
% FILE IS NOW OPENED IN THE IN_FREAD_CTF FUNCTION
% Modification made when adding the support for .ds multiple meg4 files 
% => we need to know what we are reading to open the correct file.

%% ===== CONVERT TO CONTINUOUS =====
if (length(sFile.epochs) > 1) && ~isempty(strfind(ds_directory, '_AUX'))
    % Convert
    [sFileTmp, Messages] = process_ctf_convert('Compute', sFile, 'continuous');
    % If error: leave it the way it is
    if ~isempty(sFileTmp)
        sFile = sFileTmp;
    end
    % Display message
    if ~isempty(Messages)
        % Display on console
        disp([10, 'CTF> ', strrep(Messages, char(10), [10 'CTF> ']), 10]);
        % Send to the current report
        bst_report('Warning', 'process_import_data_raw', [], Messages);
    end
        
%     % If there are events defined in the MarkerFile of the AUX file: fix them 
%     % => CTF bug for AUX files: triggers are generated when the Stim channel is high at the beginning of a "trial"
%     if ~isempty(sFile.events)
%         strMsg = '';
%         % Build list of sample indices where the DS trials start
%         trialStarts = sFile.prop.samples(1) + (0:sFile.header.gSetUp.no_trials-1) * sFile.header.gSetUp.no_samples;
%         % Loop on the MarkerFile events
%         for iEvt = 1:length(sFile.events)
%             % Skip if no event
%             if isempty(sFile.events(iEvt).samples)
%                 continue;
%             end
%             % Find events that match the beginning of a trial
%             iRemove = find(ismember(sFile.events(iEvt).samples(1,:), trialStarts));
%             % If found: delete them
%             if ~isempty(iRemove)
%                 % Get the times to remove
%                 tRemove = sFile.events(iEvt).times(1,iRemove);
%                 % Remove the events occurrences
%                 sFile.events(iEvt).times(:,iRemove)   = [];
%                 sFile.events(iEvt).samples(:,iRemove) = [];
%                 sFile.events(iEvt).epochs(:,iRemove)  = [];
%                 if ~isempty(sFile.events(iEvt).reactTimes)
%                     sFile.events(iEvt).reactTimes(:,iRemove) = [];
%                 end
%                 % Display message
%                 strMsg = [strMsg, 10, 'Removed ' num2str(length(iRemove)) ' x "' sFile.events(iEvt).label, '": ', sprintf('%1.3f ', tRemove)];
%             end
%         end
%         % Display message
%         if ~isempty(strMsg)
%             strMsg = ['Errors detected in the events of the AUX file (markers at the beginning of a trial): ' strMsg];
%             % Display on console
%             disp([10, 'CTF> ', strrep(strMsg, char(10), [10 'CTF> ']), 10]);
%             % Send to the current report
%             bst_report('Warning', 'process_import_data_raw', [], strMsg);
%         end
%     end
end

     

