function [sMontage, errMsg] = in_montage_mon(filename)
% IN_MONTAGE_MON:  Read sensors selections file from .mon file
%
% USAGE:  [sMontage, errMsg] = in_montage_mon(filename)
%         [sMontage, errMsg] = in_montage_mon(string)

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
% Authors: Francois Tadel, 2014

% Initialize returned structure
sMontage = db_template('Montage');
sMontage.Type = 'text';
errMsg = '';
% Read file
if ~any(filename == 10) && file_exist(filename)
    % Open file
    fid = fopen(filename, 'r');
    if (fid == -1)
        error('Cannot open file.');
    end
    % Read file
    str = fread(fid,[1 Inf],'*char');
    % Close file
    fclose(fid);
else
    str = filename;    
end

% Split file in lines
str = str_split(str, 10);
% Read file line by line
for iLine = 1:length(str)
    % Read line
    read_line = str{iLine};
    % Empty line: go to next line
    if isempty(read_line) || isempty(strtrim(read_line)) || (read_line(1) == '%') || (read_line(1) == '#')
        continue
    end
    % 1st line: Montage name
    if isempty(sMontage.Name)
        sMontage.Name = read_line;
        continue;
    end
    % New line index
    iDisp = length(sMontage.DispNames) + 1;
    % Separator line: ":"
    if isequal(strtrim(read_line), ':')
        % Only process as a separator if it is not the first line
        if (iDisp > 1)
            sMontage.DispNames{iDisp} = ' ';
            sMontage.Matrix(iDisp,:) = zeros(1,size(sMontage.Matrix,2));
        end
        continue;
    end
    % Regular line, split it
    split_line = str_split(read_line, ':');
    if (length(split_line) ~= 2) || isempty(split_line{1}) || isempty(split_line{2})
        errMsg = [errMsg 'Invalid line "' read_line '"' 10];
        disp(['BST> Montage: ' errMsg]);
        continue;
    end
    % Get the display name for this montage entry
    sMontage.DispNames{iDisp} = strtrim(split_line{1});
    % Split with ','
    sline = str_split(split_line{2}, ',');
    % Loop on all the entries
    for i = 1:length(sline)
        % Split with '*'
        schan = str_split(strtrim(sline{i}), '*');
        % No multiplication: "Cz" or "-Cz" or "+Cz"
        if (length(schan) == 1)
            schan = strtrim(schan{1});
            if (schan(1) == '+')
                chfactor = 1;
                chname = schan(2:end);
            elseif (schan(1) == '-')
                chfactor = -1;
                chname = schan(2:end);
            else
                chfactor = 1;
                chname = schan;
            end
        % One multiplication: "<factor>*<chname>"
        elseif (length(schan) == 2)
            chfactor = str2num(strtrim(schan{1}));
            chname = strtrim(schan{2});
        else
            errMsg = [errMsg 'Invalid entry "' sline{i} '"' 10];
            disp(['BST> Montage: ' errMsg]);
        end
        % Look for existing channel name
        iChan = find(strcmpi(sMontage.ChanNames, chname));
        % If not referenced yet: add new channel entry
        if isempty(iChan)
            iChan = length(sMontage.ChanNames) + 1;
            sMontage.ChanNames{iChan} = chname;
        end
        % Add entry to montage
        sMontage.Matrix(iDisp,iChan) = chfactor;
    end
end




