function sFileOut = out_fopen_bst(OutputFile, sFileIn, ChannelMat, EpochSize)
% OUT_FOPEN_BST: Saves the header of a new empty Brainstorm binary file.

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

% Get file comment
[fPath, fBase, fExt] = bst_fileparts(OutputFile);

% Create a new header structure
sFileOut = sFileIn;
sFileOut.filename  = OutputFile;
sFileOut.condition = '';
sFileOut.format    = 'BST-BIN';
sFileOut.byteorder = 'l';
sFileOut.comment   = fBase;
sFileOut.header    = struct();
sFileOut.header.device    = sFileOut.device;
sFileOut.header.sfreq     = sFileOut.prop.sfreq;
sFileOut.header.starttime = sFileOut.prop.times(1);
sFileOut.header.navg      = sFileOut.prop.nAvg;
% sFileOut.header.version   = 51;   % April 2019
% sFileOut.header.version   = 52;   % March 2023
sFileOut.header.version   = 53;   % September 2024
sFileOut.header.nsamples  = round((sFileOut.prop.times(2) - sFileOut.prop.times(1)) .* sFileOut.prop.sfreq) + 1;
sFileOut.header.epochsize = EpochSize;
sFileOut.header.nchannels = length(ChannelMat.Channel);
% Force the destination compensation level
sFileOut.prop.currCtfComp = sFileOut.prop.destCtfComp;  
sFileOut.header.ctfcomp   = sFileOut.prop.destCtfComp;
% Open file
fid = fopen(OutputFile, 'w+', sFileOut.byteorder);
if (fid == -1)
    error(['Could not open output file: "' OutputFile '".']);
end

% ===== FORMAT HEADER =====
fwrite(fid, 'BSTBIN', 'char');                               % CHAR(6)    : Format
fwrite(fid, sFileOut.header.version, 'uint8');               % UINT8(1)   : Version of the format
fwrite(fid, str_zeros(sFileOut.header.device, 40), 'char');  % CHAR(40)   : Device used for recording
fwrite(fid, sFileOut.header.sfreq, 'float32');               % UINT32(1)  : Sampling frequency
fwrite(fid, sFileOut.header.starttime, 'float32');           % FLOAT32(1) : Start time
fwrite(fid, sFileOut.header.navg, 'uint32');                 % UINT32(1)  : Number of files averaged
if ~isempty(sFileOut.header.ctfcomp)
    fwrite(fid, sFileOut.header.ctfcomp, 'uint8');           % UINT8(1)   : CTF compensation status (0,1,2,3)
else
    fwrite(fid, 0, 'uint8');
end
fwrite(fid, sFileOut.header.nsamples, 'uint32');             % UINT32(1)  : Total number of samples
fwrite(fid, sFileOut.header.epochsize, 'uint32');            % UINT32(1)  : Number of samples per epoch
fwrite(fid, sFileOut.header.nchannels, 'uint32');            % UINT32(1)  : Number of channels

% ===== CHANNEL LOCATIONS =====
fwrite(fid, str_zeros(ChannelMat.Comment, 40), 'char');                 % CHAR(40)   : Channel file comment
for i = 1:length(ChannelMat.Channel)
    fwrite(fid, str_zeros(ChannelMat.Channel(i).Name, 20), 'char');     % CHAR(20)   : Channel name
    fwrite(fid, str_zeros(ChannelMat.Channel(i).Type, 20), 'char');     % CHAR(20)   : Channel type
    fwrite(fid, str_zeros(ChannelMat.Channel(i).Comment, 40), 'char');  % CHAR(40)   : Channel comment
    % Loc
    fwrite(fid, size(ChannelMat.Channel(i).Loc, 2), 'uint8');           % UINT8(1)   : Number of location points
    if ~isempty(ChannelMat.Channel(i).Loc)
        fwrite(fid, ChannelMat.Channel(i).Loc, 'float32');              % FLOAT32(N) : Locations [3xN]
    end
    % Orient
    fwrite(fid, size(ChannelMat.Channel(i).Orient, 2), 'uint8');        % UINT8(1)   : Number of orientations points
    if ~isempty(ChannelMat.Channel(i).Orient)
        fwrite(fid, ChannelMat.Channel(i).Orient, 'float32');           % FLOAT32(N) : Orientations [3xN]
    end
    % Weight
    fwrite(fid, length(ChannelMat.Channel(i).Weight), 'uint8');         % UINT8(1)   : Number of weights
    if ~isempty(ChannelMat.Channel(i).Weight)
        fwrite(fid, ChannelMat.Channel(i).Weight, 'float32');           % FLOAT32(N) : Weights [1xN]
    end
    % Channel flag
    fwrite(fid, sFileIn.channelflag(i), 'int8');                        % INT8(1)    : Channel flag
end

% ===== CTF =====
% CTF compensation matrix
fwrite(fid, size(ChannelMat.MegRefCoef), 'uint32');                     % UINT32(2)  : Dimensions of the MegRefCoef matrix
fwrite(fid, ChannelMat.MegRefCoef, 'float32');                          % FLOAT32(N) : MegRefCoef matrix

% ===== SSP PROJECTORS =====
fwrite(fid, length(ChannelMat.Projector), 'uint32');                      % UINT32(1)  : Number of projectors
for i = 1:length(ChannelMat.Projector)
    fwrite(fid, str_zeros(ChannelMat.Projector(i).Comment, 40), 'char');  % CHAR(40)   : Projector comment
    fwrite(fid, size(ChannelMat.Projector(i).Components), 'uint32');      % UINT32(2)  : Dimensions of the Components matrix
    fwrite(fid, ChannelMat.Projector(i).Components, 'float32');           % FLOAT32(N) : Components matrix
    fwrite(fid, size(ChannelMat.Projector(i).CompMask), 'uint32');        % UINT32(2)  : Dimensions of the CompMask matrix
    fwrite(fid, ChannelMat.Projector(i).CompMask, 'float32');             % FLOAT32(N) : CompMask matrix
    fwrite(fid, size(ChannelMat.Projector(i).SingVal), 'uint32');         % UINT32(2)  : Dimensions of the SingVal matrix
    if ~isempty(ChannelMat.Projector(i).SingVal)
        fwrite(fid, ChannelMat.Projector(i).SingVal, 'float32');          % FLOAT32(N) : SingVal matrix
    end
    fwrite(fid, ChannelMat.Projector(i).Status, 'int8');                  % INT8(1)    : Status
    fwrite(fid, str_zeros(ChannelMat.Projector(i).Method, 20), 'char');   % CHAR(20)   : Projector method
end

% ===== HEAD POINTS =====
if ~isempty(ChannelMat.HeadPoints)
    fwrite(fid, length(ChannelMat.HeadPoints.Label), 'uint32');              % UINT32(1)  : Number of head points
    for i = 1:length(ChannelMat.HeadPoints.Label)
        fwrite(fid, ChannelMat.HeadPoints.Loc(:,i), 'float32');              % FLOAT32(3) : (X,Y,Z) positions in meters
        fwrite(fid, str_zeros(ChannelMat.HeadPoints.Label{i}, 10), 'char');  % CHAR(10)   : Point label
        fwrite(fid, str_zeros(ChannelMat.HeadPoints.Type{i}, 10), 'char');   % CHAR(10)   : Point type
    end
else
    fwrite(fid, 0, 'uint32');
end

% ===== FIDUCIALS =====
% Write fiducials positions (SCS)
if isfield(ChannelMat, 'SCS') && ~isempty(ChannelMat.SCS) ...
&& isfield(ChannelMat.SCS, 'NAS') && (length(ChannelMat.SCS.NAS) == 3) ...
&& isfield(ChannelMat.SCS, 'LPA') && (length(ChannelMat.SCS.LPA) == 3) ...
&& isfield(ChannelMat.SCS, 'RPA') && (length(ChannelMat.SCS.RPA) == 3) ...
&& isfield(ChannelMat.SCS, 'R')   && isequal(size(ChannelMat.SCS.R), [3,3]) ...
&& isfield(ChannelMat.SCS, 'T')   && (length(ChannelMat.SCS.T) == 3) ...
&& isfield(ChannelMat.SCS, 'Origin') && (length(ChannelMat.SCS.Origin) == 3)
    fwrite(fid, 1, 'int8');                                                  % INT8(1)    : Are the fiducials saved in the file?
    fwrite(fid, ChannelMat.SCS.NAS, 'float32');                              % FLOAT32(3) : NAS (X,Y,Z) positions in meters
    fwrite(fid, ChannelMat.SCS.LPA, 'float32');                              % FLOAT32(3) : LPA (X,Y,Z) positions in meters
    fwrite(fid, ChannelMat.SCS.RPA, 'float32');                              % FLOAT32(3) : RPA (X,Y,Z) positions in meters
    fwrite(fid, ChannelMat.SCS.R, 'float32');                                % FLOAT32(9) : Rotation matrix [3x3] 
    fwrite(fid, ChannelMat.SCS.T, 'float32');                                % FLOAT32(3) : Translation vector [3x1]
    fwrite(fid, ChannelMat.SCS.Origin, 'float32');                           % FLOAT32(3) : Origin (X,Y,Z) positions in meters
else
    fwrite(fid, 0, 'int8');                                                  % INT8(1)    : Are the fiducials saved in the file?
end

% ===== EVENTS =====
fwrite(fid, length(sFileOut.events), 'uint32');                              % UINT32(1)  : Number of event categories
for iEvt = 1:length(sFileOut.events)
    isExtended = (size(sFileOut.events(iEvt).times,1) == 2);
    evtLabel = sFileOut.events(iEvt).label;
    labelLength = length(evtLabel);
    nOcc = size(sFileOut.events(iEvt).times,2);
    fwrite(fid, labelLength, 'uint8');                                       % UINT8(1)   : Length of event name (1 to 255)
    fwrite(fid, str_zeros(evtLabel, labelLength), 'char');                   % CHAR(??)   : Event name
    fwrite(fid, sFileOut.events(iEvt).color, 'float32');                     % FLOAT32(3) : Event color
    fwrite(fid, isExtended, 'int8');                                         % INT8(1)    : Event type (0=regular, 1=extended)
    fwrite(fid, nOcc, 'uint32');                                             % UINT32(1)  : Number of occurrences
    % If there are event occurrences
    if ~isempty(sFileOut.events(iEvt).times)
        % Write latencies
        fwrite(fid, sFileOut.events(iEvt).times, 'float32');                 % FLOAT32(2*N) : Time in seconds
        % Write list of channels associated to each event
        isChannels = ~isempty(sFileOut.events(iEvt).channels);
        fwrite(fid, uint8(isChannels), 'uint8');                             % UINT8(1) : 1 if channels list is present, 0 otherwise
        if isChannels
            for iOcc = 1:nOcc
                nChannels = length(sFileOut.events(iEvt).channels{iOcc});
                fwrite(fid, nChannels, 'uint16');                            % UINT16(1) : Number of channels associated to this event
                for iChan = 1:nChannels
                    chLabel = sFileOut.events(iEvt).channels{iOcc}{iChan};
                    labelLength = length(chLabel);
                    fwrite(fid, labelLength, 'uint8');                       % UINT8(1) : Length of channel name (1 to 255)
                    fwrite(fid, str_zeros(chLabel, labelLength), 'char');    % CHAR(??) : Channel name
                end
            end
        end
        % Read list of notes associated to each event
        isNotes = ~isempty(sFileOut.events(iEvt).notes);
        fwrite(fid, uint8(isNotes), 'uint8');                                % UINT8(1) : 1 if notes list is present, 0 otherwise
        if isNotes
            for iOcc = 1:nOcc
                noteLabel = sFileOut.events(iEvt).notes{iOcc};
                labelLength = length(noteLabel);
                fwrite(fid, labelLength, 'uint16');                          % UINT16(1) : Length of note text
                fwrite(fid, str_zeros(noteLabel, labelLength), 'char');      % CHAR(??) : Note text
            end
        end
    end
end

% Save total header size (to allow fast skipping when reading)
sFileOut.header.hdrsize = ftell(fid);
% Close file
fclose(fid);

end


%% ===== HELPER FUNCTIONS =====
function sout = str_zeros(sin, N)
    sout = char(zeros(1,N));
    if (length(sin) <= N)
        sout(1:length(sin)) = sin;
    else
        sout = sin(1:N);
    end
end



