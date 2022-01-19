function ChannelMat = in_channel_tsv(ChannelFile, LabelChannel, LabelPos, Factor)
% IN_CHANNEL_TSV:  Read 3D positions from a .tsv file with named columns.

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
% Authors: Francois Tadel, 2017


%% ===== READ FILE =====
% Open file
fid = fopen(ChannelFile, 'r');
% Search for the header line with the column names
stop = 0;
while ~stop
    % Read line
    strLine = fgetl(fid);
    % If we reached the end of the file
    if isequal(strLine, -1)
        error(['Could not find header line with column names: "' LabelChannel '" and "' LabelPos '".']);
    end
    % If the line includes the two requested column names
    if ~isempty(strfind(strLine, LabelChannel)) && ~isempty(strfind(strLine, LabelPos))
        % Keep this line as the column labels and move on
        ColumnLabels = str_split(strLine, sprintf('\t'));
        stop = 1;
    end
end

% Read values
read_data = textscan(fid, '%s', 'Delimiter', '\t');
read_data = reshape(read_data{1}, length(ColumnLabels), [])';
% Close file
fclose(fid);

% Find columns of interest
iColLabel = find(strcmpi(ColumnLabels, LabelChannel));
iColPos   = find(strcmpi(ColumnLabels, LabelPos));
if isempty(iColLabel) || isempty(iColPos)
    error(['Column names not found: ' LabelChannel ', ' LabelPos]);
end

%% ===== BUILD OUTPUT STRUCTURE =====
nChannels = size(read_data,1);
% Initialize output structure
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'TSV';
ChannelMat.Channel = repmat(db_template('channeldesc'), 1, nChannels);
for i = 1:nChannels
    ChannelMat.Channel(i).Type    = 'EEG';
    ChannelMat.Channel(i).Name    = read_data{i,iColLabel};
    ChannelMat.Channel(i).Orient  = [];
    ChannelMat.Channel(i).Comment = '';
    ChannelMat.Channel(i).Weight  = 1;
    % Get location
    try
        Loc = eval(read_data{i,iColPos});
        ChannelMat.Channel(i).Loc  = Loc' .* Factor;
    catch
        disp(['Invalid position for contact "' ChannelMat.Channel(i).Name '": ' read_data{i,iColPos}]);
    end
end



