function out_channel_nirs_brainsight(BstFile, OutputFile, Factor, Transf)
% OUT_CHANNEL_NIRS_BRAINSIGHT: Export a Brainstorm channel file in 
% brainsight coordinate files.
%
% USAGE:  out_channel_nirs_brainsight( BstFile, OutputFile, Factor, Transf)
%
% INPUT: 
%     - BstFile    : full path to Brainstorm file to export
%     - OutputFile : full path to output file
%     - Factor     : Factor to convert the positions values in meters.
%     - Transf     : 4x4 transformation matrix to apply to the 3D positions before saving
%                    or entire MRI structure. Optodes are
%                    exported using world coordinates.
%
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
% Authors: Thomas Vincent 2017, Edouard Delaire 2023

if (nargin < 3) || isempty(Factor)
    Factor = .001;
end
if (nargin < 4) || isempty(Transf)
    Transf = [];
end


% Load brainstorm channel file
if ischar(BstFile)
    ChannelMat = in_bst_channel(BstFile);
else
    ChannelMat = BstFile;
end

if ~isfield(ChannelMat, 'Nirs')
    bst_error('Channel file does not correspond to NIRS data.');
    return;
end

Loc     = zeros(3,0);
Label   = {};
Type    = {};

for i = 1:length(ChannelMat.Channel)
    if ~isempty(ChannelMat.Channel(i).Loc) && ~all(ChannelMat.Channel(i).Loc(:) == 0)
        CHAN_RE = '^S([0-9]+)D([0-9]+)(WL\d+|HbO|HbR|HbT)$';
        toks = regexp(strrep(ChannelMat.Channel(i).Name, ' ', '_'), CHAN_RE, 'tokens');
    
        Loc(:,end+1) = ChannelMat.Channel(i).Loc(:,1);
        Label{end+1} = sprintf('S%s',toks{1}{1} );
        Type{end+1}  = 'source';
    
        Loc(:,end+1) = ChannelMat.Channel(i).Loc(:,2);
        Label{end+1} = sprintf('D%s',toks{1}{2} );
        Type{end+1}  = 'detector';
    end
end

% Remove duplicate and sort Sources / Detectors
[Label, I]  = unique(Label, 'stable');
Loc         = Loc(:,I);
Type        = Type(I);

[Type, I] = sort(Type);
Label     = Label(I);
Loc       = Loc(:,I);


if isfield(ChannelMat, 'HeadPoints') && ~isempty(ChannelMat.HeadPoints) && ~isempty(ChannelMat.HeadPoints.Loc)
    % Find fiducials in the head points
    iCardinal = find(strcmpi(ChannelMat.HeadPoints.Type, 'CARDINAL'));
    fidu_coords = ChannelMat.HeadPoints.Loc(:,iCardinal);
    fidu_labels = ChannelMat.HeadPoints.Label(iCardinal);

    Label = [Label,  fidu_labels];
    Loc   = [Loc , fidu_coords ];
end

% Apply transformation
if ~isempty(Transf)
    if isstruct(Transf)
        Loc = cs_convert(Transf, 'scs', 'world', Loc')';
    % World coordinates
    else
        R = Transf(1:3,1:3);
        T = Transf(1:3,4);
        Loc = R * Loc + T * ones(1, size(Loc,2));
    end
end
% Apply factor
Loc = Loc ./ Factor;


% Format header
header = sprintf(['# Version: 5\n# Coordinate system: NIftI-Aligned\n# Created by: Brainstorm (nirstorm plugin)\n' ...
         '# units: millimetres, degrees, milliseconds, and microvolts\n# Encoding: UTF-8\n' ...
         '# Notes: Each column is delimited by a tab. Each value within a column is delimited by a semicolon.\n' ...
         '# Sample Name	Index	Loc. X	Loc. Y	Loc. Z	Offset\n']);


% Open output file
fid = fopen(OutputFile, 'w');
if (fid < 0)
   error('Cannot open file'); 
end

fprintf(fid, '%s', header);
% Write file: one line per location
for i = 1:length(Label)
    fprintf(fid,'%s\t%d\t%f\t%f\t%f\t0.0\n',Label{i}, i, Loc(1, i), Loc(2, i), Loc(3, i));
end

% Close file
fclose(fid);

end




