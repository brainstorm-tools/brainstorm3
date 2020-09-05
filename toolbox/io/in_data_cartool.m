function DataMat = in_data_cartool(DataFile)
% IN_DATA_CARTOOL: Read an eeg recording matrix from binary or ASCII Cartool EEG file.
%
% FORMAT:
%    Three avaialable formats, identified by file extensions.
%    - EP : A very basic text file format to store an ERP, without header. This is a simple matrix of values, 
%           each line (with end-of-line) having all the electrodes values for a given time frame:
%                 "electrode_1 electrode_2 electrode_3 ... electrode_n <RETURN>"
%           Lines are repeated for each time frames (the number of time frames is therefore the number of lines).
%
%    - EPH : Same format than 'EP', with a small text header (the first line in the file):
%                 "number_of_electrodes   number_of_time_frames sampling_frequency"
%
%    - SEF : Simple bi nary format containing the minimal data structure to describe correctly an EEG, 
%            either an original recording or an ERP. It has a header, made of a fixed part and 
%            a variable part, followed by the calibrated data (in micro-volts).
%            - Fixed part of the header:
%                 struct TSefHeader{    
%                    int   Version;            // magic number filled with the wide char 'SE01'    
%                    int   NumElectrodes;      // total number of electrodes
%                    int   NumAuxElectrodes;   //  out of which are auxiliaries
%                    int   NumTimeFrames;      // time length
%                    float SamplingFrequency;  // frequency in Hertz
%                    short Year;               // Date of the recording    
%                    short Month;              // (set to 00-00-0000 if unknown)    
%                    short Day;    
%                    short Hour;               // Time of the recording    
%                    short Minute;             // (set to 00:00:00:0000 if unknown)    
%                    short Second;    
%                    short Millisecond;};
%            - Variable part of the header:
%                The names of the channels, as a matrix of  NumElectrodes x 8 chars.
%                    typedef char TSefChannelName[8];  // 1 electrode name
%                To allow an easy calculation of the data origin, be aware that names 
%                are always stored on 8 bytes, even if the string length is smaller than that. 
%                In this case, the remaining part is padded with bytes set to 0, f.ex. two consecutive names:
%            - Data part:
%                Starting at file position: sizeof ( TSefHeader ) + 8 * NumElectrodes
%                Data is stored as a float (Little Endian convention - PC) matrix written row by row:
%                float data [ NumTimeFrames ][ NumElectrodes ];

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
% Authors: Francois Tadel, 2006-2015

% Detect associated event file (.mrk)
MrkFile = [DataFile '.mrk'];
if ~file_exist(MrkFile)
    MrkFile = [];
end

% Read data
[filePath, fileBase, fileExt] = bst_fileparts(DataFile);
% Cartool .ep files
if strcmpi(fileExt, '.ep')
    % Read file
    DataMat = in_data_ascii(DataFile);
    
% Cartool .eph/.sef
else
    % Initialize returned structure
    DataMat = db_template('DataMat');
    DataMat.Comment  = 'Cartool EEG';
    DataMat.DataType = 'recordings';
    DataMat.Device   = 'Unknown';
    % Format
    switch lower(fileExt)
        case '.ep'
            %error('Please use in_data_ascii to read Cartool .EP files');
        case '.eph'
            % Open file for reading only
            [fid, message] = fopen(DataFile, 'r');
            if fid == -1
                error('ioReadEeg:openFileError', 'Unknable to open file');
            end
            % Read header
            hdr = textscan(fid, '%d %d %d', 1);
            eegHeader.numElectrodes = hdr{1};
            eegHeader.numTimeFrames = hdr{2};
            eegHeader.samplingFrequency = hdr{3};
            % Read eeg data
            DataMat.F = textscan(fid, '%f');
            DataMat.F = DataMat.F{1};
            DataMat.F = reshape(DataMat.F, eegHeader.numElectrodes, []);
            if(size(DataMat.F,2) ~= eegHeader.numTimeFrames)
                error('ioReadEeg:readFileError', 'Corrupted eeg file');
            end
            % Scale from µV to V
            DataMat.F = DataMat.F .* 1e-6;
            % Close file
            fclose(fid);

        case '.sef'
            % Open file for reading only (ONLY LITTLE ENDIAN)
            [fid, message] = fopen(DataFile, 'r', 'ieee-le');
            if fid == -1
                error('ioReadEeg:openFileError', ['Unknable to open file : ' message]);
            end
            % Read fixed part of the header
            eegHeader.version = char(fread(fid,[1,4],'uchar'));
            eegHeader.numElectrodes = fread(fid,1,'uint32'); 
            eegHeader.numAuxElectrodes = fread(fid,1,'uint32'); 
            eegHeader.numTimeFrames = fread(fid,1,'uint32'); 
            eegHeader.samplingFrequency = fread(fid,1,'float32');
            eegHeader.year = fread(fid,1,'uint16');
            eegHeader.month = fread(fid,1,'uint16');
            eegHeader.day = fread(fid,1,'uint16');
            eegHeader.hour = fread(fid,1,'uint16');
            eegHeader.minute = fread(fid,1,'uint16');
            eegHeader.second = fread(fid,1,'uint16');
            eegHeader.millisecond = fread(fid,1,'uint16');

            % Version verification
            if ~isequal(eegHeader.version, 'SE01')
                error('ioReadEeg:unknownVersion', 'Unable to read file.');
            end
            % Read variable part of the header
            eegHeader.channelNames = cell(eegHeader.numElectrodes,1);
            for i=1:eegHeader.numElectrodes
                eegHeader.channelNames{i} = char(fread(fid,[1,8],'uchar'));
            end

            % Read data
            [DataMat.F,cnt] = fread(fid,[eegHeader.numElectrodes, eegHeader.numTimeFrames],'float32');
            if (cnt ~= eegHeader.numElectrodes * eegHeader.numTimeFrames)
                error('ioReadEeg:uncompleteFile', 'Unable to read file.');
            end
            % Scale from µV to V
            DataMat.F = DataMat.F .* 1e-6;
            % Close file
            fclose(fid);

        otherwise
            error('ioReadEeg:badFileType', 'Unknown file type for EEG recording');
    end

    DataMat.ChannelFlag = ones(size(DataMat.F,1),1);
    DataMat.Time = (0:(size(DataMat.F,2)-1)) ./ double(eegHeader.samplingFrequency);
end

% ===== LOAD EVENTS =====
if ~isempty(MrkFile) && ~isempty(DataMat)
    sFile = in_fopen_bstmat(DataMat);
    % Import events file
    sFile = import_events(sFile, [], MrkFile, 'CARTOOL');
    % Report in data structure
    DataMat.Events = sFile.events;
end


