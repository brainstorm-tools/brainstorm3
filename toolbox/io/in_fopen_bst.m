function [sFile, ChannelMat] = in_fopen_bst(DataFile)
% IN_FOPEN_BST: Open a Brainstorm binary file
%
% USAGE:  [sFile, ChannelMat] = in_fopen_bst(DataFile)

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
% Authors: Francois Tadel, 2014-2015
        

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
hdr.version   = fread(fid, [1 1], '*char');                   % CHAR(1)    : Version of the format
hdr.device    = str_read(fid, 40);                            % CHAR(40)   : Device used for recording
hdr.sfreq     = double(fread(fid, [1 1], 'float32'));         % FLOAT32(1) : Sampling frequency
hdr.starttime = double(fread(fid, [1 1], 'float32'));         % FLOAT32(1) : Start time
hdr.navg      = double(fread(fid, [1 1], 'uint32'));          % UINT32(1)  : Number of files averaged
hdr.ctfcomp   = double(fread(fid, [1 1], 'uint8'));           % UINT8(1)   : CTF compensation status (0,1,2,3)
hdr.nsamples  = fread(fid, [1 1], 'uint32');                  % UINT32(1)  : Total number of samples
hdr.epochsize = double(fread(fid, [1 1], 'uint32'));          % UINT32(1)  : Number of samples per epoch
hdr.nchannels = double(fread(fid, [1 1], 'uint32'));          % UINT32(1)  : Number of channels

% ===== CHECK WHETHER VERSION IS SUPPORTED =====
if hdr.version ~= '1'
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
for i = 1:nevt
    events(i).label = str_read(fid, 20);                            % CHAR(20)   : Event name
    events(i).color = double(fread(fid, [1,3], 'float32'));         % FLOAT32(3) : Event color
    isExtended  = fread(fid, [1 1], 'int8');                        % INT8(1)    : Event type (0=regular, 1=extended)
    nocc = double(fread(fid, [1 1], 'uint32'));                     % UINT32(1)  : Number of occurrences
    if isExtended
        events(i).times = double(fread(fid, [2,nocc], 'float32'));  % FLOAT32(2N): Time in seconds
    else
        events(i).times = double(fread(fid, [1,nocc], 'float32'));  % FLOAT32(2N): Time in seconds
    end
    % Rebuild missing information
    events(i).epochs  = ones(1, nocc);
    events(i).samples = round(events(i).times .* hdr.sfreq);
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
sFile.prop.samples = round(hdr.starttime .* hdr.sfreq) + [0, hdr.nsamples-1];
sFile.prop.times   = sFile.prop.samples ./ hdr.sfreq;
sFile.prop.nAvg    = hdr.navg;
sFile.prop.currCtfComp = hdr.ctfcomp;
sFile.prop.destCtfComp = 3;

end


%% ===== READ STRING =====
function s = str_read(fid, N)
    % Read string
    s = fread(fid, [1 N], '*uint8');
    % Remove zeros
    s(s == 0) = [];
    % Convert to string
    s = strtrim(char(s));
end


