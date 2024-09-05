function [sFile, ChannelMat] = in_fopen_bst(DataFile)
% IN_FOPEN_BST: Open a Brainstorm binary file
%
% USAGE:  [sFile, ChannelMat] = in_fopen_bst(DataFile)

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
% Authors: Francois Tadel, 2014-2019; Martin Cousineau, 2018
        

%% ===== READ HEADER =====
% Initialize returned structures

ChannelMat = db_template('channelmat');
% Open file
fid = fopen(DataFile, 'r', 'ieee-le');
if (fid == -1)
    error('Could not open file');
end


% ===== FORMAT HEADER =====
magic = fread(fid, [1 6], '*char');                           % CHAR(6)    : Format
if ~isequal(magic, 'BSTBIN')
    error('File is not a valid Brainstorm binary file.');
end
hdr.version   = fread(fid, [1 1], 'uint8');                   % UINT8(1)   : Version of the format, starting at uint8('1') = 49 for legacy reasons
hdr.device    = str_read(fid, 40);                            % CHAR(40)   : Device used for recording
hdr.sfreq     = double(fread(fid, [1 1], 'float32'));         % FLOAT32(1) : Sampling frequency
hdr.starttime = double(fread(fid, [1 1], 'float32'));         % FLOAT32(1) : Start time
hdr.navg      = double(fread(fid, [1 1], 'uint32'));          % UINT32(1)  : Number of files averaged
hdr.ctfcomp   = double(fread(fid, [1 1], 'uint8'));           % UINT8(1)   : CTF compensation status (0,1,2,3)
hdr.nsamples  = fread(fid, [1 1], 'uint32');                  % UINT32(1)  : Total number of samples
hdr.epochsize = double(fread(fid, [1 1], 'uint32'));          % UINT32(1)  : Number of samples per epoch
hdr.nchannels = double(fread(fid, [1 1], 'uint32'));          % UINT32(1)  : Number of channels

% ===== CHECK WHETHER VERSION IS SUPPORTED =====
if (hdr.version > 53)
    error(['The selected version of the BST format is currently not supported.' ...
           10 'Please update Brainstorm.']);
end

% ===== CHANNEL LOCATIONS =====
ChannelMat.Comment = str_read(fid, 40);                                     % CHAR(40)   : Channel file comment
ChannelMat.Channel = repmat(db_template('channeldesc'), [1, hdr.nchannels]);
ChannelFlag = zeros(hdr.nchannels, 1);
for i = 1:length(ChannelMat.Channel)
    ChannelMat.Channel(i).Name    = str_read(fid, 20);                      % CHAR(20)   : Channel name
    ChannelMat.Channel(i).Type    = str_read(fid, 20);                      % CHAR(20)   : Channel type
    ChannelMat.Channel(i).Comment = str_read(fid, 40);                      % CHAR(40)   : Channel comment
    % Loc
    nloc = double(fread(fid, [1 1], 'uint8'));                              % UINT8(1)   : Number of location points
    if (nloc > 0)
        ChannelMat.Channel(i).Loc = double(fread(fid, [3 nloc], 'float32'));% FLOAT32(N) : Locations [3xN]          
    end
    % Orient
    nloc = double(fread(fid, [1 1], 'uint8'));                              % UINT8(1)   : Number of orientations points
    if (nloc > 0)
        ChannelMat.Channel(i).Orient = fread(fid, [3 nloc], 'float32');     % FLOAT32(N) : Orientations [3xN]
    end
    % Weight
    nloc = double(fread(fid, [1 1], 'uint8'));                              % UINT8(1)   : Number of weights
    if (nloc > 0)
        ChannelMat.Channel(i).Weight = fread(fid, [1 nloc], 'float32');     % FLOAT32(N) : Weights [1xN]
    end
    % Channel flag
    ChannelFlag(i) = double(fread(fid, [1 1], 'int8'));                     % INT8(1)    : Channel flag
end

% ===== CTF =====
% CTF compensation matrix
sizemat = double(fread(fid, [1 2], 'uint32'));                                     % UINT32(2)  : Dimensions of the MegRefCoef matrix
if (prod(sizemat) > 0)
    ChannelMat.MegRefCoef = double(fread(fid, sizemat, 'float32'));                % FLOAT32(N) : MegRefCoef matrix
end

% ===== SSP PROJECTORS =====
nproj = double(fread(fid, [1 1], 'uint32'));                                       % UINT32(1)  : Number of projectors
ChannelMat.Projector = repmat(db_template('Projector'), [1, nproj]);
for i = 1:nproj
    ChannelMat.Projector(i).Comment = str_read(fid, 40);                           % CHAR(40)   : Projector comment
    sizemat = double(fread(fid, [1 2], 'uint32'));                                 % UINT32(2)  : Dimensions of the Components matrix
    ChannelMat.Projector(i).Components = double(fread(fid, sizemat, 'float32'));   % FLOAT32(N) : Components matrix
    sizemat = double(fread(fid, [1 2], 'uint32'));                                 % UINT32(2)  : Dimensions of the CompMask matrix
    ChannelMat.Projector(i).CompMask = double(fread(fid, sizemat, 'float32'));     % FLOAT32(N) : CompMask matrix
    sizemat = double(fread(fid, [1 2], 'uint32'));                                 % UINT32(2)  : Dimensions of the SingVal matrix
    if (prod(sizemat) > 0)
        ChannelMat.Projector(i).SingVal = double(fread(fid, sizemat, 'float32'));  % FLOAT32(N) : SingVal matrix
        % If SingVal contains a string: Convert to string
        if (length(ChannelMat.Projector(i).SingVal) == 3) && (isequal(char(ChannelMat.Projector(i).SingVal), 'ICA') || isequal(char(ChannelMat.Projector(i).SingVal), 'REF'))
            ChannelMat.Projector(i).SingVal = char(ChannelMat.Projector(i).SingVal);
        end
    end
    ChannelMat.Projector(i).Status = double(fread(fid, [1 1], 'int8'));            % INT8(1)    : Status
    % September 2024: Added char array for projector method
    if hdr.version >= 53
        ChannelMat.Projector(i).Method = str_read(fid, 20);                        % CHAR(20)   : Projector method
    end
    % Complete projector method if necesary
    ChannelMat.Projector(i) = process_ssp2('ConvertOldFormat', ChannelMat.Projector(i));
end

% ===== HEAD POINTS =====
npt = double(fread(fid, [1 1], 'uint32'));                                         % UINT32(1)  : Number of head points
for i = 1:npt
    ChannelMat.HeadPoints.Loc(:,i) = double(fread(fid, [3,1], 'float32'));         % FLOAT32(3) : (X,Y,Z) positions in meters
    ChannelMat.HeadPoints.Label{i} = str_read(fid, 10);                            % CHAR(10)   : Point label
    ChannelMat.HeadPoints.Type{i}  = str_read(fid, 10);                            % CHAR(10)   : Point type
end

% ===== FIDUCIALS =====
isfid = double(fread(fid, [1 1], 'int8'));                                     % INT8(1)    : Are the fiducials saved in the file?
if isfid
    ChannelMat.SCS.NAS = double(fread(fid, [3,1], 'float32'));                 % FLOAT32(3) : NAS (X,Y,Z) positions in meters
    ChannelMat.SCS.LPA = double(fread(fid, [3,1], 'float32'));                 % FLOAT32(3) : LPA (X,Y,Z) positions in meters
    ChannelMat.SCS.RPA = double(fread(fid, [3,1], 'float32'));                 % FLOAT32(3) : RPA (X,Y,Z) positions in meters
    ChannelMat.SCS.R   = double(fread(fid, [3,3], 'float32'));                 % FLOAT32(9) : Rotation matrix [3x3] 
    ChannelMat.SCS.T   = double(fread(fid, [3,1], 'float32'));                 % FLOAT32(3) : Translation vector [3x1]
    ChannelMat.SCS.Origin = double(fread(fid, [3,1], 'float32'));              % FLOAT32(3) : Origin (X,Y,Z) positions in meters
end

% ===== EVENTS =====
nevt = double(fread(fid, [1 1], 'uint32'));                         % UINT32(1)  : Number of event categories
events = repmat(db_template('event'), [1, nevt]);
for iEvt = 1:nevt
    if (hdr.version < 50)
        labelLength = 20;
    else
        labelLength = fread(fid, [1 1], 'uint8');                   % UINT8(1)   : Length of event name (1 to 255)
    end
    events(iEvt).label = str_read(fid, labelLength);                   % CHAR(??)   : Event name
    events(iEvt).color = double(fread(fid, [1,3], 'float32'));         % FLOAT32(3) : Event color
    isExtended  = fread(fid, [1 1], 'int8');                        % INT8(1)    : Event type (0=regular, 1=extended)
    nOcc = double(fread(fid, [1 1], 'uint32'));                     % UINT32(1)  : Number of occurrences
    if isExtended
        events(iEvt).times = double(fread(fid, [2,nOcc], 'float32'));  % FLOAT32(2N): Time in seconds
    else
        events(iEvt).times = double(fread(fid, [1,nOcc], 'float32'));  % FLOAT32(2N): Time in seconds
    end
    % Rebuild missing information
    events(iEvt).epochs = ones(1, nOcc);
    % April 2019: Channels and notes are added to events
    if (hdr.version >= 51)
        % March 2023: Added boolean to check if the channel list is present
        if (hdr.version >= 52)
            isChannels = fread(fid, [1 1], 'uint8');
        else
            isChannels = 1;
        end
        % Read list of channels associated to each event
        if isChannels
            events(iEvt).channels = cell(1, nOcc);
            for iOcc = 1:nOcc
                nChannels = fread(fid, [1 1], 'uint16');                   % UINT16(1) : Number of channels associated to this event
                events(iEvt).channels{iOcc} = cell(1, nChannels);
                for iChan = 1:nChannels
                    labelLength = fread(fid, [1 1], 'uint8');                          % UINT8(1) : Length of channel name (1 to 255)
                    events(iEvt).channels{iOcc}{iChan} = str_read(fid, labelLength);   % CHAR(??) : Channel name
                end
            end
        end
        % March 2023: Added boolean to check if the notes list is present
        if (hdr.version >= 52)
            isNotes = fread(fid, [1 1], 'uint8');
        else
            isNotes = 1;
        end
        % Read list of notes associated to each event
        if isNotes
            events(iEvt).notes = cell(1, nOcc);
            for iOcc = 1:nOcc
                labelLength = fread(fid, [1 1], 'uint16');               % UINT16(1) : Length of note text
                events(iEvt).notes{iOcc} = str_read(fid, labelLength);   % CHAR(??) : Note text
            end
        end
    end
end

% Save total header size (to allow fast skipping when reading)
hdr.hdrsize = ftell(fid);
% Close file
fclose(fid);


%% ===== CREATE BRAINSTORM SFILE STRUCTURE =====
[fPath, fBase, fExt] = bst_fileparts(DataFile);
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.filename     = DataFile;
sFile.format       = 'BST-BIN';
sFile.byteorder    = 'l';
sFile.comment      = fBase;
sFile.events       = events;
sFile.header       = hdr;
sFile.channelflag  = ChannelFlag;
sFile.prop.sfreq   = hdr.sfreq;
sFile.prop.times   = (round(hdr.starttime .* hdr.sfreq) + [0, hdr.nsamples-1]) ./ hdr.sfreq;
sFile.prop.nAvg    = hdr.navg;
sFile.prop.currCtfComp = hdr.ctfcomp;
sFile.prop.destCtfComp = 3;

end


%% ===== READ STRING =====
function s = str_read(fid, N)
    % Nothing to read, return empty string
    if (N == 0)
        s = '';
    end
    % Read string
    s = fread(fid, [1 N], '*uint8');
    % Remove zeros
    s(s == 0) = [];
    % Convert to string
    s = strtrim(char(s));
end


