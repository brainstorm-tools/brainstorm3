function sHeader = neuroscan_read_header(NeuroscanFile, fileFormat, isEvents)
% NEUROSCAN_READ_HEADER: Read the header on which all the neuroscan files are bsaed (.avg,.eeg,.cnt,.dat)
%
% USAGE:  sHeader = neuroscan_read_header(NeuroscanFile, fileFormat)  : Full path to a Neuroscan file
%         sHeader = neuroscan_read_header(..., isEvents)              : {0,1}, if 1 read the events structure

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
% Authors: This function is based on code from:
%          - The Bioelectromagnetism toolbox: eeg_load_scan4*.m
%          - EEGLAB: loadcnt.m
%          Francois Tadel, Adaptation for Brainstorm, 2009-2017

%% ===== PARSE INPUTS =====
if (nargin < 2) || isempty(fileFormat)
    fileFormat = 'avg';
end
if (nargin < 3) || isempty(isEvents)
    isEvents = 1;
end

% Open file
fid = fopen(NeuroscanFile, 'r', 'ieee-le');
if (fid == -1)
    error('Could not open file ');
end


%% ===== DATA DESCRIPTION =====
h.rev               = fread(fid,12,'char');
h.nextfile          = fread(fid,1,'long');
h.prevfile          = fread(fid,1,'ulong');
h.type              = fread(fid,1,'char');
h.id                = fread(fid,20,'char');
h.oper              = fread(fid,20,'char');
h.doctor            = fread(fid,20,'char');
h.referral          = fread(fid,20,'char');
h.hospital          = fread(fid,20,'char');
h.patient           = fread(fid,20,'char');
h.age               = fread(fid,1,'short');
h.sex               = fread(fid,1,'char');
h.hand              = fread(fid,1,'char');
h.med               = fread(fid,20, 'char');
h.category          = fread(fid,20, 'char');
h.state             = fread(fid,20, 'char');
h.label             = fread(fid,20, 'char');
h.date              = fread(fid,10, 'char');
h.time              = fread(fid,12, 'char');
h.mean_age          = fread(fid,1,'float');
h.stdev             = fread(fid,1,'float');
h.n                 = fread(fid,1,'short');
h.compfile          = fread(fid,38,'char');
h.spectwincomp      = fread(fid,1,'float');
h.meanaccuracy      = fread(fid,1,'float');
h.meanlatency       = fread(fid,1,'float');
h.sortfile          = fread(fid,46,'char');
h.numevents         = fread(fid,1,'int');
h.compoper          = fread(fid,1,'char');
h.avgmode           = fread(fid,1,'char');
h.review            = fread(fid,1,'char');
h.nsweeps           = fread(fid,1,'ushort');
h.compsweeps        = fread(fid,1,'ushort');
h.acceptcnt         = fread(fid,1,'ushort');
h.rejectcnt         = fread(fid,1,'ushort');
h.pnts              = fread(fid,1,'ushort');
h.nchannels         = fread(fid,1,'ushort');
h.avgupdate         = fread(fid,1,'ushort');
h.domain            = fread(fid,1,'char');
h.variance          = fread(fid,1,'char');
h.rate              = fread(fid,1,'ushort');
h.scale             = fread(fid,1,'double');
h.veogcorrect       = fread(fid,1,'char');
h.heogcorrect       = fread(fid,1,'char');
h.aux1correct       = fread(fid,1,'char');
h.aux2correct       = fread(fid,1,'char');
h.veogtrig          = fread(fid,1,'float');
h.heogtrig          = fread(fid,1,'float');
h.aux1trig          = fread(fid,1,'float');
h.aux2trig          = fread(fid,1,'float');
h.heogchnl          = fread(fid,1,'short');
h.veogchnl          = fread(fid,1,'short');
h.aux1chnl          = fread(fid,1,'short');
h.aux2chnl          = fread(fid,1,'short');
h.veogdir           = fread(fid,1,'char');
h.heogdir           = fread(fid,1,'char');
h.aux1dir           = fread(fid,1,'char');
h.aux2dir           = fread(fid,1,'char');
h.veog_n            = fread(fid,1,'short');
h.heog_n            = fread(fid,1,'short');
h.aux1_n            = fread(fid,1,'short');
h.aux2_n            = fread(fid,1,'short');
h.veogmaxcnt        = fread(fid,1,'short');
h.heogmaxcnt        = fread(fid,1,'short');
h.aux1maxcnt        = fread(fid,1,'short');
h.aux2maxcnt        = fread(fid,1,'short');
h.veogmethod        = fread(fid,1,'char');
h.heogmethod        = fread(fid,1,'char');
h.aux1method        = fread(fid,1,'char');
h.aux2method        = fread(fid,1,'char');
h.ampsensitivity    = fread(fid,1,'float');
h.lowpass           = fread(fid,1,'char');
h.highpass          = fread(fid,1,'char');
h.notch             = fread(fid,1,'char');
h.autoclipadd       = fread(fid,1,'char');
h.baseline          = fread(fid,1,'char');
h.offstart          = fread(fid,1,'float');
h.offstop           = fread(fid,1,'float');
h.reject            = fread(fid,1,'char');
h.rejstart          = fread(fid,1,'float');
h.rejstop           = fread(fid,1,'float');
h.rejmin            = fread(fid,1,'float');
h.rejmax            = fread(fid,1,'float');
h.trigtype          = fread(fid,1,'char');
h.trigval           = fread(fid,1,'float');
h.trigchnl          = fread(fid,1,'char');
h.trigmask          = fread(fid,1,'short');
h.trigisi           = fread(fid,1,'float');
h.trigmin           = fread(fid,1,'float');
h.trigmax           = fread(fid,1,'float');
h.trigdir           = fread(fid,1,'char');
h.autoscale         = fread(fid,1,'char');
h.n2                = fread(fid,1,'short');
h.dir               = fread(fid,1,'char');
h.dispmin           = fread(fid,1,'float');
h.dispmax           = fread(fid,1,'float');
h.xmin              = fread(fid,1,'float');
h.xmax              = fread(fid,1,'float');
h.automin           = fread(fid,1,'float');
h.automax           = fread(fid,1,'float');
h.zmin              = fread(fid,1,'float');
h.zmax              = fread(fid,1,'float');
h.lowcut            = fread(fid,1,'float');
h.highcut           = fread(fid,1,'float');
h.common            = fread(fid,1,'char');
h.savemode          = fread(fid,1,'char');
h.manmode           = fread(fid,1,'char');
h.ref               = fread(fid,10,'char');
h.rectify           = fread(fid,1,'char');
h.displayxmin       = fread(fid,1,'float');
h.displayxmax       = fread(fid,1,'float');
h.phase             = fread(fid,1,'char');
h.screen            = fread(fid,16,'char');
h.calmode           = fread(fid,1,'short');
h.calmethod         = fread(fid,1,'short');
h.calupdate         = fread(fid,1,'short');
h.calbaseline       = fread(fid,1,'short');
h.calsweeps         = fread(fid,1,'short');
h.calattenuator     = fread(fid,1,'float');
h.calpulsevolt      = fread(fid,1,'float');
h.calpulsestart     = fread(fid,1,'float');
h.calpulsestop      = fread(fid,1,'float');
h.calfreq           = fread(fid,1,'float');
h.taskfile          = fread(fid,34,'char');
h.seqfile           = fread(fid,34,'char');
h.spectmethod       = fread(fid,1,'char');
h.spectscaling      = fread(fid,1,'char');
h.spectwindow       = fread(fid,1,'char');
h.spectwinlength    = fread(fid,1,'float');
h.spectorder        = fread(fid,1,'char');
h.notchfilter       = fread(fid,1,'char');
h.headgain          = fread(fid,1,'short');
h.additionalfiles   = fread(fid,1,'int');
h.unused            = fread(fid,5,'char');
h.fspstopmethod     = fread(fid,1,'short');
h.fspstopmode       = fread(fid,1,'short');
h.fspfvalue         = fread(fid,1,'float');
h.fsppoint          = fread(fid,1,'short');
h.fspblocksize      = fread(fid,1,'short');
h.fspp1             = fread(fid,1,'ushort');
h.fspp2             = fread(fid,1,'ushort');
h.fspalpha          = fread(fid,1,'float');
h.fspnoise          = fread(fid,1,'float');
h.fspv1             = fread(fid,1,'short');
h.montage           = fread(fid,40,'char');
h.eventfile         = fread(fid,40,'char');
h.fratio            = fread(fid,1,'float');
h.minor_rev         = fread(fid,1,'char');
h.eegupdate         = fread(fid,1,'short');
h.compressed        = fread(fid,1,'char');
h.xscale            = fread(fid,1,'float');
h.yscale            = fread(fid,1,'float');
h.xsize             = fread(fid,1,'float');
h.ysize             = fread(fid,1,'float');
h.acmode            = fread(fid,1,'char');
h.commonchnl        = fread(fid,1,'uchar');
h.xtics             = fread(fid,1,'char');
h.xrange            = fread(fid,1,'char');
h.ytics             = fread(fid,1,'char');
h.yrange            = fread(fid,1,'char');
h.xscalevalue       = fread(fid,1,'float');
h.xscaleinterval    = fread(fid,1,'float');
h.yscalevalue       = fread(fid,1,'float');
h.yscaleinterval    = fread(fid,1,'float');
h.scaletoolx1       = fread(fid,1,'float');
h.scaletooly1       = fread(fid,1,'float');
h.scaletoolx2       = fread(fid,1,'float');
h.scaletooly2       = fread(fid,1,'float');
h.port              = fread(fid,1,'short');
h.numsamples        = fread(fid,1,'ulong');
h.filterflag        = fread(fid,1,'char');
h.lowcutoff         = fread(fid,1,'float');
h.lowpoles          = fread(fid,1,'short');
h.highcutoff        = fread(fid,1,'float');
h.highpoles         = fread(fid,1,'short');
h.filtertype        = fread(fid,1,'char');
h.filterdomain      = fread(fid,1,'char');
h.snrflag           = fread(fid,1,'char');
h.coherenceflag     = fread(fid,1,'char');
h.continuoustype    = fread(fid,1,'char');
h.eventtablepos     = fread(fid,1,'ulong');
h.continuousseconds = fread(fid,1,'float');
h.channeloffset     = fread(fid,1,'long');
h.autocorrectflag   = fread(fid,1,'char');
h.dcthreshold       = fread(fid,1,'uchar');


%% ===== CHANNELS =====
% disp([10 'Electrodes in this file:']);
for n = 1:h.nchannels
    e(n).lab            = deblank(strtrim(char(fread(fid,10,'char')')));
    e(n).reference      = fread(fid,1,'char');
    e(n).skip           = fread(fid,1,'char');
    e(n).reject         = fread(fid,1,'char');
    e(n).display        = fread(fid,1,'char');
    e(n).bad            = fread(fid,1,'char');
    e(n).n              = fread(fid,1,'ushort');
    e(n).avg_reference  = fread(fid,1,'char');
    e(n).clipadd        = fread(fid,1,'char');
    e(n).x_coord        = fread(fid,1,'float');
    e(n).y_coord        = fread(fid,1,'float');
    e(n).veog_wt        = fread(fid,1,'float');
    e(n).veog_std       = fread(fid,1,'float');
    e(n).snr            = fread(fid,1,'float');
    e(n).heog_wt        = fread(fid,1,'float');
    e(n).heog_std       = fread(fid,1,'float');
    e(n).baseline       = fread(fid,1,'short');
    e(n).filtered       = fread(fid,1,'char');
    e(n).fsp            = fread(fid,1,'char');
    e(n).aux1_wt        = fread(fid,1,'float');
    e(n).aux1_std       = fread(fid,1,'float');
    e(n).sensitivity    = fread(fid,1,'float');
    e(n).gain           = fread(fid,1,'char');
    e(n).hipass         = fread(fid,1,'char');
    e(n).lopass         = fread(fid,1,'char');
    e(n).page           = fread(fid,1,'uchar');
    e(n).size           = fread(fid,1,'uchar');
    e(n).impedance      = fread(fid,1,'uchar');
    e(n).physicalchnl   = fread(fid,1,'uchar');
    e(n).rectify        = fread(fid,1,'char');
    e(n).calib          = fread(fid,1,'float');
end
h.datapos = ftell(fid);


%% ===== DETECT DATA FORMAT =====
% Compute the event table offset: prevfile contains high order bits of event table offset, eventtablepos contains the low order bits
EVT_offset = (double(h.prevfile) * (2^32)) + double(h.eventtablepos);
% Try to find something better: depends on the data format
switch lower(fileFormat)
    case 'cnt'
        % Estimate data format
        nbVal = h.nchannels * h.numsamples;
        nbPos = EVT_offset - h.datapos;
        h.bytes_per_samp = nbPos / nbVal;
        % If this method doesn't work
        if ~ismember(h.bytes_per_samp, [2,4])
            if (h.nextfile > 0)
                fseek(fid,h.nextfile + 52,'bof');
                is32bit = fread(fid,1,'char');
                if (is32bit == 1)
                    h.bytes_per_samp = 4;
                else
                    h.bytes_per_samp = 2;
                end
            else
                % By default: 32bits
                h.bytes_per_samp = 4;
                % Display warning in the command window
                warning('Wrong number of samples in the header or unknown file format... Assuming file in int32.');
            end
            % Recompute the number of available samples
            h.numsamples = floor((EVT_offset - h.datapos) / h.bytes_per_samp / h.nchannels);
        end
        switch (h.bytes_per_samp)
            case 2,  h.dataformat = 'int16';
            case 4,  h.dataformat = 'int32';
        end
    case 'avg'
        h.bytes_per_samp = 2;
        h.dataformat = 'float';
    case 'eeg'
        sizeHeader = 13;
        h.bytes_per_samp = floor(((EVT_offset - h.datapos) / h.compsweeps - sizeHeader) / h.pnts / h.nchannels);
        if (h.bytes_per_samp == 2)
            h.dataformat = 'int16';
        elseif (h.bytes_per_samp >= 4)
            h.dataformat = 'int32';
            h.bytes_per_samp = 4;
        else
            error('Unknown file format.');
        end
        h.epoch_size = h.nchannels * h.pnts * h.bytes_per_samp + sizeHeader;
    otherwise
        error('Unknown data format');
end


%% ===== EPOCHS =====
epochs = [];
% Only available for epoched files
if strcmpi(fileFormat, 'eeg')
    nEpochs = h.compsweeps;
    % Read the headers of all the sweeps
    for i = 1:nEpochs
        % Position cursor in file to read this data block
        pos = h.datapos + (i - 1) * h.epoch_size;
        fseek(fid, double(pos), 'bof');
        % Read sweeps header	
        epochs(i).accept   = fread(fid, 1, 'char');     % 1 byte
        epochs(i).type     = fread(fid, 1, 'short');    % 2 bytes
        epochs(i).correct  = fread(fid, 1, 'short');    % 2 bytes
        epochs(i).rt       = fread(fid, 1, 'float32');  % 4 bytes
        epochs(i).response = fread(fid, 1, 'short');    % 2 bytes
        epochs(i).reserved = fread(fid, 1, 'short');    % 2 bytes. Total = 13 bytes
        % Information about data block
        epochs(i).datasize = [h.nchannels, h.pnts];
        epochs(i).datapos  = ftell(fid);
    end
    
    % Create comments for epochs
    isAllSameType = (length(unique([epochs.type])) <= 1);
    isAllSameResp = (length(unique([epochs.response])) <= 1);
    for i = 1:nEpochs
        if (epochs(i).type > 0) && ~isAllSameType
            epochs(i).comment = sprintf('Event #%d (#%03d)', epochs(i).type, i);
        elseif (epochs(i).response > 0) && ~isAllSameResp
            epochs(i).comment = sprintf('Response #%d (#%03d)', epochs(i).response, i);
        else
            epochs(i).comment = sprintf('Epoch #%03d', i);
        end
    end
end


%% ===== EVENTS =====
evt = [];
rej = [];
if isEvents
    EventsFile = deblank(strtrim(char(h.eventfile')));
    if ~isempty(EventsFile) && file_exist(EventsFile)
        error('Event files: Not supported yet.');
    elseif (h.numevents > 0)
        % Go at the beginning of events block
        fseek(fid, EVT_offset, 'bof');
        % Read events table header
        evtType   = fread(fid,1,'uchar');
        evtSize   = fread(fid,1,'ulong');
        evtOffset = fread(fid,1,'ulong');
        % Move forward in the file
        fseek(fid, double(evtOffset), 'cof');
        
        % Check event type
        if ~ismember(evtType, [1,2,3])
            error(sprintf('Invalid event type: %d', evtType));
        end
        % Define size of each event block
        sizeEvents = [8, 19, 19];
        nEvents = evtSize / sizeEvents(evtType);
        % Initialize events structure
        evt = repmat(struct(), [1 nEvents]);
        % Offset for frame positions (header + electordes desc)
        samplespos = 900 + 75 * h.nchannels;

        % Read all events
        for i=1:nEvents
            % Read information common to all events
            evt(i).stimtype = fread(fid,1,'ushort');
            evt(i).keyboard = fread(fid,1,'char');
            % evt(i).keyPad   = fread(fid,1,'bit4');
            % evt(i).Accept   = fread(fid,1,'bit4');
            temp            = fread(fid,1,'uint8');
            evt(i).keyPad   = bitand(15,temp);
            evt(i).Accept   = bitshift(temp,-4);

            % Switch between different types of events
            switch(evtType)
                case 1
                    offset = fread(fid,1,'long');
                    evt(i).offset = offset - samplespos;
                case 2
                    offset = fread(fid,1,'long');
                    evt(i).offset     = offset - samplespos;
                    evt(i).type       = fread(fid,1,'short');
                    evt(i).code       = fread(fid,1,'short');
                    evt(i).latency    = fread(fid,1,'float');
                    evt(i).epochevent = fread(fid,1,'char');
                    evt(i).accept     = fread(fid,1,'char');
                    evt(i).accuracy   = fread(fid,1,'char');
                case 3
                    % Type 3 is similar to type 2 except the offset field encodes the global sample frame
                    offset            = fread(fid,1,'ulong');
                    evt(i).offset     = offset * h.bytes_per_samp * h.nchannels;
                    evt(i).type       = fread(fid,1,'short');
                    evt(i).code       = fread(fid,1,'short');
                    evt(i).latency    = fread(fid,1,'float');
                    evt(i).epochevent = fread(fid,1,'char');
                    evt(i).accept     = fread(fid,1,'char');
                    evt(i).accuracy   = fread(fid,1,'char');
            end
            
            % ===============================================================
            % ===== WARNING: THERE IS SOMETHING WRONG AT THIS POINT....
            % ===== Error in offset value, something is missing, there is sometimes a 
            % ===== weird additional factor to get an integer value
            % ===== Its value is not constant.... sometimes it is 39, sometimes 16...
            % =====
            % ===== The "round" helps ignoring this problem, but don't make things clean
            % ===============================================================
            % Rebuild time index
            evt(i).iTime = evt(i).offset / h.bytes_per_samp / h.nchannels;
            % Check that samples indices are integers
            if any(evt(i).iTime ~= round(evt(i).iTime))
                evt(i).iTime = round(evt(i).iTime);
                warning('Samples indices are not integers...');
            end
        end      
        
        % === REJECTED SEGMENTS ===
        % Get the beginning and end of the rejected segments
        iStarts = find([evt.Accept] == 12);
        iStops  = find([evt.Accept] == 13);
        % Check numbers of bounds
        if (length(iStarts) ~= length(iStops))
            warning('Corrupted bad segments definition. Ignoring...');
        elseif ~isempty(iStarts)
            % Build rejected segments matrix
            rej = [evt(iStarts).iTime; evt(iStops).iTime]';
        end
    end
end


%% ===== RETURN STRUCTURE =====
% Read tag (last char in the file)
fseek(fid, -1, 'eof');
tag = fread(fid,'char');

% Build final structure
sHeader.data     = h;
sHeader.electloc = e;
sHeader.events   = evt;
sHeader.tag      = tag;
sHeader.epochs   = epochs;
sHeader.rejected_segments = rej;
sHeader.fileFormat = fileFormat;

% Close file
fclose(fid);




