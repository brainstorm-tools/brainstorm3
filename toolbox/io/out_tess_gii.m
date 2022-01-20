function out_tess_gii( TessMat, OutputFile, isSPM )
% OUT_TESS_GII: Exports a surface to a GIfTI/BrainVisa .gii tessellation files.
% 
% USAGE:  out_tess_gii( TessMat,  OutputFile, isSPM=0 )
%         out_tess_gii( TessFile, OutputFile, isSPM=0 )
%
% INPUT: 
%    - TessMat    : Brainstorm tesselation matrix
%    - OutputFile : full path to output file
%    - isSPM      : If 1, save the coordinates in MNI coordinates (millimeters) instead of SCS/meters 

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
% Authors: Francois Tadel, 2013-2015

% ===== PARSE INPUTS =====
% Default units: meters
if (nargin < 3) || isempty(isSPM)
    isSPM = 1;
end
% Load surface
if ischar(TessMat)
    TessFile = TessMat;
    TessMat = in_tess_bst(TessMat);
else
    TessFile = [];
end

% ===== CONVERT TO MNI COORDINATES =====
% For export to SPM
if isSPM && ~isempty(TessFile)
    % Get subject
    sSubject = bst_get('SurfaceFile', TessFile);
    % Get MRI file
    MriFile = sSubject.Anatomy(1).FileName;
    % Load the MRI
    sMri = in_mri_bst(MriFile);
    % Get transformation
    if ~isfield(sMri, 'NCS') || ~isfield(sMri.NCS, 'R') || isempty(sMri.NCS.R)
        sMri.NCS.R = [1 0 0; 0 1 0; 0 0 1];
        sMri.NCS.T = -size(sMri.Cube(:,:,:,1))'./2;
    end
    % Convert MNI coordinates
    TessMat.Vertices = cs_convert(sMri, 'scs', 'mni', TessMat.Vertices);
end

% ===== ENCODE DATA =====
import sun.misc.BASE64Encoder;
% Initialize Base64 encoder
encoder = BASE64Encoder();
% Encode vertices: millimeters
Vertices = single(TessMat.Vertices' .* 1000);
Vertices = typecast(Vertices(:), 'uint8');
Vertices = char(encoder.encodeBuffer(Vertices));
Vertices((Vertices == 10) | (Vertices == 13)) = [];
% Encode faces: 0-based array
Faces = int32(TessMat.Faces' - 1);
Faces = typecast(Faces(:), 'uint8');
Faces = char(encoder.encodeBuffer(Faces));
Faces((Faces == 10) | (Faces == 13)) = [];
 
% ===== CREATE XML STRING =====   
% Create XML file from a template
strXml = [...
    '<?xml version="1.0" encoding="UTF-8"?>' 13 10 ...
    '<!DOCTYPE GIFTI SYSTEM "http://gifti.projects.nitrc.org/gifti.dtd">' 13 10 ...
    '<GIFTI Version="1.0"  NumberOfDataArrays="2">' 13 10 ...
    '   <MetaData />' 13 10 ...
    '   <LabelTable/>' 13 10 ...
    '   <DataArray Intent="NIFTI_INTENT_POINTSET"' 13 10 ...
    '              DataType="NIFTI_TYPE_FLOAT32"' 13 10 ...
    '              ArrayIndexingOrder="RowMajorOrder"' 13 10 ...
    '              Dimensionality="2"' 13 10 ...
    '              Dim0="' num2str(size(TessMat.Vertices,1)) '"' 13 10 ...
    '              Dim1="3"' 13 10 ...
    '              Encoding="Base64Binary"' 13 10 ...
    '              Endian="LittleEndian"' 13 10 ...
    '              ExternalFileName=""' 13 10 ...
    '              ExternalFileOffset="">' 13 10 ...
    '      <MetaData>' 13 10 ...
    '      </MetaData>' 13 10 ...
    '      <CoordinateSystemTransformMatrix>' 13 10 ...
    '          <DataSpace><![CDATA[NIFTI_XFORM_UNKNOWN]]></DataSpace>' 13 10 ...
    '           <TransformedSpace><![CDATA[NIFTI_XFORM_UNKNOWN]]></TransformedSpace>' 13 10 ...
    '          <MatrixData>1.000000 0.000000 0.000000 0.000000 0.000000 1.000000 0.000000 0.000000 0.000000 0.000000 1.000000 0.000000 0.000000 0.000000 0.000000 1.000000 </MatrixData>' 13 10 ...
    '      </CoordinateSystemTransformMatrix>' 13 10 ...
    '      <Data>' Vertices '</Data>' 13 10 ...
    '   </DataArray>' 13 10 ...
    '   <DataArray Intent="NIFTI_INTENT_TRIANGLE"' 13 10 ...
    '              DataType="NIFTI_TYPE_INT32"' 13 10 ...
    '              ArrayIndexingOrder="RowMajorOrder"' 13 10 ...
    '              Dimensionality="2"' 13 10 ...
    '              Dim0="' num2str(size(TessMat.Faces,1)) '"' 13 10 ...
    '              Dim1="3"' 13 10 ...
    '              Encoding="Base64Binary"' 13 10 ...
    '              Endian="LittleEndian"' 13 10 ...
    '              ExternalFileName=""' 13 10 ...
    '              ExternalFileOffset="">' 13 10 ...
    '      <MetaData/>' 13 10 ...
    '      <Data>' Faces '</Data>' 13 10 ...
    '   </DataArray>' 13 10 ...
    '</GIFTI>' 13 10];


% ===== SAVE XML FILE =====
% Open file for binary writing
[fid, message] = fopen(OutputFile, 'wb');
if (fid < 0)
    error(['Could not create file : ' message]);
end
% Write XML contents
fwrite(fid, strXml, 'char');
% Close file
fclose(fid);

end



