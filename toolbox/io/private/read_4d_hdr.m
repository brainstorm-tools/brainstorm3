function header = read_4d_hdr(datafile, configfile)
% READ_4D_HDR:  Read a 4D/BTi data file header and the associated 'config' file
% 
% USAGE:  header = read_4d_hdr(datafile, configfile)
%
% CONTRIBUTORS:
%    - This function was created based on the read_4d_hdr.m file from FieldTrip toolbox:
%      Copyright (C) 2008-2009, Centre for Cognitive Neuroimaging, Glasgow, Gavin Paterson & J.M.Schoffelen
%    - The intial file was based on MSI>>Matlab code written by Eugene Kronberg

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
% Authors: Eugene Kronberg, ?
%          Gavin Paterson & J.M.Schoffelen, 2008-2009
%          Francois Tadel, 2009-2015

% Parse inputs
if (nargin ~= 2)
    error('USAGE:  header = read_4d_hdr(datafile, configfile)');
end

%% ===== READ DATA FILE HEADER =====
if ~isempty(datafile)
    % Get file type, based on the filename
    [tmp__, fbase] = bst_fileparts(datafile);
    switch (fbase(1:2))
        case 'c,',  header.file_type = 'raw';
        case 'e,',  header.file_type = 'average';
        otherwise,  error('Unknown file type.');
    end
    
    % Open file (always big-endian)
    fid = fopen(datafile, 'r', 'b');
    if fid == -1
        error('Cannot open file %s', datafile);
    end
    % Get last position in the file
    fseek(fid, 0, 'eof');
    header_end = ftell(fid);
    % Last 8 bytes of the file represent the header offset
    fseek(fid, -8, 'eof');
    header_offset = fread(fid,1,'uint64');
    % Check if this pointer is inside the file
    if (header_offset > header_end)
        error('File error. Missing header pointer at the end of the file.');
    end
    
    % === READ HEADER ===
    % Go to the first byte of the header
    fseek(fid, double(header_offset), 'bof'); 
    align_file_pointer(fid);
    % Read header data
    header.header_data.file_format_int = fread(fid, 1, 'uint16=>uint16');
    header.header_data.file_format_str = deblank(fread(fid, [1 5], 'uchar=>char'));
    fseek(fid, 1, 'cof');
    header.header_data.data_format_int = fread(fid, 1, 'int16=>int16');
    switch header.header_data.data_format_int
        case 1,    header.header_data.data_format_str = 'SHORT';
        case 2,    header.header_data.data_format_str = 'LONG';
        case 3,    header.header_data.data_format_str = 'FLOAT';
        case 4,    header.header_data.data_format_str = 'DOUBLE';
        otherwise, error('Invalid data format.'); 
    end
    header.header_data.acq_mode           = fread(fid, 1,  'uint16=>uint16');
    header.header_data.TotalEpochs        = fread(fid, 1,  'uint32=>double');
    header.header_data.input_epochs       = fread(fid, 1,  'uint32=>uint32');
    header.header_data.TotalEvents        = fread(fid, 1,  'uint32=>uint32');
    header.header_data.total_fixed_events = fread(fid, 1,  'uint32=>uint32');
    header.header_data.SamplePeriod       = fread(fid, 1,  'float32=>float64');
    header.header_data.SampleFrequency    = 1 / header.header_data.SamplePeriod;
    header.header_data.xaxis_label        = deblank(fread(fid, [1 16], 'uchar=>char'));
    header.header_data.total_processes    = fread(fid, 1,  'uint32=>uint32');
    header.header_data.TotalChannels      = fread(fid, 1,  'uint16=>double');
    fseek(fid, 2, 'cof');
    header.header_data.checksum           = fread(fid, 1,  'int32=>int32');
    header.header_data.total_ed_classes   = fread(fid, 1,  'uint32=>uint32');
    header.header_data.total_associated_files = fread(fid, 1, 'uint16=>uint16');
    header.header_data.last_file_index    = fread(fid, 1,  'uint16=>uint16');
    header.header_data.timestamp          = fread(fid, 1,  'uint32=>uint32');
    header.header_data.reserved           = fread(fid, [1 20], 'uchar');
    fseek(fid, 4, 'cof');
    
    % === READ EPOCHS ===
    for epoch = 1:header.header_data.TotalEpochs;
        align_file_pointer(fid);
        header.epoch_data(epoch).pts_in_epoch     = fread(fid, 1,  'uint32=>uint32');
        header.epoch_data(epoch).epoch_duration   = fread(fid, 1,  'float32=>float32');
        header.epoch_data(epoch).expected_iti     = fread(fid, 1,  'float32=>float32');
        header.epoch_data(epoch).actual_iti       = fread(fid, 1,  'float32=>float32');
        header.epoch_data(epoch).total_var_events = fread(fid, 1,  'uint32=>uint32');
        header.epoch_data(epoch).checksum         = fread(fid, 1,  'int32=>int32');
        header.epoch_data(epoch).epoch_timestamp  = fread(fid, 1,  'int32=>int32');
        header.epoch_data(epoch).reserved         = fread(fid, [1 28], 'uchar');

        % === READ VAR EVENTS ===
        for event = 1:header.epoch_data(epoch).total_var_events
            align_file_pointer(fid);
            header.epoch_data(epoch).var_event{event}.event_name  = deblank(fread(fid, [1 16], 'uchar=>char'));
            header.epoch_data(epoch).var_event{event}.start_lat   = fread(fid, 1, 'float32=>float32');
            header.epoch_data(epoch).var_event{event}.end_lat     = fread(fid, 1, 'float32=>float32');
            header.epoch_data(epoch).var_event{event}.step_size   = fread(fid, 1, 'float32=>float32');
            header.epoch_data(epoch).var_event{event}.fixed_event = fread(fid, 1, 'uint16=>uint16');
            fseek(fid, 2, 'cof');
            header.epoch_data(epoch).var_event{event}.checksum    = fread(fid, 1, 'int32=>int32');
            header.epoch_data(epoch).var_event{event}.reserved    = fread(fid, [1 32], 'uchar');
            fseek(fid, 4, 'cof');
        end
    end
    
    % === READ CHANNEL REF DATA ===
    for channel = 1:header.header_data.TotalChannels
        align_file_pointer(fid);
        header.channel_data(channel).chan_label    = deblank(fread(fid, [1 16], 'uint8=>char'));
        header.channel_data(channel).chan_no       = fread(fid, 1, 'uint16=>uint16');
        header.channel_data(channel).attributes    = fread(fid, 1, 'uint16=>uint16');
        header.channel_data(channel).scale         = fread(fid, 1, 'float32=>float32');
        header.channel_data(channel).yaxis_label   = deblank(fread(fid, [1 16], 'uint8=>char'));
        header.channel_data(channel).valid_min_max = fread(fid, 1, 'uint16=>uint16');
        fseek(fid, 6, 'cof');
        header.channel_data(channel).ymin          = fread(fid, 1,  'float64');
        header.channel_data(channel).ymax          = fread(fid, 1,  'float64');
        header.channel_data(channel).index         = fread(fid, 1,  'uint32=>uint32');
        header.channel_data(channel).checksum      = fread(fid, 1,  'int32=>int32');
        header.channel_data(channel).whatisit      = fread(fid, [1 4], 'uint8=>char');
        header.channel_data(channel).reserved      = fread(fid, [1 28], 'uint8');
    end
    
    % === READ FIXED EVENTS ===
    for event = 1:header.header_data.total_fixed_events
        align_file_pointer(fid);
        header.event_data(event).event_name  = deblank(fread(fid, [1 16], 'uchar=>char'));
        header.event_data(event).start_lat   = fread(fid, 1,  'float32=>float32');
        header.event_data(event).end_lat     = fread(fid, 1,  'float32=>float32');
        header.event_data(event).step_size   = fread(fid, 1,  'float32=>float32');
        header.event_data(event).fixed_event = fread(fid, 1,  'uint16=>uint16');
        fseek(fid, 2, 'cof');
        header.event_data(event).checksum    = fread(fid, 1,  'int32=>int32');
        header.event_data(event).reserved    = fread(fid, [1 32], 'uchar');
        fseek(fid, 4, 'cof');
    end
    header.header_data.FirstLatency = double(header.event_data(1).start_lat);
    
    % === READ PROCESSES ===
    % Read all the processes
    for np = 1:header.header_data.total_processes
        align_file_pointer(fid);
        fp = ftell(fid);
        % Read process 
        header.process(np).nbytes     = fread(fid, 1,  'uint32=>uint32');
        header.process(np).type       = deblank(fread(fid, [1 20], 'uchar=>char'));
        header.process(np).checksum   = fread(fid, 1,  'int32=>int32');
        header.process(np).user       = deblank(fread(fid, [1 32], 'uchar=>char'));
        header.process(np).timestamp  = fread(fid, 1,  'uint32=>uint32');
        header.process(np).filename   = deblank(fread(fid, [1 32], 'uchar=>char'));
        fseek(fid, 28*8, 'cof'); % Don't know what is this for...
        header.process(np).totalsteps = fread(fid, 1,  'uint32=>uint32');
        header.process(np).checksum   = fread(fid, 1,  'int32=>int32');
        header.process(np).reserved   = fread(fid, [1 32], 'uchar');
        % Loop on all the steps
        for ns = 1:header.process(np).totalsteps
            % The following entries depend on the process type
            header.process(np).step(ns).nbytes        = fread(fid, 1, 'uint32=>uint32');
            header.process(np).step(ns).type          = deblank(fread(fid, [1 20], 'uchar=>char'));
            header.process(np).step(ns).checksum      = fread(fid, 1, 'int32=>int32');
            header.process(np).step(ns).userblocksize = fread(fid, 1, 'int32=>uint32');
            % The rest of the reading depends on the step type
            switch (header.process(np).step(ns).type)
                case 'b_selection'
                    fseek(fid, 5*8, 'cof');
                    header.process(np).step(ns).uservalue1 = fread(fid, [1 2], 'single=>double', 4);
                    fseek(fid, 4, 'cof');
                    header.process(np).step(ns).uservalue2 = deblank(fread(fid, [1 20], 'uchar=>char'));
                case 'b_sel_group'
                    fseek(fid, 4*8, 'cof');
                    header.process(np).step(ns).uservalue1 = fread(fid, 1, 'int32=>uint32');
                    header.process(np).step(ns).uservalue2 = deblank(fread(fid, [1 20], 'uchar=>char'));
                otherwise
                    % Ignore the rest of the step, we won't use it
            end
            % If user block size has a valid value: add it to size of step
            if (header.process(np).step(ns).userblocksize <= 512)
                header.process(np).step(ns).nbytes = header.process(np).step(ns).nbytes + header.process(np).step(ns).userblocksize;
            end
            % Increase current process bytes size
            header.process(np).nbytes = header.process(np).nbytes + header.process(np).step(ns).nbytes;
            % After reading this step: reposition at the beginning of the next one
            fseek(fid, double(fp + header.process(np).nbytes), 'bof');
            % Realign file pointer on 64bits blocks
            offset_align = align_file_pointer(fid);
            header.process(np).nbytes = header.process(np).nbytes + offset_align;
        end
        % After reading this process: reposition at the beginning of the next one
        fseek(fid, double(fp + header.process(np).nbytes), 'bof');
    end

    % Close data file
    fclose(fid);
end


%% ===== READ CONFIG FILE =====
% Open config file
fid = fopen(configfile, 'r', 'b');
if fid == -1
    error('Cannot open config file');
end
% Read file header
header.config_data.version           = fread(fid, 1, 'uint16=>uint16');
header.config_data.site_name         = deblank(fread(fid, [1 32], 'uchar=>char'));
header.config_data.dap_hostname      = deblank(fread(fid, [1 16], 'uchar=>char'));
header.config_data.sys_type          = fread(fid, 1, 'uint16=>uint16');
header.config_data.sys_options       = fread(fid, 1, 'uint32=>uint32');
header.config_data.supply_freq       = fread(fid, 1, 'uint16=>uint16');
header.config_data.total_chans       = fread(fid, 1, 'uint16=>uint16');
header.config_data.system_fixed_gain = fread(fid, 1, 'float32=>float32');
header.config_data.volts_per_bit     = fread(fid, 1, 'float32=>float32');
header.config_data.total_sensors     = fread(fid, 1, 'uint16=>uint16');
header.config_data.total_user_blocks = fread(fid, 1, 'uint16=>uint16');
header.config_data.next_derived_channel_number = fread(fid, 1, 'uint16=>uint16');
fseek(fid, 2, 'cof');
header.config_data.checksum          = fread(fid, 1, 'int32=>int32');
header.config_data.reserved          = fread(fid, [1 32], 'uchar=>uchar');
header.config.Xfm                    = fread(fid, [4 4], 'double');

% Read user blocks
for ub = 1:header.config_data.total_user_blocks
    % Read block header
    align_file_pointer(fid);
    header.user_block_data{ub}.nbytes      = fread(fid, 1, 'uint32=>uint32');
    header.user_block_data{ub}.type        = deblank(fread(fid, [1 20], 'uchar=>char'));
    header.user_block_data{ub}.checksum    = fread(fid, 1, 'int32=>int32');
    header.user_block_data{ub}.user            = deblank(fread(fid, [1 32], 'uchar=>char'));
    header.user_block_data{ub}.timestamp       = fread(fid, 1, 'uint32=>uint32');
    header.user_block_data{ub}.user_space_size = fread(fid, 1, 'uint32=>uint32');
    header.user_block_data{ub}.reserved        = fread(fid, [1 32], 'uchar=>uchar');
    fseek(fid, 4, 'cof');
    % Current user space size
    user_space_size = double(header.user_block_data{ub}.user_space_size);
    
    % Process different block types
    switch (header.user_block_data{ub}.type)
        % === COMPENSATION WEIGHTS ===
        case 'B_weights_used'
            tmpfp = ftell(fid);
            %there is information in the 4th and 8th byte, these might be related to the settings?
            version  = fread(fid, 1, 'uint32');
            header.user_block_data{ub}.version = version;
            if (version == 1)
                Nbytes   = fread(fid,1,'uint32');
                Nchan    = fread(fid,1,'uint32');
                header.user_block_data{ub}.position = deblank(fread(fid, [1 32], 'uchar=>char'));
                fseek(fid, double(tmpfp+user_space_size - Nbytes*Nchan), 'bof');
                Ndigital = floor((Nbytes - 4*2) / 4);
                Nanalog  = 3; %lucky guess?
                % how to know number of analog weights vs digital weights???
                for ch = 1:Nchan
                    % for Konstanz -- comment for others?
                    header.user_block_data{ub}.aweights(ch,:) = fread(fid, [1 Nanalog],  'int16')';
                    fseek(fid,2,'cof'); % alignment
                    header.user_block_data{ub}.dweights(ch,:) = fread(fid, [1 Ndigital], 'single=>double')';
                end
                fseek(fid, tmpfp, 'bof');
                %there is no information with respect to the channels here.
                %the best guess would be to assume the order identical to the order in header.config.channel_data
                %for the digital weights it would be the order of the references in that list
                %for the analog weights I would not know
            elseif (version == 2)
                unknown2 = fread(fid, 1, 'uint32');
                Nchan    = fread(fid, 1, 'uint32');
                header.user_block_data{ub}.position = deblank(fread(fid, [1 32], 'uchar=>char'));
                fseek(fid, tmpfp+124, 'bof');
                Nanalog  = fread(fid, 1, 'uint32');
                Ndigital = fread(fid, 1, 'uint32');
                fseek(fid, tmpfp+204, 'bof');
                for k = 1:Nchan
                    header.user_block_data{ub}.channames{k,1} = deblank(fread(fid, [1 16], 'uchar=>char'));
                end
                for k = 1:Nanalog
                    header.user_block_data{ub}.arefnames{k,1} = deblank(fread(fid, [1 16], 'uchar=>char'));
                end
                for k = 1:Ndigital
                    header.user_block_data{ub}.drefnames{k,1} = deblank(fread(fid, [1 16], 'uchar=>char'));
                end

                header.user_block_data{ub}.dweights = fread(fid, [Ndigital Nchan], 'single=>double')';
                header.user_block_data{ub}.aweights = fread(fid, [Nanalog  Nchan],  'int16')';
                fseek(fid, tmpfp, 'bof');
            end
            
        % === DIGITIZED POSITIONS ===
        case 'b_eeg_elec_locs'
            %this block contains the digitized coil positions
            tmpfp   = ftell(fid);
            Npoints = user_space_size ./ 40;
            for k = 1:Npoints
                label{k} = fread(fid, [1 16], 'uchar=>char');
                pnt(k,:) = fread(fid, [1 3], 'double');
                % Cutting the label after the 0 character, if any
                iz = find(label{k} == 0);
                if ~isempty(iz)
                    label{k}(iz(1):end) = [];
                end
            end
            header.user_block_data{ub}.label = label(:);
            header.user_block_data{ub}.pnt   = pnt;
            header.block_eeg_loc = ub;
            fseek(fid, tmpfp, 'bof');
            
        case 'B_E_table_used'
            %warning('reading in weight table: no warranty that this is correct');
            %tmpfp = ftell(fid);
            %fseek(fid, 4, 'cof'); %there's info here dont know how to interpret
            %Nx    = fread(fid, 1, 'uint32');
            %Nchan = fread(fid, 1, 'uint32');
            %type  = fread(fid, 32, 'uchar'); %don't know whether correct
            %header.user_block_data{ub}.type = char(type(type>0))';
            %fseek(fid, 16, 'cof');
            %for k = 1:Nchan
            %  name                                 = fread(fid, 16, 'uchar');
            %  header.user_block_data{ub}.name{k,1} = char(name(name>0))';
            %end
            
        case 'B_COH_Points'
            % tmpfp = ftell(fid);
            % Ncoil = fread(fid, 1,         'uint32');
            % N     = fread(fid, 1,         'uint32');
            % coils = fread(fid, [7 Ncoil], 'double');

            % header.user_block_data{ub}.pnt   = coils(1:3,:)';
            % header.user_block_data{ub}.ori   = coils(4:6,:)';
            % header.user_block_data{ub}.Ncoil = Ncoil;
            % header.user_block_data{ub}.N     = N;
            % tmp = fread(fid, (904-288)/8, 'double');
            % header.user_block_data{ub}.tmp   = tmp; %FIXME try to find out what these bytes mean
            % fseek(fid, tmpfp, 'bof');
            
        case 'b_ccp_xfm_block'
            % tmpfp = ftell(fid);
            % tmp1 = fread(fid, 1, 'uint32');
            % %tmp = fread(fid, [4 4], 'double');
            % %tmp = fread(fid, [4 4], 'double');
            % %the next part seems to be in little endian format (at least when I tried)
            % tmp = fread(fid, 128, 'uint8');
            % tmp = uint8(reshape(tmp, [8 16])');
            % xfm = zeros(4,4);
            % for k = 1:size(tmp,1)
            %     xfm(k) = typecast(tmp(k,:), 'double');
            %     if (abs(xfm(k))<1e-10 || abs(xfm(k))>1e10)
            %         xfm(k) = typecast(fliplr(tmp(k,:)), 'double');
            %     end
            % end
            % fseek(fid, tmpfp, 'bof'); %FIXME try to find out why this looks so strange
    end
    fseek(fid, user_space_size, 'cof');
end

% ===== READ CHANNEL INFORMATION ======
for ch = 1:header.config_data.total_chans
    align_file_pointer(fid);
    header.config.channel_data(ch).name = deblank(fread(fid, [1 16], 'uchar=>char'));
    %FIXME this is a very dirty fix to get the reading in of continuous headlocalization
    %correct. At the moment, the numbering of the hmt related channels seems to start with 1000
    %which I don't understand, but seems rather nonsensical.
    chan_no = fread(fid, 1, 'uint16=>uint16');
    if (chan_no > header.config_data.total_chans)
        %FIXME fix the number in header.channel_data as well
        sel     = find([header.channel_data.chan_no]== chan_no);
        if ~isempty(sel)
            chan_no = ch;
            header.channel_data(sel).chan_no    = chan_no;
            header.channel_data(sel).chan_label = header.config.channel_data(ch).name;
        else
            %does not matter
        end
    end
    header.config.channel_data(ch).chan_no       = chan_no;
    header.config.channel_data(ch).type          = fread(fid, 1, 'uint16=>uint16');
    header.config.channel_data(ch).sensor_no     = fread(fid, 1, 'int16=>int16');
    fseek(fid, 2, 'cof');
    header.config.channel_data(ch).gain          = fread(fid, 1, 'float32=>float32');
    header.config.channel_data(ch).units_per_bit = fread(fid, 1, 'float32=>float32');
    header.config.channel_data(ch).yaxis_label   = deblank(fread(fid, [1 16], 'uchar=>char'));
    header.config.channel_data(ch).aar_val       = fread(fid, 1, 'double');
    header.config.channel_data(ch).checksum      = fread(fid, 1, 'int32=>int32');
    header.config.channel_data(ch).reserved      = fread(fid, [1 32], 'uchar=>uchar');
    fseek(fid, 4, 'cof');
    
    align_file_pointer(fid);
    header.config.channel_data(ch).device_data.size     = fread(fid, 1, 'uint32=>uint32');
    header.config.channel_data(ch).device_data.checksum = fread(fid, 1, 'int32=>int32');
    header.config.channel_data(ch).device_data.reserved = fread(fid, [1 32], 'uchar=>uchar');
    
    switch header.config.channel_data(ch).type
        case {1, 3} % MEG / REF
            header.config.channel_data(ch).device_data.inductance  = fread(fid, 1, 'float32=>float32');
            fseek(fid, 4, 'cof');
            header.config.channel_data(ch).device_data.Xfm         = fread(fid, [4 4], 'double');
            header.config.channel_data(ch).device_data.xform_flag  = fread(fid, 1, 'uint16=>uint16');
            header.config.channel_data(ch).device_data.total_loops = fread(fid, 1, 'uint16=>uint16');
            header.config.channel_data(ch).device_data.reserved    = fread(fid, [1 32], 'uchar=>uchar');
            fseek(fid, 4, 'cof');
            % Read each loop
            for loop = 1:header.config.channel_data(ch).device_data.total_loops
                align_file_pointer(fid);
                header.config.channel_data(ch).device_data.loop_data(loop).position    = fread(fid, 3, 'double');
                header.config.channel_data(ch).device_data.loop_data(loop).direction   = fread(fid, 3, 'double');
                header.config.channel_data(ch).device_data.loop_data(loop).radius      = fread(fid, 1, 'double');
                header.config.channel_data(ch).device_data.loop_data(loop).wire_radius = fread(fid, 1, 'double');
                header.config.channel_data(ch).device_data.loop_data(loop).turns       = fread(fid, 1, 'uint16=>uint16');
                fseek(fid, 2, 'cof');
                header.config.channel_data(ch).device_data.loop_data(loop).checksum    = fread(fid, 1, 'int32=>int32');
                header.config.channel_data(ch).device_data.loop_data(loop).reserved    = fread(fid, [1 32], 'uchar');
            end
        case 2 % EEG
            header.config.channel_data(ch).device_data.impedance       = fread(fid, 1, 'float32=>float32');
            fseek(fid, 4, 'cof');
            header.config.channel_data(ch).device_data.Xfm             = fread(fid, [4 4], 'double');
            header.config.channel_data(ch).device_data.reserved        = fread(fid, [1 32], 'uchar=>uchar');
        case 4 % EXTERNAL
            header.config.channel_data(ch).device_data.user_space_size = fread(fid, 1, 'uint32=>uint32');
            header.config.channel_data(ch).device_data.reserved        = fread(fid, [1 32], 'uchar=>uchar');
            fseek(fid, 4, 'cof');
        case 5 % TRIGGER
            header.config.channel_data(ch).device_data.user_space_size = fread(fid, 1, 'uint32=>uint32');
            header.config.channel_data(ch).device_data.reserved        = fread(fid, [1 32], 'uchar=>uchar');
            fseek(fid, 4, 'cof');
        case 6 % UTILITY
            header.config.channel_data(ch).device_data.user_space_size = fread(fid, 1, 'uint32=>uint32');
            header.config.channel_data(ch).device_data.reserved        = fread(fid, [1 32], 'uchar=>uchar');
            fseek(fid, 4, 'cof');
        case 7 % DERIVED
            header.config.channel_data(ch).device_data.user_space_size = fread(fid, 1, 'uint32=>uint32');
            header.config.channel_data(ch).device_data.reserved        = fread(fid, [1 32], 'uchar=>uchar');
            fseek(fid, 4, 'cof');
        case 8 % SHORTED
            header.config.channel_data(ch).device_data.reserved        = fread(fid, [1 32], 'uchar=>uchar');
        otherwise
            error('Unknown device type: %d\n', header.config.channel_data(ch).type);
    end
end
% Close config file
fclose(fid);

% Build some easy-to-access information
if isfield(header, 'channel_data')
    header.ChannelGain        = double([header.config.channel_data([header.channel_data.chan_no]).gain]');
    header.ChannelUnitsPerBit = double([header.config.channel_data([header.channel_data.chan_no]).units_per_bit]');
end
end

%% ===== HELPER FUNCTIONS =====
% Ensure to be at the beginning of an 8 bytes block
function offset = align_file_pointer(fid)
    current_position = ftell(fid);
    if mod(current_position, 8) ~= 0
        offset = 8 - mod(current_position,8);
        fseek(fid, offset, 'cof');
    else
        offset = 0;
    end
end

%% ===== REMOVED CODE =====
% FOR THE READING OF THE PROCESSES

%    fseek(fid, 32, 'cof'); %needed until next step FIXME make more robust, the total number of read bytes
%    %should be equal to the nbytes computed earlier on
%    if strcmp(header.process(np).step(ns).type, 'PDF_Weight_Table'),
%        warning('reading in weight table: no warranty that this is correct. it seems to work for the Glasgow 248-magnetometer system. if you have some code yourself, and/or would like to test it on your own data, please contact Jan-Mathijs');
%        tmpfp = ftell(fid);
%        tmp   = fread(fid, 1, 'uint8');
%        Nchan = fread(fid, 1, 'uint32');
%        Nref  = fread(fid, 1, 'uint32');
%        for k = 1:Nref
%            header.process(np).step(ns).RefChan{k,1} = deblank(fread(fid, [1 17], 'uchar=>char')); %strange, but true
%        end
%        fseek(fid, 152, 'cof');
%        for k = 1:Nchan
%            header.process(np).step(ns).Chan{k,1} = deblank(fread(fid, [1 17], 'uchar=>char'));
%        end
%        %fseek(fid, 20, 'cof');
%        %fseek(fid, 4216, 'cof');
%        header.process(np).step(ns).stuff1  = fread(fid, 4236, 'uint8');
%        header.process(np).step(ns).Creator = deblank(fread(fid, [1 16], 'uchar=>char'));
%        %some stuff I don't understand yet
%        %fseek(fid, 136, 'cof');
%        header.process(np).step(ns).stuff2  = fread(fid, 136, 'uint8');
%        %now something strange is going to happen: the weights are probably little-endian encoded.
%        %here we go: check whether this applies to the whole PDF weight table
%        fp = ftell(fid);
%        fclose(fid);
%        fid = fopen(datafile, 'r', 'l');
%        fseek(fid, fp, 'bof');
%        for k = 1:Nchan
%            header.process(np).step(ns).Weights(k,:) = fread(fid, [1 23], 'float32=>float32');
%            fseek(fid, 36, 'cof');
%        end
%    else
%    end
        
        
        


