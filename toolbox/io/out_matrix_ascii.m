function out_matrix_ascii( OutputFile, Data, FileFormat, Label1, Label2, Label3, Title2)
% OUT_MATRIX_ASCII: Save the selected matrix of data in a text file.

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
% Authors: Francois Tadel, 2014-2016

% Parse inputs
if (nargin < 7) || isempty(Title2)
    Title2 = 'Time';
end
if (nargin < 6) || isempty(Label3)
    Label3 = [];
end
if (nargin < 5) || isempty(Label2)
    Label2 = [];
end
if (nargin < 4) || isempty(Label1)
    Label1 = [];
end
if (nargin < 3) || isempty(FileFormat)
    FileFormat = 'ASCII-CSV';
end

% Convert numeric labels into strings
if ~isempty(Label1) && ~iscell(Label1)
    Label = cell(size(Label1));
    for i = 1:length(Label1)
        Label{i} = num2str(Label1(i));
    end
    Label1 = Label;
end
% Convert numeric labels into strings
if ~isempty(Label2) && ~iscell(Label2)
    Label = cell(size(Label2));
    for i = 1:length(Label2)
        Label{i} = num2str(Label2(i));
    end
    Label2 = Label;
end
% Convert numeric labels into strings
if ~isempty(Label3) && ~iscell(Label3)
    Label = cell(size(Label3));
    for i = 1:length(Label3)
        Label{i} = num2str(Label3(i));
    end
    Label3 = Label;
end
% Error: Cannot export complex values
if ~isreal(Data)
    error('Cannot export complex values. Please extract the magnitude, phase or power first.');
end

% If there is a third dimension and not a second one (freq but no time): switch
if ((size(Data,2) == 1) || ((size(Data,2) == 2) && isequal(Data(:,1,:,:), Data(:,2,:,:)))) && (size(Data,3) > 1)
    Data = permute(Data, [1,3,2]);
    Label2 = Label3;
    Label3 = [];
    Title2 = 'Freq';
% If there are too many dimensions, and not saving in XLSX, select which one
elseif (size(Data,3) > 1) % && ~strcmpi(FileFormat, 'EXCEL')
    % Ask user what entry to export
    selLabel = java_dialog('combo', 'Select the frequency to export:', 'Export to ASCII', [], Label3);
    if isempty(selLabel)
        return
    end    
    % Get the index of the selected frequency
    iFreq = find(strcmpi(Label3, selLabel));
    if (length(iFreq) ~= 1)
        error('Unknown error...');
    end
    % Select only that one
    Data = Data(:,:,iFreq);
    Label3 = [];
end
% Transpose data (dimensions 1 and 2)
if ismember(FileFormat, {'ASCII-CSV-HDR-TR', 'ASCII-TSV-HDR-TR', 'EXCEL-TR'})
    FileFormat = FileFormat(1:end-3);
    Data = permute(Data, [2,1,3]);
    tmp = Label1;
    Label1 = Label2;
    Label2 = tmp;
end
    

% Switch depending on the requested file format
switch (FileFormat)
%     case 'ASCII-SPC' 
%         dlmwrite(OutputFile, Data, 'newline', 'unix', 'precision', '%17.9e', 'delimiter', ' ');
%     case 'ASCII-CSV' 
%         dlmwrite(OutputFile, Data, 'newline', 'unix', 'precision', '%17.9e', 'delimiter', ',');
        
    case {'ASCII-SPC', 'ASCII-CSV', 'ASCII-TSV', 'ASCII-SPC-HDR', 'ASCII-CSV-HDR', 'ASCII-TSV-HDR'}
        % Get separator character
        if ismember(FileFormat, {'ASCII-CSV-HDR', 'ASCII-CSV'})
            sep = ',';
        elseif ismember(FileFormat, {'ASCII-TSV-HDR', 'ASCII-TSV'})
            sep = sprintf('\t');
        else
            sep = ' ';
        end
        % Pad with spaces for fixed column sizes
        isPad = ismember(FileFormat, {'ASCII-SPC-HDR', 'ASCII-SPC'});
        % Are we saving a header
        isHeader = ismember(FileFormat, {'ASCII-SPC-HDR', 'ASCII-CSV-HDR', 'ASCII-TSV-HDR'});
        
        % Open output file
        fid = fopen(OutputFile, 'w');
        if (fid < 0)
           error('Cannot open file'); 
        end
        % Write header: labels for dimension 2
        if isHeader && ~isempty(Label2)
            if ~isempty(Label1)
                if isPad
                    fwrite(fid, sprintf(['%17s' sep], Title2), 'char');
                else
                    fwrite(fid, [Title2, sep], 'char');
                end
            end
            for i2 = 1:length(Label2)
                if isPad
                    fwrite(fid, sprintf(['%17s' sep], Label2{i2}), 'char');
                else
                    fwrite(fid, [Label2{i2}, sep], 'char');
                end
            end
            fwrite(fid, sprintf('\n'), 'char');
        end
        % Write channels one after the other
        for i1 = 1:size(Data,1)
            % Print row header
            if isHeader && ~isempty(Label1) && ~isempty(Label1{i1})
                if isPad
                    fwrite(fid, sprintf(['%17s' sep], Label1{i1}), 'char');
                else
                    fwrite(fid, [Label1{i1}, sep], 'char');
                end
            end
            % Print all data
            if isPad
                strChan = sprintf(['%17.9e' sep], Data(i1,:));
            else
                strChan = sprintf(['%1.9e' sep], Data(i1,:));
            end
            % Remove last separator
            strChan(end) = [];
            % Write data to file
            fwrite(fid, strChan, 'char');
            % End line
            fwrite(fid, sprintf('\n'), 'char');
        end
        % Close file
        fclose(fid);
        
    case 'EXCEL'
        % Save each frequency in a different sheet
        for i3 = 1:size(Data,3)
            % Sheet name
            if isempty(Label3)
                SheetName = 1;
            elseif iscell(Label3)
                SheetName = Label3{i3};
            else
                SheetName = Label3(i3);
            end
            % Save headers
            if ~isempty(Label1) && ~isempty(Label2)
                xlswrite(OutputFile, {Title2},   SheetName, 'A1');
                xlswrite(OutputFile, Label1(:),  SheetName, 'A2');
                xlswrite(OutputFile, Label2(:)', SheetName, 'B1');
                StartCell = 'B2';
            elseif ~isempty(Label1)
                xlswrite(OutputFile, Label1(:), SheetName, 'A1');
                StartCell = 'B1';
            elseif ~isempty(Label2)
                xlswrite(OutputFile, Label2(:)', SheetName, 'A1');
                StartCell = 'A2';
            else
                StartCell = 'A1';
            end
            % Save data as a new sheet
            [res,errMsg] = xlswrite(OutputFile, Data(:,:,i3), SheetName, StartCell);
            if ~res
                error(['Could not export file to Excel: ' 10 errMsg]);
            end
        end
end



                