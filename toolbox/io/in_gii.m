function [sXml, Values] = in_gii(GiiFile)
% IN_GII: Read all the DataArray entries from a .gii file.

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

import sun.misc.BASE64Decoder;

% Read XML file
sXml = in_xml(GiiFile);

% Inialize returned values
nArrays = length(sXml.GIFTI.DataArray);
Values = cell(1,nArrays);

% For each data entry
for iArray = 1:nArrays
    % Get dimensions
    sizeValue = [1 1 1];
    if isfield(sXml.GIFTI.DataArray(iArray), 'Dim0') && ~isempty(sXml.GIFTI.DataArray(iArray).Dim0)
        sizeValue(1) = str2double(sXml.GIFTI.DataArray(iArray).Dim0);
    end
    if isfield(sXml.GIFTI.DataArray(iArray), 'Dim1') && ~isempty(sXml.GIFTI.DataArray(iArray).Dim1)
        sizeValue(2) = str2double(sXml.GIFTI.DataArray(iArray).Dim1);
    end
    % Get data type
    switch (sXml.GIFTI.DataArray(iArray).DataType)
        case 'NIFTI_TYPE_UINT8',   DataType = 'uint8';
        case 'NIFTI_TYPE_INT16',   DataType = 'int16';   
        case 'NIFTI_TYPE_INT32',   DataType = 'int32';
        case 'NIFTI_TYPE_FLOAT32', DataType = 'single';
        case 'NIFTI_TYPE_FLOAT64', DataType = 'double';
    end
    
    % Read the file
    switch sXml.GIFTI.DataArray(iArray).Encoding
        case 'ASCII'
            Values{iArray} = str2num(sXml.GIFTI.DataArray(iArray).Data.text)';
            
        case {'Base64Binary', 'GZipBase64Binary'}
            % Base64 decoding
            decoder = BASE64Decoder();
            Values{iArray} = decoder.decodeBuffer(sXml.GIFTI.DataArray(iArray).Data.text);
            % Unpack gzipped stream
            if strcmpi(sXml.GIFTI.DataArray(iArray).Encoding, 'GZipBase64Binary')
                Values{iArray} = dunzip(Values{iArray});
            end
            % Cast to the required type of data
            Values{iArray} = typecast(Values{iArray}, DataType);
            
        case 'ExternalFileBinary'
            % Get binary filename
            DatFile = sXml.GIFTI.DataArray(iArray).ExternalFileName;
            % If file doesn't exist, look for local file
            if ~file_exist(DatFile)
                DatFile = fullfile(bst_fileparts(GiiFile), DatFile);
                if ~file_exist(DatFile)
                    error(['ExternalFileName does not exist: ' DatFile]);
                end
            end
            % Get file offset
            if isfield(sXml.GIFTI.DataArray(iArray), 'ExternalFileOffset') && ~isempty(sXml.GIFTI.DataArray(iArray).ExternalFileOffset)
                offset = str2num(sXml.GIFTI.DataArray(iArray).ExternalFileOffset);
                if isempty(offset)
                    offset = 0;
                end
            else
                offset = 0;
            end
            % Open file for binary reading
            fid = fopen(DatFile,'rb');
            if (fid < 0)
                error(['Could not open file : ' message]);
            end
            % Seek in file to the target offset
            fseek(fid, offset, 'bof');
            % Read data vector
            Values{iArray} = fread(fid, [1,prod(sizeValue)], DataType);
            % Close file
            fclose(fid);
    end

    % Reshape matrix to target size
    if ~isempty(Values{iArray}) && isfield(sXml.GIFTI.DataArray(iArray), 'ArrayIndexingOrder')
        % Change order
        switch (sXml.GIFTI.DataArray(iArray).ArrayIndexingOrder)
            case 'ColumnMajorOrder'
                Values{iArray} = reshape(Values{iArray}, sizeValue);
            case 'RowMajorOrder'
                Values{iArray} = reshape(Values{iArray}, sizeValue([2 1]))';
        end
    end
end







