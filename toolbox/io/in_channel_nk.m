function ChannelMat = in_channel_nk(ChannelFile)
% IN_CHANNEL_NK:  Read channel names from a Nihon Kohden 21E file.
%
% USAGE:  ChannelMat = in_channel_nk(ChannelFile)
%         ChannelMat = in_channel_nk()             : Return default channel names

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2017


%% ===== DEFAULTS =====
% Initialize output channel structure
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'Nihon Kohden';
ChannelMat.Channel = repmat(db_template('channeldesc'), 1, 256);

% Default electrode labels
for i = 1:length(ChannelMat.Channel)
    switch (i)
        case 1,    ChannelMat.Channel(i).Name = 'FP1';                       ChannelMat.Channel(i).Type = 'EEG';
        case 2,    ChannelMat.Channel(i).Name = 'FP2';                       ChannelMat.Channel(i).Type = 'EEG';
        case 3,    ChannelMat.Channel(i).Name = 'F3';                        ChannelMat.Channel(i).Type = 'EEG';
        case 4,    ChannelMat.Channel(i).Name = 'F4';                        ChannelMat.Channel(i).Type = 'EEG';
        case 5,    ChannelMat.Channel(i).Name = 'C3';                        ChannelMat.Channel(i).Type = 'EEG';
        case 6,    ChannelMat.Channel(i).Name = 'C4';                        ChannelMat.Channel(i).Type = 'EEG';
        case 7,    ChannelMat.Channel(i).Name = 'P3';                        ChannelMat.Channel(i).Type = 'EEG';
        case 8,    ChannelMat.Channel(i).Name = 'P4';                        ChannelMat.Channel(i).Type = 'EEG';
        case 9,    ChannelMat.Channel(i).Name = 'O1';                        ChannelMat.Channel(i).Type = 'EEG';
        case 10,   ChannelMat.Channel(i).Name = 'O2';                        ChannelMat.Channel(i).Type = 'EEG';
        case 11,   ChannelMat.Channel(i).Name = 'F7';                        ChannelMat.Channel(i).Type = 'EEG';
        case 12,   ChannelMat.Channel(i).Name = 'F8';                        ChannelMat.Channel(i).Type = 'EEG';
        case 13,   ChannelMat.Channel(i).Name = 'T3';                        ChannelMat.Channel(i).Type = 'EEG';
        case 14,   ChannelMat.Channel(i).Name = 'T4';                        ChannelMat.Channel(i).Type = 'EEG';
        case 15,   ChannelMat.Channel(i).Name = 'T5';                        ChannelMat.Channel(i).Type = 'EEG';
        case 16,   ChannelMat.Channel(i).Name = 'T6';                        ChannelMat.Channel(i).Type = 'EEG';
        case 17,   ChannelMat.Channel(i).Name = 'FZ';                        ChannelMat.Channel(i).Type = 'EEG';
        case 18,   ChannelMat.Channel(i).Name = 'CZ';                        ChannelMat.Channel(i).Type = 'EEG';
        case 19,   ChannelMat.Channel(i).Name = 'PZ';                        ChannelMat.Channel(i).Type = 'EEG';
        case 20,   ChannelMat.Channel(i).Name = 'E';                         ChannelMat.Channel(i).Type = 'EEG';
        case 21,   ChannelMat.Channel(i).Name = 'PG1';                       ChannelMat.Channel(i).Type = 'EEG';
        case 22,   ChannelMat.Channel(i).Name = 'PG2';                       ChannelMat.Channel(i).Type = 'EEG';
        case 23,   ChannelMat.Channel(i).Name = 'A1';                        ChannelMat.Channel(i).Type = 'EEG';
        case 24,   ChannelMat.Channel(i).Name = 'A2';                        ChannelMat.Channel(i).Type = 'EEG';
        case 25,   ChannelMat.Channel(i).Name = 'T1';                        ChannelMat.Channel(i).Type = 'EEG';
        case 26,   ChannelMat.Channel(i).Name = 'T2';                        ChannelMat.Channel(i).Type = 'EEG';
        case num2cell(27:37), ChannelMat.Channel(i).Name = sprintf('X%d', i - 26);     ChannelMat.Channel(i).Type = 'EEG';
        case num2cell(43:74), ChannelMat.Channel(i).Name = sprintf('DC%02d', i - 42);  ChannelMat.Channel(i).Type = 'DC';
        case 75,   ChannelMat.Channel(i).Name = 'BN1';                       ChannelMat.Channel(i).Type = 'MISC';
        case 76,   ChannelMat.Channel(i).Name = 'BN2';                       ChannelMat.Channel(i).Type = 'MISC';
        case 77,   ChannelMat.Channel(i).Name = 'Mark1';                     ChannelMat.Channel(i).Type = 'MISC';
        case 78,   ChannelMat.Channel(i).Name = 'Mark2';                     ChannelMat.Channel(i).Type = 'MISC';
        case 101,  ChannelMat.Channel(i).Name = 'X12/BP1';                   ChannelMat.Channel(i).Type = 'EEG';
        case 102,  ChannelMat.Channel(i).Name = 'X13/BP2';                   ChannelMat.Channel(i).Type = 'EEG';
        case 103,  ChannelMat.Channel(i).Name = 'X14/BP3';                   ChannelMat.Channel(i).Type = 'EEG';
        case 104,  ChannelMat.Channel(i).Name = 'X15/BP4';                   ChannelMat.Channel(i).Type = 'EEG';
        case num2cell(105:255), ChannelMat.Channel(i).Name = sprintf('X%d', i - 89);   ChannelMat.Channel(i).Type = 'EEG';
        case 256,  ChannelMat.Channel(i).Name = 'Z';                         ChannelMat.Channel(i).Type = 'MISC';
        case num2cell([38:42, 79:100]), ChannelMat.Channel(i).Name = sprintf('U%d',i); ChannelMat.Channel(i).Type = 'UNKNOWN';
    end
end

% If only the defaults are needed
if (nargin == 0) || isempty(ChannelFile)
    return;
end


%% ===== READ 21E FILE =====
% Open file
fid = fopen(ChannelFile, 'r');
if (fid == -1)
    error('Cannot open file.');
end

% Initialize indices structure
curBlock = '';
% Read file line by line
while 1
    % Read line
    read_line = fgetl(fid);
    % Empty line: go to next line
    if isempty(read_line)
        continue
    % End of file: stop reading
    elseif (read_line(1) == -1)
        break
    end
    % Strip additional spaces
    read_line = strtrim(read_line);
    % Empty line or comment: go to next line
    if isempty(read_line) || (read_line(1) == '#')
        curBlock = '';
        continue
    end     
    % Check if beginning/end of block
    if strcmpi(read_line, '[ELECTRODE]')
        curBlock = 'electrode';
    elseif strcmpi(read_line, '[REFERENCE]')
        curBlock = 'reference';
    elseif strcmpi(read_line, '[SYSTEM_SETUP]')
        curBlock = 'setup';
    elseif strcmpi(read_line(1), '[')
        curBlock = 'skip';
    else
        switch (curBlock)
            case 'electrode'
                if any(read_line == '=')
                    % Split line around "="
                    splitLine = str_split(read_line, '=');
                    if (length(splitLine) ~= 2)
                        continue;
                    end
                    % Read fields
                    iChannel = str2num(splitLine{1}) + 1;
                    chName   = strtrim(splitLine{2});
                    % Save channel name
                    if ~isempty(chName)
                        ChannelMat.Channel(iChannel).Name = chName;
                    end
                end
            case 'reference'
                if any(read_line == '=')
                    % Split line around "="
                    splitLine = str_split(read_line, '=');
                    if (length(splitLine) ~= 2)
                        continue;
                    end
                    % Read fields
                    iChannel = str2num(splitLine{1}) + 1;
                    chRef    = strtrim(splitLine{2});
                    chRef(chRef == '$') = [];
                    % Save channel name
                    if ~isempty(chRef)
                        ChannelMat.Channel(iChannel).Comment = ['Reference: ' chRef];
                    end
                end
        end
    end
end
% Close file
fclose(fid);





