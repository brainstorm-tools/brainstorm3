function ChannelMat = in_channel_ascii(ChannelFile, Format, nSkipLines, Factor)
% IN_CHANNEL_ASCII:  Read 3D cartesian positions for a set of electrodes from an ASCII file.
%
% USAGE:  ChannelMat = in_channel_ascii(ChannelFile, Format={'X','Y','Z'}, nSkipLines=0, Factor=0.1(cm))
%
% INPUTS: 
%     - ChannelFile : Full path to the file
%     - Format      : Cell-array describing the columns in the ASCII file (assumes that 1 row = 1 electrode)
%                     => 'X','Y','Z' : 3D electrode position (float)
%                     => 'indice'    : electrode indice (integer)
%                     => 'name'      : electrode name (string)
%                     => otherwise   : do not use this column
%     - nSkipLines  : Number of lines to skip before starting to read values (for files with headers)
%     - Factor      : Factor to convert the positions values in meters.

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
% Authors: Francois Tadel, 2009-2019

%% ===== PARSE INPUTS =====
% Check arguments
if (nargin < 2) || isempty(Format)
    Format = {'X','Y','Z'};
end
if (nargin < 3) || isempty(nSkipLines)
    nSkipLines = 0;
end
if (nargin < 4) || isempty(Factor)
    Factor = .01;
end

% Interpret Format string
strScanFormat = '';
iX = [];
iY = [];
iZ = [];
iName = [];
iIndice = [];
isMinuxX = 0;
isMinuxY = 0;
isMinuxZ = 0;
isSpherical = 0;
% Loop on all the format elements
for i = 1:length(Format)
    switch lower(Format{i})
        case 'x'
            iX = i;
            strScanFormat = [strScanFormat, '%f '];
        case '-x'
            iX = i;
            isMinuxX = 1;
            strScanFormat = [strScanFormat, '%f '];
        case 'y'
            iY = i;
            strScanFormat = [strScanFormat, '%f '];
        case '-y'
            iY = i;
            isMinuxY = 1;
            strScanFormat = [strScanFormat, '%f '];
        case 'z'
            iZ = i;
            strScanFormat = [strScanFormat, '%f '];
        case '-z'
            iZ = i;
            isMinuxZ = 1;
            strScanFormat = [strScanFormat, '%f '];
        case 'th'
            iX = i;
            strScanFormat = [strScanFormat, '%f '];
            isSpherical = 1;
        case 'phi'
            iY = i;
            strScanFormat = [strScanFormat, '%f '];
            isSpherical = 1;
        case 'name'
            iName = i;
            strScanFormat = [strScanFormat, '%[^,; \t\b\n\r] '];
        case 'indice'
            iIndice = i;
            strScanFormat = [strScanFormat, '%d '];
        otherwise
            strScanFormat = [strScanFormat, Format{i}, ' '];
    end
end
% Ignore all the end of the line
strScanFormat = [strScanFormat, '%*[^\n\r]'];


%% ===== READ FILE =====
% Open file
fid = fopen(ChannelFile, 'r');
% Skip the header lines
for i = 1:nSkipLines
    fgetl(fid);
end
% Read values
read_data = textscan(fid, strScanFormat, 'Whitespace', ',; \t');
% Close file
fclose(fid);


%% ===== PROCESS VALUES =====
% Get the electrodes positions
if ~isempty(iZ)
    Locs = [read_data{iX}, read_data{iY}, read_data{iZ}];
elseif isSpherical
    % Convert Spherical(degrees) => Spherical(radians) => Cartesian
    TH  = (90 - read_data{iX}) ./ 180 * pi;
    PHI = (180 + read_data{iY}) ./ 180 * pi;
    [Locs(:,2),Locs(:,1),Locs(:,3)] = sph2cart(PHI, TH, ones(size(TH)));
    Locs(:,3) = Locs(:,3) + .5;
    Locs(:,1) = -Locs(:,1);
    Locs(:,2) = -Locs(:,2);
else
    Locs = [read_data{iX}, read_data{iY}, 0 * read_data{iY}];
end
% Replace NaN values with zeros
Locs(isnan(Locs)) = 0;
% Opposite of some columns ?
if isMinuxX
    Locs(:,1) = -Locs(:,1);
end
if isMinuxY
    Locs(:,2) = -Locs(:,2);
end
if isMinuxZ
    Locs(:,3) = -Locs(:,3);
end

% Get number of electrodes
nElectrodes = size(Locs, 1);
if (nElectrodes == 0)
    ChannelMat = [];
else
    ChannelMat = db_template('channelmat');
end
% Get the names
if ~isempty(iName)
    Names = read_data{iName};
% If names are not defined: create them
else
    % Process each electrode separately
    for i = 1:nElectrodes
        % If indice is available, use it
        if ~isempty(iIndice)
            eind = read_data{iIndice}(i);
        % Else, use the current indice in the matrix
        else
            eind = i;
        end
        % Build electrode name: "E#i"
        Names{i} = sprintf('E%d', eind);
    end
end


%% ===== BUILD OUTPUT STRUCTURE =====
for i = 1:nElectrodes
    ChannelMat.Channel(i).Type    = 'EEG';
    ChannelMat.Channel(i).Name    = Names{i};
    ChannelMat.Channel(i).Loc     = Locs(i, :)' .* Factor;
    ChannelMat.Channel(i).Orient  = [];
    ChannelMat.Channel(i).Comment = '';
    ChannelMat.Channel(i).Weight  = 1;
end





