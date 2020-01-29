function [sMri, vox2ras] = in_mri_nii(MriFile, isReadMulti, isApply)
% IN_MRI_NII: Reads a structural NIfTI/Analyze MRI.
%
% USAGE:  [sMri, vox2ras] = in_mri_nii(MriFile, isReadMulti=0, isApply=[ask]);
%
% INPUT: 
%    - MriFile     : name of file to open, WITH EXTENSION
%    - isReadMulti : If 1, allow reading multiple volumes from the same file
%    - isApply     : If 1, apply best orientation found to match Brainstorm convention
%
% OUTPUT:
%    - sMri    : Brainstorm MRI structure
%    - vox2ras : [4x4] transformation matrix: voxels to RAS coordinates
%                (corresponds to MNI coordinates if the volume is registered to the MNI space)
%
% FORMATS:
%     - Analyze7.5 (.hdr/.img)
%     - NIFTI-1 (.hdr/.img or .nii)

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
% Authors: Francois Tadel, 2008-2017

sMri = [];
vox2ras = [];
% Parse inputs
if (nargin < 3) || isempty(isApply)
    isApply = [];
end
if (nargin < 2) || isempty(isReadMulti)
    isReadMulti = 0;
end

% ===== READ FILE =====
[filepath, baseName, extension] = bst_fileparts(MriFile);
switch(lower(extension))               
    % NIFTI-1 (single file) : documentation at http://nifti.nimh.nih.gov/nifti-1/
    case '.nii'
        fid = nifti_open_hdr(MriFile);
        if fid==-1, disp(sprintf('in_mri_nii : Error opening header file')); return; end
        % Read file header
        hdr = nifti_read_hdr(fid, isReadMulti);
        if isempty(hdr), disp(sprintf('in_mri_nii : Error reading header file')); return; end
        % Read image (3D matrix)
        fseek(fid, double(hdr.dim.vox_offset), 'bof');
        data = nifti_read_img(fid, hdr);
        fclose(fid);
        if isempty(data), disp('in_mri_nii : Error reading image file'); return; end
        
    % ANALYZE7.5 or NIFTI-1 (dual file .HDR/.IMG)
    case {'.hdr', '.img'}
        % Make sure that both .hdr and .img files are present
        hdrFilename = bst_fullfile(filepath, [baseName '.hdr']);
        imgFilename = bst_fullfile(filepath, [baseName '.img']);
        if ~file_exist(hdrFilename), disp(sprintf('in_mri_nii : Missing header file (%s)', hdrFilename)); return; end
        if ~file_exist(imgFilename), disp(sprintf('in_mri_nii : Missing image file (%s)', imgFilename)); return; end
        % Read header file
        [fid, byteOrder] = nifti_open_hdr(hdrFilename);
        if fid==-1, disp(sprintf('in_mri_nii : Error opening header file')); return; end
        hdr = nifti_read_hdr(fid, isReadMulti);
        if isempty(hdr), disp(sprintf('in_mri_nii : Error reading header file')); return; end
        fclose(fid);
        % Read image file
        [fid, message] = fopen(imgFilename, 'r', byteOrder);
        if fid == -1, disp(sprintf('in_mri_nii : %s', message)); return; end
        data = nifti_read_img(fid, hdr);
        fclose(fid);
        
    otherwise
        error('Unsupported file format');
end


% ===== UNITS =====
% === NIfTI UNITS ===
if ~isempty(hdr.nifti)
    if (hdr.nifti.xyzt_units ~= 0)
        % Convert spatial units
        xyzunits = bitand(hdr.nifti.xyzt_units,7); % 0x7
        switch(xyzunits)
            case 1, xyzscale = 1000.000; % meters
            case 2, xyzscale =    1.000; % mm
            case 3, xyzscale =     .001; % microns
        end
        if (xyzunits ~= 1)
            hdr.dim.pixdim(2:4) = hdr.dim.pixdim(2:4) * xyzscale;
            hdr.nifti.srow_x = hdr.nifti.srow_x * xyzscale;
            hdr.nifti.srow_y = hdr.nifti.srow_y * xyzscale;
            hdr.nifti.srow_z = hdr.nifti.srow_z * xyzscale;
        end
        % Convert temporal units
        tunits = bitand(hdr.nifti.xyzt_units,3*16+8); % 0x38 
        switch(tunits)
            case  8, tscale = 1000.000; % seconds
            case 16, tscale =    1.000; % msec
            case 32, tscale =     .001; % microsec
            otherwise,  tscale = 0;
        end
        if (tscale ~= 1)
            hdr.dim.pixdim(5) = hdr.dim.pixdim(5) * tscale;
        end
        % Change value in xyzt_units to reflect scale change
        hdr.nifti.xyzt_units = bitor(2,16); % 2=mm, 16=msec
    end
% === ANALYZE UNITS ===
else
    switch (deblank(hdr.dim.vox_units))
        case 'mm'
            factor = 1;
        case 'm'
            factor = 1000;
        otherwise
            factor = 1;
    end
    hdr.dim.pixdim(2:4) = (double(hdr.dim.pixdim(2:4)) * factor);
end
% Voxel size
Voxsize = abs(hdr.dim.pixdim(2:4));

% ===== CREATE BRAINSTORM STRUCTURE =====
sMri = struct('Cube',   data, ...
             'Voxsize', Voxsize, ...
             'Comment', 'MRI', ...
             'Header',  hdr);

% ===== NIFTI ORIENTATION =====
% Apply orientation to the volume
if ~isempty(hdr.nifti) && ~isempty(hdr.nifti.vox2ras)
    [vox2ras, sMri] = cs_nii2bst(sMri, hdr.nifti.vox2ras, isApply);
end

end




%% =================================================================================================
%  ====== HELPER FUNCTIONS =========================================================================
%  =================================================================================================
%% ===== OPEN HEADER =====
function [fid, byteOrder] = nifti_open_hdr(MriFile)
    % Open file for reading only (trying little endian byte order)
    [fid, message] = fopen(MriFile, 'r', 'ieee-le');
    if fid == -1, disp(sprintf('in_mri_nii : %s', message)); return; end
    % Detect data byte order (little endian or big endian)
    fseek(fid,40,'bof');
    dim_zero = fread(fid,1,'uint16');
    % dim_zero must be a number between 1 and 7, else try a big endian byte order
    if(dim_zero < 1 || dim_zero > 7)
        fclose(fid);
        fopen(MriFile, 'r', 'ieee-be');
        fseek(fid,40,'bof');
        dim_zero = fread(fid,1,'uint16');
        if(dim_zero < 1 || dim_zero > 7) % ERROR
            fid = -1;
            return;
        end
        byteOrder = 'ieee-be';
    else
        byteOrder = 'ieee-le';
    end
    fseek(fid,0,'bof');
end 


%% ===== READ HEADER =====
% Reads an Analyze7.5 or a NIFTI-1 header file
function hdr = nifti_read_hdr(fid, isReadMulti)
    % ===== ANALYZE : Section 'header_key' =====
    key.sizeof_hdr    = fread(fid,1,'uint32');
    key.data_type     = char(fread(fid,[1,10],'uchar'));   
    key.db_name       = char(fread(fid,[1,18],'uchar'));
    key.extents       = fread(fid,1,'uint32'); 
    key.session_error = fread(fid,1,'uint16');
    key.regular       = char(fread(fid,1,'uchar'));
    key.hkey_un0      = char(fread(fid,1,'uchar'));

    % ===== ANALYZE : Section 'image_dimension' =====
    dim.dim        = fread(fid,[1,8],'uint16');
    dim.vox_units  = char(fread(fid,[1,4],'uchar'));
    dim.cal_units  = char(fread(fid,[1,8],'uchar'));
    dim.unused1    = fread(fid,1,'uint16');
    dim.datatype   = fread(fid,1,'uint16');
    dim.bitpix     = fread(fid,1,'uint16');
    dim.dim_un0    = fread(fid,1,'uint16');
    dim.pixdim     = fread(fid,[1,8],'float32');    % in disk it is a float !!!!!!
    dim.vox_offset = fread(fid,1,'float32');    % in disk it is a float !!!!!!
    dim.funused1   = fread(fid,1,'float32');      % in disk it is a float !!!!!!
    dim.funused2   = fread(fid,1,'float32');      % in disk it is a float !!!!!!
    dim.funused3   = fread(fid,1,'float32');      % in disk it is a float !!!!!!
    dim.cal_max    = fread(fid,1,'float32');       % in disk it is a float !!!!!!
    dim.cal_min    = fread(fid,1,'float32');       % in disk it is a float !!!!!!
    dim.compressed = fread(fid,1,'uint32');      
    dim.verified   = fread(fid,1,'uint32');      
    dim.glmax      = fread(fid,1,'uint32'); 
    dim.glmin      = fread(fid,1,'uint32');

    % ===== ANALYZE : Section 'image_dimensions' =====
    hist.descrip     = char(fread(fid,[1,80],'uchar'));
    hist.aux_file    = char(fread(fid,[1,24],'uchar'));
    hist.orient      = fread(fid,1,'uchar');
    hist.originator  = fread(fid,[1,5],'int16');
    hist.generated   = char(fread(fid,[1,10],'uchar'));
    hist.scannum     = char(fread(fid,[1,10],'uchar'));
    hist.patient_id  = char(fread(fid,[1,10],'uchar'));
    hist.exp_date    = char(fread(fid,[1,10],'uchar'));
    hist.exp_time    = char(fread(fid,[1,10],'uchar'));
    hist.hist_un0    = char(fread(fid,[1,3],'uchar'));
    hist.views       = fread(fid,1,'uint32');
    hist.vols_added  = fread(fid,1,'uint32');
    hist.start_field = fread(fid,1,'uint32');
    hist.field_skip  = fread(fid,1,'uint32');
    hist.omax        = fread(fid,1,'uint32');
    hist.omin        = fread(fid,1,'uint32');
    hist.smax        = fread(fid,1,'uint32');
    [hist.smin, cnt] = fread(fid,1,'uint32');
    if (cnt ~= 1)
        error('Error opening file : Incomplete header');
    end

    % ===== NIfTI-specific section =====
    % Read identification string
    fseek(fid, 344, 'bof');
    [nifti.magic, count] = fread(fid,[1,4],'uchar');
    % Detect file type
    isNifti = ismember(deblank(char(nifti.magic)), {'ni1', 'n+1'});
    % If file is a real NIfTI-1 file : read other values
    if isNifti
        nifti.dim_info = key.hkey_un0;
        fseek(fid, 56, 'bof');
        nifti.intent_p1 = fread(fid,1,'float32');
        nifti.intent_p2 = fread(fid,1,'float32');
        nifti.intent_p3 = fread(fid,1,'float32');
        nifti.intent_code = fread(fid,1,'uint16');
        nifti.slice_start = dim.dim_un0;
        nifti.scl_slope = dim.funused1;
        nifti.scl_inter = dim.funused2;
        fseek(fid, 120, 'bof');
        nifti.slice_end = fread(fid,1,'uint16');
        nifti.slice_code = fread(fid,1,'uchar');
        nifti.xyzt_units = fread(fid,1,'uchar');
        nifti.slice_duration = dim.compressed;
        nifti.toffset = dim.verified;
        fseek(fid, 252, 'bof');
        nifti.qform_code = fread(fid,1,'uint16');
        nifti.sform_code = fread(fid,1,'uint16');
        nifti.quatern_b = fread(fid,1,'float32');
        nifti.quatern_c = fread(fid,1,'float32');
        nifti.quatern_d = fread(fid,1,'float32');
        nifti.qoffset_x = fread(fid,1,'float32');
        nifti.qoffset_y = fread(fid,1,'float32');
        nifti.qoffset_z = fread(fid,1,'float32');
        nifti.srow_x = fread(fid,[1,4],'float32');
        nifti.srow_y = fread(fid,[1,4],'float32');
        nifti.srow_z = fread(fid,[1,4],'float32');
        nifti.intent_name = fread(fid,[1,16],'uchar');
    else
        nifti = [];
    end
    if (count ~= 4)
        error('Unknown error');
    end

    % ===== NIFTI ORIENTATION =====
    if ~isempty(nifti)
        % Sform matrix
        if ~isempty(nifti.srow_x) && ~isequal(nifti.srow_x, [0 0 0 0])
            nifti.sform = [...
                nifti.srow_x;
                nifti.srow_y;
                nifti.srow_z;
                0 0 0 1];
        else
            nifti.sform = [];
        end

        % Qform matrix - not quite sure how all this works,
        % mainly just copied CH's code from mriio.c
        b = nifti.quatern_b;
        c = nifti.quatern_c;
        d = nifti.quatern_d;
        x = nifti.qoffset_x;
        y = nifti.qoffset_y;
        z = nifti.qoffset_z;
        a = 1.0 - (b*b + c*c + d*d);
        if(abs(a) < 1.0e-7)
            a = 1.0 / sqrt(b*b + c*c + d*d);
            b = b*a;
            c = c*a;
            d = d*a;
            a = 0.0;
        else
            a = sqrt(a);
        end
        r11 = a*a + b*b - c*c - d*d;
        r12 = 2.0*b*c - 2.0*a*d;
        r13 = 2.0*b*d + 2.0*a*c;
        r21 = 2.0*b*c + 2.0*a*d;
        r22 = a*a + c*c - b*b - d*d;
        r23 = 2.0*c*d - 2.0*a*b;
        r31 = 2.0*b*d - 2*a*c;
        r32 = 2.0*c*d + 2*a*b;
        r33 = a*a + d*d - c*c - b*b;
        if(dim.pixdim(1) < 0.0)
            r13 = -r13;
            r23 = -r23;
            r33 = -r33;
        end
        qMdc = [r11 r12 r13; r21 r22 r23; r31 r32 r33];
        D = diag(dim.pixdim(2:4));
        P0 = [x y z]';
        nifti.qform = [qMdc*D P0; 0 0 0 1];

        % Build final transformation matrix
        if (nifti.sform_code ~= 0) && ~isempty(nifti.sform) && ~isequal(nifti.sform(1:3,1:3),zeros(3)) && ~isequal(nifti.sform(1:3,1:3),eye(3))
            nifti.vox2ras = nifti.sform;
        elseif (nifti.qform_code ~= 0) && ~isempty(nifti.qform) && ~isequal(nifti.qform(1:3,1:3),zeros(3)) && ~isequal(nifti.qform(1:3,1:3),eye(3))
            nifti.vox2ras = nifti.qform;
        % Same thing, but accept identity rotations
        elseif (nifti.sform_code ~= 0) && ~isempty(nifti.sform) && ~isequal(nifti.sform(1:3,1:3),zeros(3))
            nifti.vox2ras = nifti.sform;
        elseif (nifti.qform_code ~= 0) && ~isempty(nifti.qform) && ~isequal(nifti.qform(1:3,1:3),zeros(3))
            nifti.vox2ras = nifti.qform;
        else
            nifti.vox2ras = [];
        end
    end
    
    % ===== Test header values =====
    Ndim = dim.dim(1);  % Number of dimensions
    Nt = dim.dim(5);    % Number of time frames
    if ~isReadMulti && ~(((Ndim == 4) && (Nt == 1)) || (Ndim == 3))
        error('Support only for 3D data set' );
    end
    
    % ===== Report results =====
    hdr.key = key;
    hdr.dim = dim;
    hdr.hist = hist;
    hdr.nifti = nifti;
end



%% ===== READ IMG =====
function data = nifti_read_img(fid, hdr)
    % Data type to read
    switch (hdr.dim.datatype)
        % Analyze-compatible codes
        case {1,2},   datatype = 'uint8';
        case 4,       datatype = 'int16';
        case 8,       datatype = 'int32';
        case 16,      datatype = 'single';
        case {32,64}, datatype = 'double';
        % NIfTI-specific codes
        case 256,     datatype = 'int8';
        case 512,     datatype = 'uint16';
        case 768,     datatype = 'uint32';
        case 1024,    datatype = 'int64';
        case 1280,    datatype = 'uint64';
        otherwise,    error('Unsupported data type');
    end

    % Dimensions of the MRI
    Nx = hdr.dim.dim(2);    % Number of pixels in X
    Ny = hdr.dim.dim(3);    % Number of pixels in Y
    Nz = hdr.dim.dim(4);    % Number of Z slices
    Nt = hdr.dim.dim(5);    % Number of time frames
    if (Nt == 0)
        Nt = 1;
    end
    % Read data
    data = repmat(cast(1, datatype),[Nx,Ny,Nz,Nt]);
    Nxy = Nx*Ny;
    for t = 1:Nt,
       for z = 1:Nz,
          [temp, cont] = fread(fid, [Nx,Ny], datatype);
          if (cont ~= Nxy) % ERROR
              data = [];
              return;
          end
          data(:,:,z,t) = temp;
       end
    end
end




        