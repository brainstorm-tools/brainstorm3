function out_channel_ascii( BstFile, OutputFile, Format, isEEG, isHeadshape, isHeader, Factor, Transf)
% OUT_CHANNEL_ASCII: Exports a Brainstorm channel file in an ascii file.
%
% USAGE:  out_channel_ascii( BstFile, OutputFile, Format={X,Y,Z}, isEEG=1, isHeadshape=1, isHeader=0, Factor=.01, Transf=[]);
%
% INPUT: 
%     - BstFile    : full path to Brainstorm file to export
%     - OutputFile : full path to output file
%     - Format     : Cell-array describing the columns in the ASCII file
%                    => 'X','Y','Z' : 3D position (float)
%                    => 'indice'    : indice (integer)
%                    => 'name'      : name (string)
%                    => otherwise   : do not use this column
%     - isEEG       : Writes the coordinates of the electrodes
%     - isHeadshape : Writes the coordinates of the headshape points
%     - isHeader    : Writes header (number of EEG points)
%     - Factor      : Factor to convert the positions values in meters.
%     - Transf      : 4x4 transformation matrix to apply to the 3D positions before saving
%                     or entire MRI structure for conversion to MNI space

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
% Authors: Francois Tadel, 2012-2020


%% ===== PARSE INPUTS =====
if (nargin < 3) || isempty(Format)
    Format = {'X','Y','Z'};
end
if (nargin < 4) || isempty(isEEG)
    isEEG = 1;
end
if (nargin < 5) || isempty(isHeadshape)
    isHeadshape = 1;
end
if (nargin < 6) || isempty(isHeader)
    isHeader = 0;
end
if (nargin < 7) || isempty(Factor)
    Factor = .01;
end
if (nargin < 8) || isempty(Transf)
    Transf = [];
end

% Load brainstorm channel file
BstMat = in_bst_channel(BstFile);
% Get all the positions
Loc    = zeros(3,0);
Label  = {};
if isEEG && isfield(BstMat, 'Channel') && ~isempty(BstMat.Channel)
    for i = 1:length(BstMat.Channel)
        if ~isempty(BstMat.Channel(i).Loc) && ~all(BstMat.Channel(i).Loc(:) == 0)
            
            if size(BstMat.Channel(i).Loc,2) == 1
                Loc(:,end+1) = BstMat.Channel(i).Loc(:,1);
                Label{end+1} = strrep(BstMat.Channel(i).Name, ' ', '_');
            else
                CHAN_RE = '^S([0-9]+)D([0-9]+)(WL\d+|HbO|HbR|HbT)$';
                toks = regexp(strrep(BstMat.Channel(i).Name, ' ', '_'), CHAN_RE, 'tokens');

                Loc(:,end+1) = BstMat.Channel(i).Loc(:,1);
                Label{end+1} = sprintf('S%s',toks{1}{1} );

                Loc(:,end+1) = BstMat.Channel(i).Loc(:,2);
                Label{end+1} = sprintf('D%s',toks{1}{2} );
            end
        end
    end

    % Remove duplicate optodes / electrodes 
    [Label, I] = unique(Label, 'stable');
    Loc = Loc(:,I);
    
end

if isHeadshape && isfield(BstMat, 'HeadPoints') && ~isempty(BstMat.HeadPoints) && ~isempty(BstMat.HeadPoints.Loc)
    Loc   = [Loc, BstMat.HeadPoints.Loc];
    Label = cat(2, Label, BstMat.HeadPoints.Label);
end

% Apply transformation
if ~isempty(Transf)
    % MNI coordinates: the entire MRI is passed in input
    if isstruct(Transf)
        Loc = cs_convert(Transf, 'scs', 'mni', Loc')';
    % World coordinates
    else
        R = Transf(1:3,1:3);
        T = Transf(1:3,4);
        Loc = R * Loc + T * ones(1, size(Loc,2));
    end
end
% Apply factor
Loc = Loc ./ Factor;

% Open output file
fid = fopen(OutputFile, 'w');
if (fid < 0)
   error('Cannot open file'); 
end
% Write header
nLoc = size(Loc,2);
if isHeader
    fwrite(fid, sprintf('%d\n', nLoc), 'char');
end
% Write file: one line per location
for i = 1:nLoc
    % Write each format entry
    for iF = 1:length(Format)
        % Entry types
        switch lower(Format{iF})
            case 'x',       str = sprintf('%1.4f', Loc(1,i));
            case '-x',      str = sprintf('%1.4f', -Loc(1,i));
            case 'y',       str = sprintf('%1.4f', Loc(2,i));
            case '-y',      str = sprintf('%1.4f', -Loc(2,i));
            case 'z',       str = sprintf('%1.4f', Loc(3,i));
            case '-z',      str = sprintf('%1.4f', -Loc(3,i));
            case 'indice',  str = sprintf('%d', i);
            case 'name',    str = Label{i};
            otherwise,      str = ' ';
        end
        % Write value
        fwrite(fid, str);
        % Add separator (space)
        if (iF ~= length(Format))
            fwrite(fid, sprintf('\t'));
        % Terminate line
        else
            fwrite(fid, 10);
        end
    end
end
% Close file
fclose(fid);






