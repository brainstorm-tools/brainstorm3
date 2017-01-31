function TessMat = in_tess_gii(TessFile)
% IN_TESS_GII: Import GIfTI/BrainVisa .gii tessellation files.
%
% USAGE:  TessMat = in_tess_gii(TessFile);
%
% INPUT: 
%     - TessFile : full path to a tesselation file
% OUTPUT:
%     - TessMat:  Brainstorm tesselation structure
%
% SEE ALSO: in_tess

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2016 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2012

import sun.misc.BASE64Decoder;

% Initialize returned value
TessMat = struct('Vertices', [], 'Faces', []);
% Read XML file
sXml = in_xml(TessFile);
% For each data entry
for iArray = 1:length(sXml.GIFTI.DataArray)
    % Check for necessary fields
    if ~all(isfield(sXml.GIFTI.DataArray(iArray), {'Dim0', 'Dim1', 'DataType', 'Encoding', 'ArrayIndexingOrder', 'Intent'}))
        error('This file does not contain a valid tesselation.');
    end
    % Get size
    sizeValue = [str2double(sXml.GIFTI.DataArray(iArray).Dim0), str2double(sXml.GIFTI.DataArray(iArray).Dim1)];
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
            value = str2num(sXml.GIFTI.DataArray(iArray).Data.text)';
        case {'Base64Binary', 'GZipBase64Binary'}
            % Base64 decoding
            decoder = BASE64Decoder();
            value = decoder.decodeBuffer(sXml.GIFTI.DataArray(iArray).Data.text);
            % Unpack gzipped stream
            if strcmpi(sXml.GIFTI.DataArray(iArray).Encoding, 'GZipBase64Binary')
                value = dunzip(value);
            end
            % Cast to the required type of data
            value = typecast(value, DataType);
        case 'ExternalFileBinary'
            % Get binary filename
            DatFile = sXml.GIFTI.DataArray(iArray).ExternalFileName;
            % If file doesn't exist, look for local file
            if ~file_exist(DatFile)
                DatFile = fullfile(bst_fileparts(TessFile), DatFile);
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
            value = fread(fid, [1,prod(sizeValue)], DataType);
            % Close file
            fclose(fid);
    end
    
    % Reshape matrix to target size
    switch (sXml.GIFTI.DataArray(iArray).ArrayIndexingOrder)
        case 'ColumnMajorOrder'
            value = reshape(value, sizeValue);
        case 'RowMajorOrder'
            value = reshape(value, sizeValue([2 1]))';
    end
    % Identify type
    switch (sXml.GIFTI.DataArray(iArray).Intent)
        case 'NIFTI_INTENT_POINTSET'
            TessMat.Vertices = double(value) ./ 1000;
        case 'NIFTI_INTENT_TRIANGLE'
            TessMat.Faces = double(value) + 1;
    end
end

% Make sure that the file was properly read
if isempty(TessMat.Vertices) || isempty(TessMat.Faces)
    error('This file does not contain a valid tesselation: NIFTI_INTENT_POINTSET or NIFTI_INTENT_TRIANGLE missing.');
end





