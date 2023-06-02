function out_channel_bids(BstFile, OutputFile, Factor, Transf, isNIRS)
% OUT_CHANNEL_BIDS: Exports a Brainstorm channel file in an BIDS _electrodes.tsv or _optrodes.tsv file
%
% USAGE:  out_channel_bids(BstFile, OutputFile, Factor=1, Transf=[]);
%
% INPUT: 
%     - BstFile    : full path to Brainstorm file to export
%     - OutputFile : full path to output file
%     - Factor     : Factor to convert the positions values in meters.
%     - Transf     : 4x4 transformation matrix to apply to the 3D positions before saving
%                    or entire MRI structure for conversion to MNI space
%     - isNIRS     : (Default = 0), if isNIRS = 1, channel file is exported as _optrodes.tsv

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
% Authors: Francois Tadel, 2022


%% ===== PARSE INPUTS =====
if (nargin < 3) || isempty(Factor)
    Factor = .01;
end
if (nargin < 4) || isempty(Transf)
    Transf = [];
end
if (nargin < 5) || isempty(isNIRS)
    isNIRS = 0;
end
% Load brainstorm channel file
BstMat = in_bst_channel(BstFile);

% Get all the positions
Loc   = zeros(3,0);
Label = {};
Group = {};
Type = {};
for i = 1:length(BstMat.Channel)
    if ~isempty(BstMat.Channel(i).Loc) && ~all(BstMat.Channel(i).Loc(:) == 0)
        if ~isNIRS
            Loc(:,end+1) = BstMat.Channel(i).Loc(:,1);
            Label{end+1} = strrep(BstMat.Channel(i).Name, ' ', '_');
            Group{end+1} = BstMat.Channel(i).Group;
            Type{end+1} = BstMat.Channel(i).Type;
        else
            CHAN_RE = '^S([0-9]+)D([0-9]+)(WL\d+|HbO|HbR|HbT)$';
            toks = regexp(strrep(BstMat.Channel(i).Name, ' ', '_'), CHAN_RE, 'tokens');

            Loc(:,end+1) = BstMat.Channel(i).Loc(:,1);
            Label{end+1} = sprintf('S%s',toks{1}{1} );
            Type{end+1}  = 'source';
            Group{end+1} = '';

            Loc(:,end+1) = BstMat.Channel(i).Loc(:,2);
            Label{end+1} = sprintf('D%s',toks{1}{2} );
            Type{end+1}  = 'detector';
            Group{end+1} = '';
        end
    end   
end

% Remove duplicate 
if isNIRS
    [Label, I]  = unique(Label, 'stable');
    Loc         = Loc(:,I);
    Group       = Group(I);
    Type        = Type(I);
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
% Write header: column names
if isNIRS
    ColNames = {'name','type', 'x', 'y', 'z'};
else
    ColNames = {'name', 'x', 'y', 'z', 'size', 'group', 'type'};
end
fprintf(fid, '%s\t', ColNames{1:end-1});
fprintf(fid, '%s\n', ColNames{end});
% Write file: one line per location
for i = 1:length(Label)
    for iCol = 1:length(ColNames)
        switch (ColNames{iCol})
            case 'name'
                fprintf(fid, '%s', Label{i});
            case 'x'
                fprintf(fid, '%1.6f', Loc(1,i));
            case 'y'
                fprintf(fid, '%1.6f', Loc(2,i));
            case 'z'
                fprintf(fid, '%1.6f', Loc(3,i));
            case 'size'
                fprintf(fid, 'n/a');
            case 'group'
                fprintf(fid, '%s', Group{i});
            case 'type'
                switch (Type{i})
                    case {'source', 'detector'}
                        chType = Type{i};
                    case 'SEEG'
                        chType = 'depth';
                    case 'ECOG'
                        chType = 'grid';
                        % Detect if this is a strip instead of a grid
                        if ~isempty(Group{i}) && ~isempty(BstMat.IntraElectrodes)
                            iElec = find(strcmpi(Group{i}, {BstMat.IntraElectrodes.Name}), 1);
                            if ~isempty(iElec)
                                N = BstMat.IntraElectrodes(iElec).ContactNumber;
                                if (length(N) == 1) || ((length(N) > 1) && (prod(N) == max(N)))
                                    chType = 'strip';
                                end
                            end
                        end
                    otherwise
                        chType = 'n/a';
                end
                fprintf(fid, '%s', chType);
        end

        if iCol < length(ColNames)
            fprintf(fid, '\t');
        end
    end
    fprintf(fid, '\n');
end
% Close file
fclose(fid);
