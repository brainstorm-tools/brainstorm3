function [fid, nifti] = out_mri_nii( sMri, OutputFile, typeMatlab, Nt )
% OUT_MRI_NII: Exports a MRI to a NIFTI-1 file (.NII or .HDR/.IMG)).
% 
% USAGE:        out_mri_nii( sMri, OutputFile, typeMatlab)         : Write a full file
%         fid = out_mri_nii( sMri, OutputFile, typeMatlab, Nt=1 )  : Write the header and do not close the file before returning
%         ... = out_mri_nii( BstMriFile, ...)
%
% INPUT: 
%    - sMri       : Brainstorm MRI structure
%    - BstMriFile : Path to a MRI file in the Brainstorm database
%    - OutputFile : full path to output file (with '.img' or '.nii' extension)
%    - typeMatlab : string, type of data to write in the file: uint8, int16, int32, float32, double
%    - Nt         : Number of time points to write in the file
%                   If specified, writes only the header of the file (time frames will be written from calling function)
%
% NOTE: store binary files in Little Endian only

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2008-2021

% ===== PARSE INPUTS =====
% Write header of full file
if (nargin < 4) || isempty(Nt)
    Nt = [];
    isHdrOnly = 0;
else
    isHdrOnly = 1;
end
if (nargin < 3) || isempty(typeMatlab)
    typeMatlab = [];
end
% Little Endian
byteOrder = 'l'; 
% Output file
[OutputPath, OutputBase, OutputExt] = bst_fileparts(OutputFile);

% ===== LOAD BRAINSTORM MRI =====
% If input is a filename
if ischar(sMri)
    BstMriFile = sMri;
    sMri = in_mri_bst(BstMriFile);
end
if isempty(Nt)
    Nt = size(sMri.Cube, 4);
end
% Get maximum
MaxVal = max(abs(sMri.Cube(:)));
MinVal = min(sMri.Cube(:));
% Check value range
if isempty(typeMatlab)
    if (MinVal < 0) || any(sMri.Cube(:) ~= round(sMri.Cube(:)))
        typeMatlab   = 'float32';
    elseif (MaxVal <= 255)
        typeMatlab   = 'uint8';
    elseif all(MaxVal < 32767)
        typeMatlab   = 'int16';
    elseif all(MaxVal < 2147483647)
        typeMatlab   = 'int32';
    else
        typeMatlab   = 'float32';
    end
end
switch (typeMatlab)
    case 'uint8'
        hdr.datatype = 2;
        hdr.bitpix   = 8;
        sMri.Cube  = uint8(sMri.Cube);
    case 'int16'
        hdr.datatype = 4;
        hdr.bitpix   = 16;
        sMri.Cube  = int16(sMri.Cube);
    case 'int32'
        hdr.datatype = 8;
        hdr.bitpix   = 32;
        sMri.Cube  = int32(sMri.Cube);
    case 'float32'
        hdr.datatype = 16;
        hdr.bitpix   = 32;
        sMri.Cube  = single(sMri.Cube);
    case 'double'
        hdr.datatype = 32;
        hdr.bitpix   = 64;
        sMri.Cube  = double(sMri.Cube);
end
% Size of the volume
volDim = size(sMri.Cube(:,:,:,1));
% Set up other field values
hdr.dim    = [3 + (Nt > 1), volDim, Nt, 0, 0, 0];
hdr.pixdim = [1, sMri.Voxsize, 1, 0, 0, 0];
hdr.glmax  = MaxVal;


% ===== TRANSORMATION MATRICES ======
% Use existing matrices (from the header)
if isfield(sMri, 'Header') && isfield(sMri.Header, 'nifti') && all(isfield(sMri.Header.nifti, {'qform_code', 'sform_code', 'quatern_b', 'quatern_c', 'quatern_d', 'qoffset_x', 'qoffset_y', 'qoffset_z', 'srow_x', 'srow_y', 'srow_z'})) && isfield(sMri.Header, 'dim') && isfield(sMri.Header.dim, 'pixdim')
    nifti = sMri.Header.nifti;
    hdr.pixdim = sMri.Header.dim.pixdim;
% Use transformation matrices from other formats than .nii
else
    % === QFORM ===
    % XFORM_SCANNER: Scanner-based referential: from the vox2ras matrix
    if isfield(sMri, 'InitTransf') && ~isempty(sMri.InitTransf) && any(ismember(sMri.InitTransf(:,1), 'vox2ras'))
        nifti.qform_code = 1;  % NIFTI_XFORM_SCANNER_ANAT
        % Use directly the unmodified vox2ras from the original file
        iTransf = find(strcmpi(sMri.InitTransf(:,1), 'vox2ras'));
        nifti.qform = sMri.InitTransf{iTransf(1),2};
        % Convert from 4x4 transformations to quaternions
        R = nifti.qform(1:3, 1:3);
        T = nifti.qform(1:3, 4);
        a = 0.5  * sqrt(1 + R(1,1) + R(2,2) + R(3,3));
     	nifti.quatern_b = 0.25 * (R(3,2) - R(2,3)) / a;
     	nifti.quatern_c = 0.25 * (R(1,3) - R(3,1)) / a;
        nifti.quatern_d = 0.25 * (R(2,1) - R(1,2)) / a;
        nifti.qoffset_x = T(1);
        nifti.qoffset_y = T(2);
        nifti.qoffset_z = T(3);
    else
        nifti.qform_code = 0;
     	nifti.quatern_b = 0;
     	nifti.quatern_c = 0;
        nifti.quatern_d = 0;
        nifti.qoffset_x = 0;
        nifti.qoffset_y = 0;
        nifti.qoffset_z = 0;
    end

    % === SFORM ===
    % XFORM_MNI_152: Normalized coordinates (NCS field)
    if isfield(sMri, 'NCS') && isfield(sMri.NCS, 'R') && ~isempty(sMri.NCS.R) && isfield(sMri.NCS, 'T') && ~isempty(sMri.NCS.T)
        nifti.sform_code = 4;   % NIFTI_XFORM_MNI_152
        mri2world = cs_convert(sMri, 'mri', 'mni');
    % XFORM_ALIGNED: If no scanner coordinates (qform) or MNI normalization (sform): Just center the image on AC or the middle of the volume
    elseif (nifti.qform_code == 0)
        nifti.sform_code = 2;   % NIFTI_XFORM_ALIGNED_ANAT
        if isfield(sMri, 'NCS') && isfield(sMri.NCS, 'AC') && ~isempty(sMri.NCS.AC) 
            Origin = sMri.NCS.AC;
        elseif isfield(sMri, 'NCS') && isfield(sMri.NCS, 'Origin') && ~isempty(sMri.NCS.Origin)
            Origin = sMri.NCS.Origin;
        else
            Origin = volDim .* sMri.Voxsize / 2;
        end
        mri2world = [...
            1, 0, 0, -Origin(1) ./ 1000; ...
            0, 1, 0, -Origin(2) ./ 1000; ...
            0, 0, 1, -Origin(3) ./ 1000; 
            0, 0, 0, 1];
    % No sform
    else
        nifti.sform_code = 0;
        nifti.srow_x = [0 0 0 0];
        nifti.srow_y = [0 0 0 0];
        nifti.srow_z = [0 0 0 0];
    end
    % Convert Brainstorm transformation to nifti vox2ras
    if (nifti.sform_code ~= 0)
        % Convert from MRI(meters) to MRI(millimeters)
        vox2ras = mri2world;
        vox2ras(1:3,4) = vox2ras(1:3,4) .* 1000;
        % Convert from MRI(mm) to voxels
        vox2ras = vox2ras * diag([sMri.Voxsize, 1]);
        % Change reference from (0,0,0) to (1,1,1)
        nifti.sform = vox2ras * [1 0 0 1; 0 1 0 1; 0 0 1 1; 0 0 0 1];
        % Saved in sform format
        nifti.srow_x = nifti.sform(1,:);
        nifti.srow_y = nifti.sform(2,:);
        nifti.srow_z = nifti.sform(3,:);
    end
end


%% ===== SAVE ANALYZE HEADER (.NII or .HDR) =====
% Header file
switch(lower(OutputExt))
    case {'.hdr', '.img'}
        HeaderFile = bst_fullfile(OutputPath, [OutputBase '.hdr']);
        DataFile   = bst_fullfile(OutputPath, [OutputBase '.img']);
        isNifti = 0;
        hdr.vox_offset = 0;
    case '.nii'
        HeaderFile = bst_fullfile(OutputPath, [OutputBase '.nii']);
        DataFile   = [];
        isNifti = 1;
        hdr.vox_offset = 352;
    otherwise
        error(['Invalid format: "' OutputExt '"']);
end
% Open file for binary writing
[fid, message] = fopen(HeaderFile, 'wb', byteOrder);
if (fid == -1)
   error('Error opening header file \n%s', message);
end


% ===== SECTION 'header_key' =====
z = @(n)zeros(1,n);
fwrite(fid, 348,     'uint32');   % sizeof_hdr
fwrite(fid, z(10),   'uchar');    % data_type
fwrite(fid, z(18),   'uchar');    % db_name
fwrite(fid, 0,       'uint32');   % extents
fwrite(fid, 0,       'uint16');   % session_error
fwrite(fid, 'r',     'uchar');    % regular
if isNifti
    fwrite(fid, 32,  'uchar');    % dim_info
else
    fwrite(fid, 0, 'uchar');      % hkey_un0
end


% ===== SECTION 'image_dimension' =====
fwrite(fid, hdr.dim, 'uint16');     % dim
if isNifti
    fwrite(fid, [0 0 0], 'float32');% intent_p1, intent_p2, intent_p3
    fwrite(fid, 0,       'uint16'); % intent_code
else
    fwrite(fid, 'mm  ', 'uchar');   % vox_units
    fwrite(fid, z(8),   'uchar');   % cal_units
    fwrite(fid, 0,      'uint16');  % unused1
end
fwrite(fid, hdr.datatype, 'uint16');% datatype
fwrite(fid, hdr.bitpix, 'uint16');  % bitpix
if isNifti 
    fwrite(fid, 0, 'uint16');       % slice_start
else
    fwrite(fid, 0, 'uint16');       % dim_un0
end
fwrite(fid, hdr.pixdim,     'float32'); % pixdim
fwrite(fid, hdr.vox_offset, 'float32'); % vox_offset
if isNifti
    fwrite(fid, 0,  'float32');     % scl_slope
    fwrite(fid, 0,  'float32');     % scl_inter
    fwrite(fid, 0,  'uint16');      % slice_end
    fwrite(fid, 0,  'uchar');       % slice_code
    fwrite(fid, 18, 'uchar');       % xyzt_units
else
    fwrite(fid, 1, 'float32');      % funused1
    fwrite(fid, 0, 'float32');      % funused2  
    fwrite(fid, 0, 'float32');      % funused3
end
fwrite(fid, 0,         'float32');  % cal_max
fwrite(fid, 0,         'float32');  % cal_min
fwrite(fid, 0,         'float32');  % compressed
fwrite(fid, 0,         'uint32');   % verified
fwrite(fid, hdr.glmax, 'uint32');   % glmax
fwrite(fid, 0,         'uint32');


% ===== SECTION 'data_history' =====
desc = z(80);
desc(1:23) = 'Written with Brainstorm';
fwrite(fid, desc,  'uchar');         % descrip
fwrite(fid, z(24), 'uchar');         % aux_file
if isNifti 
    fwrite(fid, nifti.qform_code, 'uint16');    % qform_code
    fwrite(fid, nifti.sform_code, 'uint16'); 
    fwrite(fid, nifti.quatern_b,  'float');
    fwrite(fid, nifti.quatern_c,  'float');
    fwrite(fid, nifti.quatern_d,  'float');
    fwrite(fid, nifti.qoffset_x,  'float');
    fwrite(fid, nifti.qoffset_y,  'float');
    fwrite(fid, nifti.qoffset_z,  'float');
    fwrite(fid, nifti.srow_x,  'float');   % sform
    fwrite(fid, nifti.srow_y,  'float');   % sform
    fwrite(fid, nifti.srow_z,  'float');   % sform
    fwrite(fid, z(16), 'uchar');     % intent_name
    fwrite(fid, ['n+1' 0], 'uchar'); % magic
    fwrite(fid, z(4),      'uchar'); % end...
else    
    fwrite(fid, 0, 'uchar');         % orient
    fwrite(fid, z(5), 'int16');      % originator
    fwrite(fid, z(10), 'uchar');     % generated
    fwrite(fid, z(10), 'uchar');     % scannum
    fwrite(fid, z(10), 'uchar');     % patient_id
    fwrite(fid, z(10), 'uchar');     % exp_date
    fwrite(fid, z(10), 'uchar');     % exp_time
    fwrite(fid, z(3), 'uchar');      % hist_un0
    fwrite(fid, 0, 'uint32');        % views
    fwrite(fid, 0, 'uint32');        % vols_added
    fwrite(fid, 0, 'uint32');        % start_field
    fwrite(fid, 0, 'uint32');        % field_skip
    fwrite(fid, 0, 'uint32');        % omax
    fwrite(fid, 0, 'uint32');        % omin
    fwrite(fid, 0, 'uint32');        % smax
    fwrite(fid, 0, 'uint32');        % smin
end
      

%% ===== SAVE ANALYZE VOLUME (.IMG) =====
if ~isempty(DataFile)
    % Close header file and open image file
    fclose(fid);
    [fid, message] = fopen(DataFile, 'wb', byteOrder);
    if fid == -1
        error('Error opening image file: "%s".', message);
    end
else
    % Continue with the same 
    % Pad with zeros to reach minimum header size
    npad = hdr.vox_offset - ftell(fid);
    fwrite(fid, z(npad), 'uchar');
end

% Dimensions
% Nx = hdr.dim(2);    % Number of pixels in X
% Ny = hdr.dim(3);    % Number of pixels in Y
Nz = hdr.dim(4);      % Number of Z slices
% Nt = hdr.dim(5);    % Number of time frames

% Write image file
if ~isHdrOnly
    % Nxy = Nx*Ny;
    for t = 1:Nt
        for z = 1:Nz
            count = fwrite(fid, sMri.Cube(:,:,z,t), typeMatlab);
%             if (count ~= Nxy)
%                 fclose(fid);
%                 error('Error writing file');
%             end
        end
    end
    fclose(fid);
end

end

