function out_mri_ctf( sMri, OutputFile )
% OUT_MRI_CTF: Exports a Brainstorm MRI in CTF .mri file format, Version 4.1
%
% USAGE:  out_mri_ctf( sMri, OutputFile )
%
% INPUT: 
%    - sMri       : Brainstorm MRI structure
%    - OutputFile : full path to output file (with '.mri' extension)
% 
% FORMAT: For the documentation of the CTF .mri format (Version 4.1), see in_mri_ctf.m
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
% Authors: Francois Tadel, 2011-2015

% Keep only the first volume, if multiple
sMri.Cube = sMri.Cube(:,:,:,1);

% ===== CONVERT FIDUCIALS =====
nas = [sMri.SCS.NAS(1) ./ sMri.Voxsize(1), ...
       size(sMri.Cube,2) - sMri.SCS.NAS(2) ./ sMri.Voxsize(2), ...
       size(sMri.Cube,3) - sMri.SCS.NAS(3) ./ sMri.Voxsize(3)];
lpa = [sMri.SCS.LPA(1) ./ sMri.Voxsize(1), ...
       size(sMri.Cube,2) - sMri.SCS.LPA(2) ./ sMri.Voxsize(2), ...
       size(sMri.Cube,3) - sMri.SCS.LPA(3) ./ sMri.Voxsize(3)];
rpa = [sMri.SCS.RPA(1) ./ sMri.Voxsize(1), ...
       size(sMri.Cube,2) - sMri.SCS.RPA(2) ./ sMri.Voxsize(2), ...
       size(sMri.Cube,3) - sMri.SCS.RPA(3) ./ sMri.Voxsize(3)];
center = (lpa + rpa) ./ 2;
transf = [[sMri.SCS.R; center], [0;0;0;1]];

% ===== CONVERT VOLUME =====
% Pad to 256x256x256
Vol = zeros(256, 256, 256, 'uint16');
s = size(sMri.Cube);
ind1 = 1:min(256,s(1));
ind2 = 1:min(256,s(2));
ind3 = 1:min(256,s(3));
Vol(ind1,ind2,ind3) = sMri.Cube(ind1,ind2,ind3);
% Re-orient
Vol = Vol(:, end:-1:1, end:-1:1);
Vol = permute(Vol, [2 3 1]);
Vol = reshape(Vol, 256 * 256, 256);
   
    
% ===== WRITE CTF TAGS ======
% Open file (binary, bin-endian)
fid = fopen(OutputFile, 'wb', 'ieee-be'); 
if (fid < 0)
    error('Cannot open file : "%s"', OutputFile);
end
% Write format type: Version 4.1
fwrite(fid, 'WS1_', 'uchar');
% Write tags
write_tag('_CTFMRI_VERSION', 10, 'CTF_MRI_FORMAT VER 4.1');
write_tag('_CTFMRI_UID', 10, '2.16.124.113589.000000.20090305180445.643787599.033833457.0000');
write_tag('_HDM_NASION', 10, sprintf('%3.10f\\%3.10f\\%3.10f', nas));
write_tag('_HDM_LEFTEAR', 10, sprintf('%3.10f\\%3.10f\\%3.10f', lpa));
write_tag('_HDM_RIGHTEAR', 10, sprintf('%3.10f\\%3.10f\\%3.10f', rpa));
write_tag('_HDM_DEFAULTSPHERE', 10, '6.9716758728\-0.5730150342\45.8437728882\97.7487106323');
write_tag('_CTFMRI_ROTATE', 10, '0.0000000000\0.0000000000\0.0000000000');
write_tag('_CTFMRI_SIZE', 6, 256);
write_tag('_CTFMRI_DATASIZE', 6, 2);
write_tag('_CTFMRI_MMPERPIXEL', 10, sprintf('%3.10f\\%3.10f\\%3.10f', sMri.Voxsize));
write_tag('_HDM_HEADORIGIN', 10, sprintf('%3.10f\\%3.10f\\%3.10f', center));
write_tag('_CTFMRI_ORTHOGONALFLAG', 6, 0);
write_tag('_CTFMRI_INTERPOLATEDFLAG', 6, 1);
write_tag('_CTFMRI_TRANSFORMMATRIX', 10, [sprintf('%3.10f', transf(1)), sprintf('\\%3.10f', transf(2:end))]);
write_tag('_CTFMRI_COMMENT', 10, '');
write_tag('_PATIENT_NAME', 10, 'Brainstorm');
write_tag('_PATIENT_ID', 10, 'Bst31');
write_tag('_PATIENT_BIRTHDAY', 10, '20000101');
write_tag('_PATIENT_SEX', 6, 0);
write_tag('_STUDY_ID', 10, '1');
write_tag('_STUDY_DATETIME', 10, '2008-06-03, 17:59:28');
write_tag('_STUDY_DATE', 10, '20080603');
write_tag('_STUDY_TIME', 10, '175928.578000 ');
write_tag('_STUDY_DESCRIPTION', 10, 'BrainstormMRI');
write_tag('_STUDY_COMMENTS', 10, '');
write_tag('_STUDY_ACCESSIONNUMBER', 10, '');
write_tag('_SERIES_MODALITY', 10, 'MR');
write_tag('_SERIES_DATE', 10, '20080603');
write_tag('_SERIES_TIME', 10, '181010.453000 ');
write_tag('_SERIES_DESCRIPTION', 10, 'T1 MPR3D SAG 1mm');
write_tag('_EQUIP_MANUFACTURER', 10, 'SIEMENS ');
write_tag('_EQUIP_MODEL', 10, 'Sonata');
write_tag('_EQUIP_INSTITUTION', 10, 'BrainstormMRI');
write_tag('_IMAGE_REFERENCEDUID', 10, '1.3.12.2.1107.5.2.12.21296.30000008060306464609300004125');
write_tag('_REFERENCE_UID', 10, '1.3.12.2.1107.5.2.12.21296.20080603175930890.0.0.0');
write_tag('_REFERENCE_INDICATOR', 10, '');
write_tag('_IMAGEPLANE_LOCATION', 10, '140.659363\-189.429098\106.247072');
write_tag('_IMAGEPLANE_ORIENTATION', 5, 1);
write_tag('_IMAGEPIXEL_INTERPRETATION', 10, 'MONOCHROME2 ');
write_tag('_MRIMAGE_SEQUENCENAME', 10, '*tfl3d1_ns');
write_tag('_MRIMAGE_SCANNINGSEQUENCE', 10, 'IR\GR ');
write_tag('_MRIMAGE_SEQUENCEVARIANT', 10, 'SP\MP ');
write_tag('_MRIMAGE_REPETITIONTIME', 10, '1970');
write_tag('_MRIMAGE_ECHOTIME', 10, '3.93');
write_tag('_MRIMAGE_INVERSIONTIME', 10, '1100');
write_tag('_MRIMAGE_AVERAGES', 10, '1 ');
write_tag('_MRIMAGE_FREQUENCY', 10, '63.64401');
write_tag('_MRIMAGE_IMAGEDNUCLEUS', 10, '1H');
write_tag('_MRIMAGE_FIELDSTRENGTH', 10, '1.5 ');
write_tag('_MRIMAGE_FLIPANGLE', 10, '15');
write_tag('_CTIMAGE_RESCALEINTERCEPT', 10, '');
write_tag('_CTIMAGE_RESCALESLOPE', 10, '');
write_tag('_VOILUT_WINDOWWIDTH', 4, 921);
write_tag('_VOILUT_WINDOWCENTER', 4, 460);
write_tag('_SPECIFICCHARSET', 10, 'ISO_IR 100');
write_tag('_DICOMSOURCE_HASVALIDIMAGE', 5, 1);
write_tag('_DICOMSOURCE_NUMBER_SLICES', 7, 176);
write_tag('_DICOMSOURCE_NUMBER_ROWS', 7, 256);
write_tag('_DICOMSOURCE_NUMBER_COLUMNS', 7, 256);
write_tag('_DICOMSOURCE_SLICE_SPACING', 4, 1);
write_tag('_DICOMSOURCE_SLICE_THICKNESS', 4, 1);
write_tag('_DICOMSOURCE_ROW_SPACING', 4, 1);
write_tag('_DICOMSOURCE_COLUMN_SPACING', 4, 1);
write_tag('_DICOMSOURCE_ROW_ORIENTATION', 10, '-0.0209\0.9998\-0.0000');
write_tag('_DICOMSOURCE_COLUMN_ORIENTATION', 10, '-0.0626\-0.0013\-0.9980');
write_tag('_DICOMSOURCE_LOCATION_GAP', 10, '40.0000\0.0000\0.0000');

% Write slices info
for i = 0:175
    write_tag('_DICOMSOURCE_SLICE_LOCATION', 10, sprintf('%d\\0.0000\\0.0000\\0.0000', i));
end
for i = 0:175
    write_tag('_DICOMSOURCE_CTF_TO_SOURCE_SLICE', 10, sprintf('%d\\%d', i+40, i));
end

% Write slices
for i = 1:256
    write_tag(sprintf('_CTFMRI_SLICE_DATA#%05d', i), 3, Vol(:,i));
end

% Write end of file
fwrite(fid, [0 0 0 15 'EndOfParameters'], 'uchar');

% Close file
fclose(fid);


%% ===== FUNCTION: WRITE TAG =====
function write_tag(label_text, value_type, value)
    fwrite(fid, length(label_text), 'int32');
    fwrite(fid, label_text, 'uchar');
    % Write the value type
    fwrite(fid, value_type, 'uint32');
    % Binary or Cstring: write the value length
    if (value_type == 3)
        fwrite(fid, numel(value) * 2, 'int32');
    elseif (value_type == 10)
        fwrite(fid, numel(value), 'int32');
    end
    % Write the value
    switch value_type
        case 3
            fwrite(fid, value, 'uint16');
        case 4 
            fwrite(fid, value, 'float64','ieee-be');
        case 5
            fwrite(fid, value, 'int32','ieee-be');
        case 6
            fwrite(fid, value, 'int16','ieee-be');
        case 7
            fwrite(fid, value, 'uint16','ieee-be');
        case 8
            fwrite(fid, value, 'uchar','ieee-be');
        case 9
            fwrite(fid, value, 'uchar');  % ENSURE LENGTH=32
        case 10
            fwrite(fid, value, 'uchar');
        case 14
            fwrite(fid, value, 'long');
        case 15
            fwrite(fid, value, 'ulong');
        case 16
            fwrite(fid, value, 'uint32');
        case 17
            fwrite(fid, value, 'int32');
        otherwise 
            % NOTHING TO DO
    end
end

end
